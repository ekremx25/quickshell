#!/bin/bash

set -u

action="${1:-}"
value="${2:-}"

lua_quote() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

provider() {
    hyprctl systeminfo 2>/dev/null | awk -F': ' '/configProvider:/ { print $2; exit }'
}

monitor_eval() {
    local arg="$1"
    local IFS=','
    read -r -a parts <<< "$arg"

    [ "${#parts[@]}" -ge 4 ] || return 1

    local output="${parts[0]}"
    local mode="${parts[1]}"
    local position="${parts[2]}"
    local scale="${parts[3]}"
    local expr="hl.monitor({ output = \"$(lua_quote "$output")\", mode = \"$(lua_quote "$mode")\", position = \"$(lua_quote "$position")\", scale = \"$(lua_quote "$scale")\""

    local i=4
    while [ "$i" -lt "${#parts[@]}" ]; do
        local key="${parts[$i]}"
        local val="${parts[$((i + 1))]:-}"
        case "$key" in
            bitdepth|vrr|max_luminance|max_avg_luminance|sdr_max_luminance|supports_hdr|supports_wide_color)
                expr="$expr, $key = $val"
                ;;
            min_luminance|sdr_min_luminance|sdrbrightness|sdrsaturation)
                expr="$expr, $key = $val"
                ;;
            cm|icc|sdr_eotf)
                expr="$expr, $key = \"$(lua_quote "$val")\""
                ;;
        esac
        i=$((i + 2))
    done

    expr="$expr })"
    hyprctl eval "$expr"
}

focus_eval() {
    local mon="$1"
    hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$(lua_quote "$mon")\" }))"
}

case "$action" in
    monitor)
        if [ "$(provider)" = "lua" ]; then
            monitor_eval "$value"
        else
            hyprctl keyword monitor "$value"
        fi
        ;;
    focus)
        if [ -z "$value" ] || [ "$value" = "null" ]; then
            exit 0
        fi
        if [ "$(provider)" = "lua" ]; then
            focus_eval "$value"
        else
            hyprctl dispatch focusmonitor "$value"
        fi
        ;;
    *)
        echo "usage: $0 monitor <monitor-arg> | focus <monitor-name>" >&2
        exit 2
        ;;
esac
