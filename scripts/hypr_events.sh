#!/usr/bin/env bash
# hypr_events.sh — Connect to the Hyprland .socket2 event stream.
#
# Each event is written to stdout as a single line:
#   workspace>>1
#   openwindow>>0x1234,1,kitty,terminal
#   closewindow>>0x1234
#   activewindow>>kitty,terminal
#   focusedmon>>DP-2,1
#   movewindow>>0x1234,2
#   windowtitle>>0x1234
#
# The QML side reads these lines and calls refresh() only on relevant events.
# This replaces a 700ms polling loop entirely.
#
# If the connection drops (compositor restart, crash), the QML side restarts
# the process after 1 second.

set -euo pipefail

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "HYPRLAND_INSTANCE_SIGNATURE is not set" >&2
    exit 1
fi

SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

if [ ! -S "$SOCK" ]; then
    echo "Socket not found: $SOCK" >&2
    exit 1
fi

# Prefer socat; fall back to nc -U.
if command -v socat >/dev/null 2>&1; then
    exec socat -U - "UNIX-CONNECT:$SOCK"
elif command -v nc >/dev/null 2>&1; then
    exec nc -U "$SOCK"
else
    echo "neither socat nor nc is installed" >&2
    exit 127
fi
