#!/usr/bin/env python3
"""Restore opted-in monitor snapshots after a connector change, without relayout."""
import argparse
import json
import os
import subprocess
from collections import Counter
from pathlib import Path
from monitor_role_manager import ROLE_NAMES, monitor_identity, monitor_argument, atomic_json_write


def resolve_outputs(saved, live):
    active = [m for m in live if not m.get('disabled')]
    mapping = {}
    for old in saved:
        if not monitor_identity(old):
            continue
        candidates = [m for m in active if monitor_identity(m) == monitor_identity(old)]
        exact = [m for m in candidates if m['name'] == old['name']]
        # The same physical display may expose DP and HDMI simultaneously.
        same_kind = [m for m in candidates if m['name'].rsplit('-', 1)[0] == old['name'].rsplit('-', 1)[0]]
        choices = exact or same_kind or candidates
        if len(choices) == 1:
            mapping[old['name']] = choices[0]
    # Mid-hotplug only one cable of a dual-connected display may be up, so two
    # saved outputs claim the same connector. Leave those untouched, keep the rest.
    claims = Counter(m['name'] for m in mapping.values())
    return {old: current for old, current in mapping.items() if claims[current['name']] == 1}


def role_rank(profile):
    role = profile.get('role')
    return ROLE_NAMES.index(role) if role in ROLE_NAMES else len(ROLE_NAMES)


def ordered_profiles(config):
    """Settings-page profiles, named roles first, so a stale extra profile never wins."""
    profiles = [p for p in config.values() if isinstance(p, dict) and p.get('role')]
    return sorted(profiles, key=role_rank)


def sdr_settings(old, config):
    """SDR tuning from the settings page profile for this display, else the snapshot."""
    profile = next((p for p in ordered_profiles(config) if p.get('identity') == monitor_identity(old)), {})
    return dict(sdrBrightness=profile.get('sdrBrightness', old.get('sdrBrightness', 1)),
                sdrSaturation=profile.get('sdrSaturation', old.get('sdrSaturation', 1)),
                sdrLuminance=profile.get('sdrLuminance', old.get('sdrMaxLuminance', 80)),
                sdrEotf=profile.get('sdrEotf', 'default'))


def matches_live(old, current, target, sdr):
    """True when the live output already has the wanted mode, geometry, SDR tuning and mirror."""
    mirror = str(target['id']) if target else 'none'
    hdr = str(old.get('colorManagementPreset', '')).startswith('hdr')
    if hdr and not (abs(current.get('sdrMaxLuminance', 0) - sdr['sdrLuminance']) < 1
                    and abs(current.get('sdrBrightness', 0) - sdr['sdrBrightness']) < 0.05
                    and abs(current.get('sdrSaturation', 0) - sdr['sdrSaturation']) < 0.05):
        return False
    return (current['width'] == old['width'] and current['height'] == old['height']
            and round(current['refreshRate']) == round(old['refreshRate'])
            and current['x'] == old['x'] and current['y'] == old['y']
            and abs(current['scale'] - old['scale']) < 0.01
            and current.get('transform', 0) == old.get('transform', 0)
            and current.get('colorManagementPreset') == old.get('colorManagementPreset')
            and ('2101010' in current.get('currentFormat', '')) == ('2101010' in old.get('currentFormat', ''))
            and str(current.get('mirrorOf', 'none')) == mirror)


def restored_roles(saved, live, config):
    mapping = resolve_outputs(saved, live)
    saved_by_name = {m['name']: m for m in saved}
    roles = {}
    for connector, profile in sorted(config.items(), key=lambda item: role_rank(item[1]) if isinstance(item[1], dict) else 99):
        if not isinstance(profile, dict) or not profile.get('role'):
            continue
        identity = profile.get('identity')
        candidates = [current for old_name, current in mapping.items()
                      if str(saved_by_name[old_name].get('mirrorOf', 'none')) == 'none'
                      and str(current.get('mirrorOf', 'none')) == 'none'
                      and (monitor_identity(current) == identity if identity else old_name == connector)]
        # One display gets one role; a stale duplicate profile must not alias it.
        if len(candidates) == 1 and candidates[0]['name'] not in roles.values():
            roles[profile['role']] = candidates[0]['name']
    return roles


def plan_restore(saved, live, config=None):
    mapping = resolve_outputs(saved, live)
    ids = {str(m['id']): m['name'] for m in saved}
    commands = []
    for old in saved:
        current = mapping.get(old['name'])
        if current is None:
            continue
        mirror = str(old.get('mirrorOf', 'none'))
        target_old = ids.get(mirror) if mirror != 'none' else None
        target = mapping.get(target_old) if target_old else None
        if target_old and target is None:
            continue  # Never turn an unresolved mirror into an extended desktop.
        sdr = sdr_settings(old, config or {})
        if matches_live(old, current, target, sdr):
            continue
        item = dict(name=current['name'], res=f"{old['width']}x{old['height']}",
                    hz=old['refreshRate'], posX=old['x'], posY=old['y'], scale=old['scale'],
                    hdr=str(old.get('colorManagementPreset', '')).startswith('hdr'),
                    bitdepth=10 if '2101010' in old.get('currentFormat', '') else 8,
                    vrr=int(bool(old.get('vrr'))), colorManagement=old.get('colorManagementPreset', 'srgb'),
                    **sdr)
        arg = monitor_argument(item)
        arg += f",transform,{old.get('transform', 0)},sdr_min_luminance,{old.get('sdrMinLuminance', 0.2)}"
        if target:
            arg += ',mirror,' + target['name']
        commands.append((bool(target), arg))
    return [arg for _, arg in sorted(commands, key=lambda pair: pair[0])]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    root = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'quickshell'
    saved = json.loads((root / 'monitor_port_snapshot.json').read_text())
    live = json.loads(subprocess.check_output(['hyprctl', 'monitors', 'all', '-j'], text=True))
    config_path = root / 'monitor_config.json'
    config = json.loads(config_path.read_text()) if config_path.exists() else {}
    commands = plan_restore(saved, live, config)
    if args.dry_run:
        print(json.dumps(commands, indent=2))
        return
    for command in commands:
        subprocess.run([str(root / 'scripts/hypr_monitor_apply.sh'), 'monitor', command], check=True)
    atomic_json_write(root / 'monitor_runtime.json', restored_roles(saved, live, config))


if __name__ == '__main__':
    main()
