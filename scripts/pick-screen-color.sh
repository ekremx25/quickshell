#!/usr/bin/env bash
# Capture only the selected pixel; Escape leaves the current color untouched.
set -euo pipefail
for tool in slurp grim magick; do command -v "$tool" >/dev/null || exit 1; done
geometry=$(slurp -p) || exit 2
[[ -n "$geometry" ]] || exit 2
grim -g "$geometry" -t ppm - | magick ppm:- -depth 8 -format '#%[hex:p{0,0}]' info:-
