#!/usr/bin/env bash
# hypr_events.sh — Hyprland .socket2 event stream'e bağlanır.
#
# Her olay tek satır olarak stdout'a yazılır:
#   workspace>>1
#   openwindow>>0x1234,1,kitty,terminal
#   closewindow>>0x1234
#   activewindow>>kitty,terminal
#   focusedmon>>DP-2,1
#   movewindow>>0x1234,2
#   windowtitle>>0x1234
#
# QML tarafı bu satırları okuyarak sadece ilgili olaylarda refresh() çağırır.
# Böylece 700ms polling tamamen ortadan kalkar.
#
# Bağlantı kesilirse (compositor restart, crash) QML tarafı 1s sonra
# yeniden başlatır.

set -euo pipefail

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "HYPRLAND_INSTANCE_SIGNATURE tanımlı değil" >&2
    exit 1
fi

SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

if [ ! -S "$SOCK" ]; then
    echo "Socket bulunamadı: $SOCK" >&2
    exit 1
fi

# socat varsa tercih et, yoksa nc -U kullan
if command -v socat >/dev/null 2>&1; then
    exec socat -U - "UNIX-CONNECT:$SOCK"
elif command -v nc >/dev/null 2>&1; then
    exec nc -U "$SOCK"
else
    echo "socat veya nc bulunamadı" >&2
    exit 127
fi
