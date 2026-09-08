#!/usr/bin/env python3
"""Persist an explicitly confirmed Quickshell layout to the managed profile."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from datetime import datetime, timezone


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=30).stdout


def merge(profile, desired):
    result = json.loads(json.dumps(profile))
    matched = set()
    for output in result['outputs']:
        name = output['name']
        if name not in desired:
            continue
        value = desired[name]
        identity = value.get('identity', '')
        if identity.startswith('edid:') and identity[5:] != output.get('match_key', output.get('key')):
            raise ValueError('Display identity changed: ' + name)
        width, height = map(int, value['res'].split('x'))
        scale, refresh = float(value['scale']), float(value['hz'])
        if not (0.25 <= scale <= 8 and 1 <= refresh <= 1000 and width > 0 and height > 0):
            raise ValueError('Invalid display mode: ' + name)
        output.update(width=width, height=height, refresh=refresh,
                      mode=f'{width}x{height}@{refresh:.2f}Hz', scale=scale,
                      x=int(value['posX']), y=int(value['posY']),
                      bitdepth=int(value['bitdepth']), vrr=int(value['vrr']),
                      cm=value.get('colorManagement', 'hdr' if value.get('hdr') else 'srgb'),
                      sdr_max_luminance=int(value['sdrLuminance']),
                      sdr_brightness=float(value['sdrBrightness']),
                      sdr_saturation=float(value['sdrSaturation']),
                      icc=value.get('iccProfile', ''),
                      sdr_eotf=str(value.get('sdrEotf', 1)))
        # Retain profile-specific workspace rules, hooks and unedited outputs.
        matched.add(name)
    if matched != set(desired):
        raise ValueError('Active profile does not match the confirmed displays')
    result['updated_at'] = datetime.now(timezone.utc).isoformat()
    return result


def atomic_write(path, data):
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(data)
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    script = Path(__file__).resolve().parent
    if run('bash', str(script / 'detect_compositor.sh')).strip() != 'hyprland':
        return
    if subprocess.run(['systemctl', '--user', 'is-active', '--quiet', 'hyprmoncfgd.service']).returncode:
        return
    desired = json.loads(sys.argv[1])
    status = run('hyprmoncfg', 'status')
    names = [line.partition(':')[2].strip() for line in status.splitlines()
             if line.startswith('Active profile:')]
    if len(names) != 1 or not names[0] or Path(names[0]).name != names[0]:
        raise ValueError('Cannot determine active hyprmoncfg profile')
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))
    path = config / 'hyprmoncfg' / 'profiles' / (names[0] + '.json')
    # During a preview the CLI labels the modified live state "custom layout".
    # Resolve by hardware only if there is exactly one matching saved profile.
    if not path.is_file():
        candidates = []
        for candidate in (config / 'hyprmoncfg' / 'profiles').glob('*.json'):
            profile = json.loads(candidate.read_text())
            if {o['name'] for o in profile['outputs'] if o.get('enabled')} != set(desired):
                continue
            try:
                merge(profile, desired)
            except ValueError:
                continue
            candidates.append(candidate)
        if len(candidates) != 1:
            raise ValueError('Cannot uniquely identify the managed monitor profile')
        path = candidates[0]
        names[0] = json.loads(path.read_text())['name']
    original = path.read_bytes()
    updated = merge(json.loads(original), desired)
    backup = Path(tempfile.mkdtemp(prefix='quickshell-monitor-', dir=str(config / 'hyprmoncfg')))
    (backup / path.name).write_bytes(original)
    atomic_write(path, (json.dumps(updated, indent=2) + '\n').encode())
    try:
        # Keep has already been chosen in Quickshell; do not start a second prompt.
        run('hyprmoncfg', 'apply', names[0], '--confirm-timeout', '0')
    except Exception:
        atomic_write(path, original)
        run('hyprmoncfg', 'apply', names[0], '--confirm-timeout', '0')
        raise


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('Monitor profile sync failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
