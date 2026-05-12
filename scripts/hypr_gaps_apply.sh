#!/bin/bash

set -u

gaps_in="${1:-6}"
gaps_out="${2:-3}"
border_size="${3:-2}"
rounding="${4:-10}"
shadow_enabled="${5:-false}"
palette="${6:-solid}"
hypr_general="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lua/general.lua"

clamp_int() {
    local value="$1" fallback="$2" max="$3"
    case "$value" in
        ''|*[!0-9]*) value="$fallback" ;;
    esac
    if [ "$value" -gt "$max" ]; then value="$max"; fi
    printf '%s\n' "$value"
}

gaps_in=$(clamp_int "$gaps_in" 6 80)
gaps_out=$(clamp_int "$gaps_out" 3 120)
border_size=$(clamp_int "$border_size" 2 12)
rounding=$(clamp_int "$rounding" 10 40)

case "$shadow_enabled" in
    true|1|yes|on) shadow_enabled=true ;;
    *) shadow_enabled=false ;;
esac

case "$palette" in
    aqua)       active_a="rgba(33ccffee)"; active_b="rgba(00ff99ee)"; inactive="rgba(595959aa)" ;;
    catppuccin) active_a="rgba(89b4faff)"; active_b="rgba(cba6f7ff)"; inactive="rgba(585b70aa)" ;;
    rose)       active_a="rgba(f5c2e7ff)"; active_b="rgba(f38ba8ff)"; inactive="rgba(6c7086aa)" ;;
    jade)       active_a="rgba(a6e3a1ff)"; active_b="rgba(94e2d5ff)"; inactive="rgba(585b70aa)" ;;
    amber)      active_a="rgba(f9e2afff)"; active_b="rgba(fab387ff)"; inactive="rgba(6c7086aa)" ;;
    mono)       active_a="rgba(cdd6f4ff)"; active_b="rgba(a6adc8ff)"; inactive="rgba(585b70aa)" ;;
    solid|*)    palette="solid"; active_a="rgba(89b4faff)"; active_b="rgba(89b4faff)"; inactive="rgba(595959aa)" ;;
esac

lua_quote() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

provider() {
    hyprctl systeminfo 2>/dev/null | awk -F': ' '/configProvider:/ { print $2; exit }'
}

if [ -f "$hypr_general" ]; then
    perl -0pi -e '
        s/gaps_in\s*=\s*\d+,/gaps_in = '"$gaps_in"',/;
        s/gaps_out\s*=\s*\d+,/gaps_out = '"$gaps_out"',/;
        s/border_size\s*=\s*\d+,/border_size = '"$border_size"',/;
        s/active_border\s*=\s*\{[^\n]*\},/active_border = { colors = { "'"$active_a"'", "'"$active_b"'" }, angle = 45 },/;
        s/inactive_border\s*=\s*"rgba\([0-9A-Fa-f]+\)",/inactive_border = "'"$inactive"'",/;
        s/rounding\s*=\s*\d+,/rounding = '"$rounding"',/;
        s/(shadow\s*=\s*\{\s*enabled\s*=\s*)(true|false)/${1}'"$shadow_enabled"'/s;
        s/(blur\s*=\s*\{\s*enabled\s*=\s*)(true|false)/${1}false/s;
    ' "$hypr_general"
fi

if [ "$(provider)" = "lua" ]; then
    hyprctl eval "hl.config({ general = { gaps_in = $gaps_in, gaps_out = $gaps_out, border_size = $border_size, col = { active_border = { colors = { \"$(lua_quote "$active_a")\", \"$(lua_quote "$active_b")\" }, angle = 45 }, inactive_border = \"$(lua_quote "$inactive")\" } }, decoration = { rounding = $rounding, shadow = { enabled = $shadow_enabled }, blur = { enabled = false } } })"
else
    hyprctl keyword general:gaps_in "$gaps_in"
    hyprctl keyword general:gaps_out "$gaps_out"
    hyprctl keyword general:border_size "$border_size"
    hyprctl keyword general:col.active_border "$active_a $active_b 45deg"
    hyprctl keyword general:col.inactive_border "$inactive"
    hyprctl keyword decoration:rounding "$rounding"
    hyprctl keyword decoration:shadow:enabled "$shadow_enabled"
    hyprctl keyword decoration:blur:enabled false
fi
