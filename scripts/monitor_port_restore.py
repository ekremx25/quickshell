#!/usr/bin/env python3
"""Keep monitors as chosen in Settings → Monitors, whatever port they are on.

The settings page (monitor_config.json) is the source of truth for mode,
scale, position and colour. This script

* re-applies those settings after a connector change or Hyprland reload,
  matching displays by EDID identity, with mirrors taken from the snapshot;
* writes hypr/lua/quickshell_monitors.lua (loaded by hyprland.lua) so Hyprland
  starts and reloads with the same settings instead of stale hard-coded ones.
"""
import argparse
import json
import re
import os
import subprocess
from collections import Counter
from pathlib import Path
from monitor_role_manager import ROLE_NAMES, monitor_identity, monitor_argument, atomic_json_write, normalize_eotf


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


def desired_layout(config):
    """identity -> wanted mode and geometry from the settings page.

    Overlapping monitors are pushed to the right of their neighbour, and the
    layout is moved so its top-left corner is at 0,0.
    """
    layout = {}
    for profile in ordered_profiles(config):
        identity = profile.get('identity')
        if not identity or identity in layout:
            continue
        try:
            width, height = (int(v) for v in str(profile['res']).lower().split('x', 1))
            hz, scale = float(profile['hz']), float(profile['scale'])
            x, y = int(float(profile.get('posX', 0))), int(float(profile.get('posY', 0)))
        except (KeyError, ValueError, TypeError):
            continue
        if width <= 0 or height <= 0 or hz <= 0 or scale <= 0:
            continue
        layout[identity] = dict(profile=profile, width=width, height=height, hz=hz, scale=scale, x=x, y=y)

    placed = []
    for item in sorted(layout.values(), key=lambda d: (d['x'], d['y'])):
        w, h = item['width'] / item['scale'], item['height'] / item['scale']
        for other in placed:
            ow, oh = other['width'] / other['scale'], other['height'] / other['scale']
            if (item['x'] < other['x'] + ow and other['x'] < item['x'] + w
                    and item['y'] < other['y'] + oh and other['y'] < item['y'] + h):
                item['x'] = int(round(other['x'] + ow))
        placed.append(item)
    if placed:
        min_x, min_y = min(d['x'] for d in placed), min(d['y'] for d in placed)
        for item in placed:
            item['x'] -= min_x
            item['y'] -= min_y
    return layout


def wanted_state(old, layout):
    """The snapshot entry with mode, geometry and colour from the settings page."""
    item = layout.get(monitor_identity(old))
    if not item:
        return old
    profile = item['profile']
    want = dict(old, width=item['width'], height=item['height'], refreshRate=item['hz'],
                x=item['x'], y=item['y'], scale=item['scale'])
    # Colour fields the profile leaves out keep the snapshot's values.
    if 'hdr' in profile or 'colorManagement' in profile:
        hdr = bool(profile.get('hdr')) or str(profile.get('colorManagement', '')).startswith('hdr')
        want['colorManagementPreset'] = (('hdredid' if profile.get('colorManagement') == 'hdredid' else 'hdr') if hdr
                                         else str(profile.get('colorManagement') or old.get('colorManagementPreset', 'srgb')))
    if 'bitdepth' in profile:
        want['currentFormat'] = 'XRGB2101010' if int(profile['bitdepth']) == 10 else 'XRGB8888'
    if 'vrr' in profile:
        want['vrr'] = bool(int(profile.get('vrr') or 0))
    return want


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
    layout = desired_layout(config or {})
    commands = []
    for snapshot in saved:
        current = mapping.get(snapshot['name'])
        if current is None:
            continue
        mirror = str(snapshot.get('mirrorOf', 'none'))
        target_old = ids.get(mirror) if mirror != 'none' else None
        target = mapping.get(target_old) if target_old else None
        if target_old and target is None:
            continue  # Never turn an unresolved mirror into an extended desktop.
        # Mirrors keep their snapshot mode; extended outputs follow the settings page.
        old = snapshot if target_old else wanted_state(snapshot, layout)
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


def lua_string(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'


def update_descriptions(path, live):
    """identity -> EDID description, kept for monitors that are unplugged now."""
    try:
        known = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        known = {}
    original = dict(known)
    for monitor in live:
        identity, description = monitor_identity(monitor), str(monitor.get('description') or '').strip()
        if identity and description:
            known[identity] = description
    if known != original:
        atomic_json_write(path, known)
    return known


def render_rules(config, descriptions):
    lines = [
        '-- Generated by Quickshell from Settings → Monitors. Do not edit by hand;',
        '-- changes made in Quickshell overwrite this file. Displays are matched by',
        '-- EDID description, so they keep their settings on any port.',
    ]
    for identity, item in desired_layout(config).items():
        description = descriptions.get(identity)
        if not description:
            continue
        profile = item['profile']
        hdr = bool(profile.get('hdr')) or str(profile.get('colorManagement', '')).startswith('hdr')
        fields = [
            f'output = {lua_string("desc:" + description)}',
            f'mode = "{item["width"]}x{item["height"]}@{item["hz"]:.2f}"',
            f'position = "{item["x"]}x{item["y"]}"',
            f'scale = "{item["scale"]:g}"',
            f'bitdepth = {int(profile.get("bitdepth", 10 if hdr else 8))}',
            f'vrr = {int(profile.get("vrr", 0) or 0)}',
        ]
        if hdr:
            fields += [f'cm = "{"hdredid" if profile.get("colorManagement") == "hdredid" else "hdr"}"',
                       f'sdr_max_luminance = {float(profile.get("sdrLuminance", 80)):g}',
                       f'sdrbrightness = {float(profile.get("sdrBrightness", 1)):g}',
                       f'sdrsaturation = {float(profile.get("sdrSaturation", 1)):g}']
        elif re.fullmatch(r'[a-z0-9]+', str(profile.get('colorManagement', ''))) and profile.get('colorManagement') != 'default':
            fields.append(f'cm = "{profile["colorManagement"]}"')
        eotf = normalize_eotf(profile.get('sdrEotf', 1))
        if eotf in ('default', 'gamma22', 'srgb'):
            fields.append(f'sdr_eotf = "{eotf}"')
        lines.append('hl.monitor({ ' + ', '.join(fields) + ' })')
    return '\n'.join(lines) + '\n'


def write_rules(root, config, live):
    """Write quickshell_monitors.lua; only when it changes, since Hyprland reloads on every write."""
    descriptions = update_descriptions(root / 'monitor_descriptions.json', live)
    target = root.parent / 'hypr' / 'lua' / 'quickshell_monitors.lua'
    if not target.parent.is_dir():
        return False
    text = render_rules(config, descriptions)
    try:
        if target.read_text() == text:
            return False
    except OSError:
        pass
    tmp = target.with_name(f'.{target.name}.tmp')
    tmp.write_text(text)
    os.replace(tmp, target)
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--write-rules', action='store_true',
                        help='only regenerate hypr/lua/quickshell_monitors.lua (after the settings page saves)')
    args = parser.parse_args()
    root = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'quickshell'
    live = json.loads(subprocess.check_output(['hyprctl', 'monitors', 'all', '-j'], text=True))
    config_path = root / 'monitor_config.json'
    config = json.loads(config_path.read_text()) if config_path.exists() else {}
    if args.write_rules:
        print(json.dumps({'ok': True, 'changed': write_rules(root, config, live)}))
        return
    saved = json.loads((root / 'monitor_port_snapshot.json').read_text())
    commands = plan_restore(saved, live, config)
    if args.dry_run:
        print(json.dumps(commands, indent=2))
        return
    for command in commands:
        subprocess.run([str(root / 'scripts/hypr_monitor_apply.sh'), 'monitor', command], check=True)
    atomic_json_write(root / 'monitor_runtime.json', restored_roles(saved, live, config))
    write_rules(root, config, live)


if __name__ == '__main__':
    main()
