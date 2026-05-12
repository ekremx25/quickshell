#!/usr/bin/env python3
"""Apply monitor settings to Niri config.kdl.

Reads monitor parameters from environment variables to avoid any
shell escaping concerns. Called from MonitorsBackend via direct argv.

Env vars: NIRI_MON, NIRI_MODE, NIRI_PX, NIRI_PY, NIRI_SC
"""
import re, os, sys

mon  = os.environ.get('NIRI_MON', '')
mode = os.environ.get('NIRI_MODE', '')
px   = os.environ.get('NIRI_PX', '0')
py_v = os.environ.get('NIRI_PY', '0')
sc   = os.environ.get('NIRI_SC', '1')

if not mon or not mode:
    print('Missing NIRI_MON or NIRI_MODE', file=sys.stderr)
    sys.exit(1)

conf = os.path.expanduser('~/.config/niri/config.kdl')
with open(conf) as f:
    text = f.read()

esc = re.escape(mon)
pat = r'(output\s+"' + esc + r'"\s*\{)[^}]*(\})'

def repl(m):
    return (m.group(1)
            + '\n    mode "' + mode + '"'
            + '\n    position x=' + px + ' y=' + py_v
            + '\n    scale ' + sc + '\n'
            + m.group(2))

if re.search(pat, text, re.DOTALL):
    new_text = re.sub(pat, repl, text, flags=re.DOTALL)
else:
    new_text = (text.rstrip()
                + '\n\noutput "' + mon + '" {\n'
                + '    mode "' + mode + '"\n'
                + '    position x=' + px + ' y=' + py_v + '\n'
                + '    scale ' + sc + '\n}\n')

with open(conf, 'w') as f:
    f.write(new_text)
print('Updated ' + conf)
