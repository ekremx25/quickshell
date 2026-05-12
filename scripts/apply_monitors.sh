#!/bin/bash

# Applies monitor settings from monitor_config.json.
# Hyprland Lua configs are applied through hypr_monitor_apply.sh because
# `hyprctl keyword monitor ...` is a config-language operation.

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_FILE="$CONFIG_HOME/quickshell/monitor_config.json"
HYPR_MONITOR_APPLY="$CONFIG_HOME/quickshell/scripts/hypr_monitor_apply.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

IS_HYPRLAND=0
IS_NIRI=0
IS_MANGO=0

if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || hyprctl systeminfo >/dev/null 2>&1; then
    IS_HYPRLAND=1
elif [ -n "$NIRI_SOCKET" ]; then
    IS_NIRI=1
elif command -v mmsg >/dev/null 2>&1; then
    IS_MANGO=1
fi

if [ $IS_HYPRLAND -eq 0 ] && [ $IS_NIRI -eq 0 ] && [ $IS_MANGO -eq 0 ]; then
    exit 0
fi

MONITORS=$(jq -r 'keys[]' "$CONFIG_FILE" 2>/dev/null)
DEFAULT_MONITOR=$(jq -r 'to_entries[] | select(.value.default == true) | .key' "$CONFIG_FILE" 2>/dev/null | head -n1)

normalize_eotf() {
    case "$1" in
        0) printf '%s\n' "default" ;;
        1) printf '%s\n' "srgb" ;;
        2) printf '%s\n' "gamma22" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

apply_monitors() {
    local MISSING_MONITORS=""
    local BATCH_CMDS=""
    local CONFIG_PROVIDER=""

    if [ $IS_HYPRLAND -eq 1 ]; then
        CURRENT_STATE=$(hyprctl monitors all -j 2>/dev/null)
        CONNECTED_MONITORS=$(echo "$CURRENT_STATE" | jq -r '.[].name' 2>/dev/null)
        CONFIG_PROVIDER=$(hyprctl systeminfo 2>/dev/null | awk -F': ' '/configProvider:/ { print $2; exit }')
    fi

    while IFS= read -r MON; do
        [ -n "$MON" ] || continue

        RES=$(jq -r --arg mon "$MON" '.[$mon].res' "$CONFIG_FILE")
        HZ=$(jq -r --arg mon "$MON" '.[$mon].hz' "$CONFIG_FILE")
        SCALE=$(jq -r --arg mon "$MON" '.[$mon].scale' "$CONFIG_FILE")
        POS_X=$(jq -r --arg mon "$MON" '.[$mon].posX' "$CONFIG_FILE")
        POS_Y=$(jq -r --arg mon "$MON" '.[$mon].posY' "$CONFIG_FILE")

        if [ "$RES" = "null" ] || [ "$HZ" = "null" ] || [ "$SCALE" = "null" ] || [ "$RES" = "0x0" ]; then
            continue
        fi

        if [ $IS_HYPRLAND -eq 1 ]; then
            if ! printf '%s\n' "$CONNECTED_MONITORS" | grep -Fxq "$MON"; then
                MISSING_MONITORS="$MISSING_MONITORS $MON"
                continue
            fi

            CURR_RES=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | "\(.width)x\(.height)"' 2>/dev/null)
            CURR_HZ=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | .refreshRate' 2>/dev/null)
            CURR_SCALE=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | .scale' 2>/dev/null)
            CURR_X=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | .x' 2>/dev/null)
            CURR_Y=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | .y' 2>/dev/null)
            CURR_CM=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | .colorManagementPreset // "srgb"' 2>/dev/null)
            CURR_BD=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | if (.currentFormat // "" | contains("2101010")) then 10 else 8 end' 2>/dev/null)
            CURR_VRR=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | if .vrr == true then 1 elif .vrr == false then 0 else (.vrr // 0) end' 2>/dev/null)

            HDR=$(jq -r --arg mon "$MON" '.[$mon].hdr // false' "$CONFIG_FILE")
            BITDEPTH=$(jq -r --arg mon "$MON" '.[$mon].bitdepth // 8' "$CONFIG_FILE")
            VRR=$(jq -r --arg mon "$MON" '.[$mon].vrr // 0' "$CONFIG_FILE")
            SDR_LUM=$(jq -r --arg mon "$MON" '.[$mon].sdrLuminance // 80' "$CONFIG_FILE")
            SDR_BRI=$(jq -r --arg mon "$MON" '.[$mon].sdrBrightness // 1.0' "$CONFIG_FILE")
            SDR_SAT=$(jq -r --arg mon "$MON" '.[$mon].sdrSaturation // 1.0' "$CONFIG_FILE")
            SDR_EOTF=$(normalize_eotf "$(jq -r --arg mon "$MON" '.[$mon].sdrEotf // "default"' "$CONFIG_FILE")")
            COLOR_MGMT=$(jq -r --arg mon "$MON" '.[$mon].colorManagement // "srgb"' "$CONFIG_FILE")
            ICC_PROFILE=$(jq -r --arg mon "$MON" '.[$mon].iccProfile // ""' "$CONFIG_FILE")

            WANT_CM="$COLOR_MGMT"
            if [ "$HDR" = "true" ] || [[ "$COLOR_MGMT" =~ ^hdr ]]; then
                WANT_CM="hdr"
                [ "$COLOR_MGMT" = "hdredid" ] && WANT_CM="hdredid"
            elif [ "$COLOR_MGMT" = "default" ] || [ "$COLOR_MGMT" = "null" ]; then
                WANT_CM="$CURR_CM"
            fi

            WANT_HZ_INT=$(printf "%.0f" "$HZ" 2>/dev/null)
            CURR_HZ_INT=$(printf "%.0f" "$CURR_HZ" 2>/dev/null)
            WANT_SCALE_2=$(printf "%.2f" "$SCALE" 2>/dev/null)
            CURR_SCALE_2=$(printf "%.2f" "$CURR_SCALE" 2>/dev/null)

            if [ "$CURR_RES" = "$RES" ] && \
               [ "$CURR_HZ_INT" = "$WANT_HZ_INT" ] && \
               [ "$CURR_SCALE_2" = "$WANT_SCALE_2" ] && \
               [ "$CURR_X" = "$POS_X" ] && \
               [ "$CURR_Y" = "$POS_Y" ] && \
               [ "$CURR_CM" = "$WANT_CM" ] && \
               [ "$CURR_BD" = "$BITDEPTH" ] && \
               [ "$CURR_VRR" = "$VRR" ] && \
               { [ -z "$ICC_PROFILE" ] || [ "$ICC_PROFILE" = "null" ]; }; then
                continue
            fi

            MON_CMD="$MON,$RES@$HZ,${POS_X}x${POS_Y},$SCALE,bitdepth,$BITDEPTH,vrr,$VRR"
            if [ -n "$ICC_PROFILE" ] && [ "$ICC_PROFILE" != "null" ] && [ -f "$ICC_PROFILE" ]; then
                MON_CMD="$MON_CMD,icc,$ICC_PROFILE,sdrbrightness,$SDR_BRI,sdrsaturation,$SDR_SAT,sdr_max_luminance,$SDR_LUM"
            elif [ "$HDR" = "true" ] || [[ "$COLOR_MGMT" =~ ^hdr ]]; then
                APPLIED_CM="hdr"
                [ "$COLOR_MGMT" = "hdredid" ] && APPLIED_CM="hdredid"
                MON_CMD="$MON_CMD,cm,$APPLIED_CM,sdrbrightness,$SDR_BRI,sdrsaturation,$SDR_SAT,sdr_max_luminance,$SDR_LUM"
            elif [ "$COLOR_MGMT" != "default" ] && [ "$COLOR_MGMT" != "srgb" ] && [ "$COLOR_MGMT" != "null" ]; then
                MON_CMD="$MON_CMD,cm,$COLOR_MGMT"
            elif [ "$COLOR_MGMT" = "srgb" ]; then
                MON_CMD="$MON_CMD,cm,srgb"
            fi

            if [ "$SDR_EOTF" = "default" ] || [ "$SDR_EOTF" = "gamma22" ] || [ "$SDR_EOTF" = "srgb" ]; then
                MON_CMD="$MON_CMD,sdr_eotf,$SDR_EOTF"
            fi

            if [ "$CONFIG_PROVIDER" = "lua" ]; then
                "$HYPR_MONITOR_APPLY" monitor "$MON_CMD" >/dev/null 2>&1
            else
                BATCH_CMDS="${BATCH_CMDS}keyword monitor ${MON_CMD} ; "
            fi
        elif [ $IS_NIRI -eq 1 ]; then
            if [ "$POS_X" != "null" ] && [ "$POS_Y" != "null" ]; then
                wlr-randr --output "$MON" --mode "${RES}@${HZ}Hz" --scale "$SCALE" --pos "${POS_X},${POS_Y}"
            else
                wlr-randr --output "$MON" --mode "${RES}@${HZ}Hz" --scale "$SCALE"
            fi
        fi
    done <<< "$MONITORS"

    if [ $IS_HYPRLAND -eq 1 ]; then
        if [ "$CONFIG_PROVIDER" = "lua" ]; then
            "$HYPR_MONITOR_APPLY" focus "$DEFAULT_MONITOR" >/dev/null 2>&1
        elif [ -n "$BATCH_CMDS" ]; then
            if [ -n "$DEFAULT_MONITOR" ] && [ "$DEFAULT_MONITOR" != "null" ]; then
                BATCH_CMDS="${BATCH_CMDS}dispatch focusmonitor ${DEFAULT_MONITOR}"
            fi
            hyprctl --batch "$BATCH_CMDS"
        fi
    fi

    echo "$MISSING_MONITORS"
}

MISSING=$(apply_monitors)

RETRY=0
MAX_RETRY=3
while [ -n "$(echo "$MISSING" | tr -d ' ')" ] && [ $RETRY -lt $MAX_RETRY ]; do
    RETRY=$((RETRY + 1))
    sleep 2
    MISSING=$(apply_monitors)
done
