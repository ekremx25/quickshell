#!/bin/bash
# Ends the Hyprland session. Hyprland 0.56+ with a Lua config only accepts
# Lua expressions through `hyprctl eval`; older setups use `dispatch exit`.

set -u

provider() {
    hyprctl systeminfo 2>/dev/null | awk -F': ' '/configProvider:/ { print $2; exit }'
}

if [ "$(provider)" = "lua" ]; then
    hyprctl eval "hl.dispatch(hl.dsp.exit())"
else
    hyprctl dispatch exit
fi
