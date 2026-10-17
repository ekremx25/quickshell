#!/bin/bash
# Usage: hypr_window_action.sh <close|focus> <window-address>
# Hyprland 0.56+ with a Lua config only accepts Lua expressions through
# `hyprctl eval`; older/hyprlang setups still use the classic dispatchers.

set -u

action="${1:-}"
address="${2:-}"

# Addresses come from `hyprctl clients -j` (0x-prefixed hex); reject anything
# else so the value can never break out of the Lua string literal.
[[ "$address" =~ ^0x[0-9a-fA-F]+$ ]] || exit 2

provider() {
    hyprctl systeminfo 2>/dev/null | awk -F': ' '/configProvider:/ { print $2; exit }'
}

if [ "$(provider)" = "lua" ]; then
    case "$action" in
        close) hyprctl eval "hl.dispatch(hl.dsp.window.close({ window = \"address:$address\" }))" ;;
        focus) hyprctl eval "hl.dispatch(hl.dsp.focus({ window = \"address:$address\" }))" ;;
        *) exit 2 ;;
    esac
else
    case "$action" in
        close) hyprctl dispatch closewindow "address:$address" ;;
        focus) hyprctl dispatch focuswindow "address:$address" ;;
        *) exit 2 ;;
    esac
fi
