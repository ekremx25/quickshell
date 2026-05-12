#!/bin/bash

set -u

workspace="${1:-}"

[ -n "$workspace" ] || exit 0

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
