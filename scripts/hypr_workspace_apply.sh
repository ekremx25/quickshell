#!/bin/bash

set -u

workspace="${1:-}"
monitor="${2:-}"

[ -n "$workspace" ] || exit 0

if [ -n "$monitor" ]; then
    hyprctl dispatch focusmonitor "$monitor" >/dev/null 2>&1 || true
fi

lua_quote() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

provider() {
    hyprctl systeminfo 2>/dev/null | awk -F': ' '/configProvider:/ { print $2; exit }'
}

if [ "$(provider)" = "lua" ]; then
    hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = \"$(lua_quote "$workspace")\" }))"
else
    hyprctl dispatch workspace "$workspace"
fi
