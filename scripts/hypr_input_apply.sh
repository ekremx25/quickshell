#!/bin/bash

set -u

sensitivity="${1:-0.00}"
scroll_factor="${2:-1.00}"
accel_profile="${3:-adaptive}"
cursor_theme="${4:-}"
cursor_size="${5:-24}"
compositor="${6:-auto}"

lua_quote() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

provider() {
    hyprctl systeminfo 2>/dev/null | awk -F': ' '/configProvider:/ { print $2; exit }'
}

apply_hyprland() {
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
}

apply_mango() {
    local mango_config mango_dir temp_config profile_number
    mango_config="${QUICKSHELL_MANGO_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/mango/config.conf}"
    mango_dir="$(dirname "$mango_config")"

    [ -f "$mango_config" ] || return 1
    case "$accel_profile" in
        flat) profile_number=1 ;;
        adaptive) profile_number=2 ;;
        *) profile_number=2 ;;
    esac
    case "$cursor_theme" in
        ""|*[!A-Za-z0-9._+-]*) cursor_theme="Adwaita" ;;
    esac

    temp_config="$(mktemp "$mango_dir/.config.conf.quickshell.XXXXXX")" || return 1
    trap 'rm -f "$temp_config"' RETURN

    awk '
        $0 == "# BEGIN QUICKSHELL MANAGED MOUSE" { managed = 1; next }
        $0 == "# END QUICKSHELL MANAGED MOUSE" { managed = 0; next }
        !managed { print }
    ' "$mango_config" > "$temp_config" || return 1

    {
        printf '\n# BEGIN QUICKSHELL MANAGED MOUSE\n'
        printf '# Updated by the Quickshell Mouse Settings page.\n'
        printf 'mouse_accel_speed=%s\n' "$sensitivity"
        printf 'trackpad_accel_speed=%s\n' "$sensitivity"
        printf 'axis_scroll_factor=%s\n' "$scroll_factor"
        printf 'trackpad_scroll_factor=%s\n' "$scroll_factor"
        printf 'mouse_accel_profile=%s\n' "$profile_number"
        printf 'trackpad_accel_profile=%s\n' "$profile_number"
        printf 'cursor_theme=%s\n' "$cursor_theme"
        printf 'cursor_size=%s\n' "$cursor_size"
        printf '# END QUICKSHELL MANAGED MOUSE\n'
    } >> "$temp_config"

    if command -v mango >/dev/null 2>&1; then
        mango -c "$temp_config" -p >/dev/null 2>&1 || return 1
    fi

    chmod --reference="$mango_config" "$temp_config" 2>/dev/null || true
    mv "$temp_config" "$mango_config" || return 1
    trap - RETURN
    mmsg dispatch reload_config >/dev/null
}

if [ "$compositor" = "hyprland" ] || { [ "$compositor" = "auto" ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; }; then
    apply_hyprland
elif [ "$compositor" = "mango" ] || { [ "$compositor" = "auto" ] && [ -n "${MANGO_INSTANCE_SIGNATURE:-}" ]; }; then
    apply_mango
else
    exit 1
fi
