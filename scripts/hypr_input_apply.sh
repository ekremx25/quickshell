#!/bin/bash

set -u

sensitivity="${1:-0.00}"
scroll_factor="${2:-1.00}"
accel_profile="${3:-adaptive}"
cursor_theme="${4:-}"
cursor_size="${5:-24}"

lua_quote() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

provider() {
    hyprctl systeminfo 2>/dev/null | awk -F': ' '/configProvider:/ { print $2; exit }'
}

if [ "$(provider)" = "lua" ]; then
    hyprctl eval "hl.config({ input = { sensitivity = ${sensitivity}, scroll_factor = ${scroll_factor}, accel_profile = \"$(lua_quote "$accel_profile")\" } })" >/dev/null
else
    hyprctl keyword input:sensitivity "$sensitivity" >/dev/null
    hyprctl keyword input:scroll_factor "$scroll_factor" >/dev/null
    hyprctl keyword input:accel_profile "$accel_profile" >/dev/null
fi

if [ -n "$cursor_theme" ] && [ "$cursor_theme" != "null" ]; then
    hyprctl setcursor "$cursor_theme" "$cursor_size" >/dev/null
fi
