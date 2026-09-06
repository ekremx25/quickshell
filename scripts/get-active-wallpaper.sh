#!/usr/bin/env bash
# Keep the public entry point used by QML and desktop hooks.
exec python3 "$(dirname -- "$0")/detect_wallpaper.py" "$@"
