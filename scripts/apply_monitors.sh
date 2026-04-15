#!/bin/bash

# Applies monitor settings from monitor_config.json
# Uses hyprctl --batch for single-refresh application
# Skips monitors already matching desired config to avoid flicker

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_FILE="$CONFIG_HOME/quickshell/monitor_config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

# Determine compositor
IS_HYPRLAND=0
IS_NIRI=0
IS_MANGO=0

if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    IS_HYPRLAND=1
elif [ -n "$NIRI_SOCKET" ]; then
    IS_NIRI=1
elif command -v mmsg >/dev/null 2>&1; then
    IS_MANGO=1
fi

if [ $IS_HYPRLAND -eq 0 ] && [ $IS_NIRI -eq 0 ] && [ $IS_MANGO -eq 0 ]; then
    exit 0
fi

# Read keys from JSON using jq
MONITORS=$(jq -r 'keys[]' "$CONFIG_FILE" 2>/dev/null)
DEFAULT_MONITOR=$(jq -r 'to_entries[] | select(.value.default == true) | .key' "$CONFIG_FILE" 2>/dev/null | head -n1)

apply_monitors() {
    local MISSING_MONITORS=""
    local BATCH_CMDS=""

    if [ $IS_HYPRLAND -eq 1 ]; then
        # Get current monitor state as JSON for comparison
        CURRENT_STATE=$(hyprctl monitors all -j 2>/dev/null)
        CONNECTED_MONITORS=$(echo "$CURRENT_STATE" | jq -r '.[].name' 2>/dev/null)
    fi

    while IFS= read -r MON; do
        [ -n "$MON" ] || continue

        RES=$(jq -r --arg mon "$MON" '.[$mon].res' "$CONFIG_FILE")
        HZ=$(jq -r --arg mon "$MON" '.[$mon].hz' "$CONFIG_FILE")
        SCALE=$(jq -r --arg mon "$MON" '.[$mon].scale' "$CONFIG_FILE")
        POS_X=$(jq -r --arg mon "$MON" '.[$mon].posX' "$CONFIG_FILE")
        POS_Y=$(jq -r --arg mon "$MON" '.[$mon].posY' "$CONFIG_FILE")

        if [ "$RES" != "null" ] && [ "$HZ" != "null" ] && [ "$SCALE" != "null" ] && [ "$RES" != "0x0" ]; then
            if [ $IS_HYPRLAND -eq 1 ]; then
                if ! printf '%s\n' "$CONNECTED_MONITORS" | grep -Fxq "$MON"; then
                    MISSING_MONITORS="$MISSING_MONITORS $MON"
                    continue
                fi

                # Check if monitor already matches desired config
                CURR_RES=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | "\(.width)x\(.height)"' 2>/dev/null)
                CURR_HZ=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | .refreshRate' 2>/dev/null)
                CURR_SCALE=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | .scale' 2>/dev/null)
                CURR_X=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | .x' 2>/dev/null)
                CURR_Y=$(echo "$CURRENT_STATE" | jq -r --arg m "$MON" '.[] | select(.name==$m) | .y' 2>/dev/null)

                # Compare: skip if res, position, and scale already match
                WANT_HZ_INT=$(printf "%.0f" "$HZ" 2>/dev/null)
                CURR_HZ_INT=$(printf "%.0f" "$CURR_HZ" 2>/dev/null)
                WANT_SCALE_2=$(printf "%.2f" "$SCALE" 2>/dev/null)
                CURR_SCALE_2=$(printf "%.2f" "$CURR_SCALE" 2>/dev/null)

                if [ "$CURR_RES" = "$RES" ] && \
                   [ "$CURR_HZ_INT" = "$WANT_HZ_INT" ] && \
                   [ "$CURR_SCALE_2" = "$WANT_SCALE_2" ] && \
                   [ "$CURR_X" = "$POS_X" ] && \
                   [ "$CURR_Y" = "$POS_Y" ]; then
                    continue
                fi

                HDR=$(jq -r --arg mon "$MON" '.[$mon].hdr // false' "$CONFIG_FILE")
                BITDEPTH=$(jq -r --arg mon "$MON" '.[$mon].bitdepth // 8' "$CONFIG_FILE")
                VRR=$(jq -r --arg mon "$MON" '.[$mon].vrr // 0' "$CONFIG_FILE")
                SDR_BRI=$(jq -r --arg mon "$MON" '.[$mon].sdrBrightness // 1.0' "$CONFIG_FILE")
                SDR_SAT=$(jq -r --arg mon "$MON" '.[$mon].sdrSaturation // 1.0' "$CONFIG_FILE")
                COLOR_MGMT=$(jq -r --arg mon "$MON" '.[$mon].colorManagement // "srgb"' "$CONFIG_FILE")

                MON_CMD="$MON,$RES@$HZ,${POS_X}x${POS_Y},$SCALE,bitdepth,$BITDEPTH,vrr,$VRR"
                if [ "$HDR" = "true" ] || [[ "$COLOR_MGMT" =~ ^hdr ]]; then
                    local APPLIED_CM="hdr"
                    [ "$COLOR_MGMT" = "hdredid" ] && APPLIED_CM="hdredid"
                    MON_CMD="$MON_CMD,cm,$APPLIED_CM,sdrbrightness,$SDR_BRI,sdrsaturation,$SDR_SAT"
                elif [ "$COLOR_MGMT" != "default" ] && [ "$COLOR_MGMT" != "srgb" ] && [ "$COLOR_MGMT" != "null" ]; then
                    MON_CMD="$MON_CMD,cm,$COLOR_MGMT"
                fi
                BATCH_CMDS="${BATCH_CMDS}keyword monitor ${MON_CMD} ; "
            elif [ $IS_NIRI -eq 1 ]; then
                if [ "$POS_X" != "null" ] && [ "$POS_Y" != "null" ]; then
                    wlr-randr --output "$MON" --mode "${RES}@${HZ}Hz" --scale "$SCALE" --pos "${POS_X},${POS_Y}"
                else
                    wlr-randr --output "$MON" --mode "${RES}@${HZ}Hz" --scale "$SCALE"
                fi
            fi
        fi
    done <<< "$MONITORS"

    # Hyprland: apply all changed monitors in a single batch call
    if [ $IS_HYPRLAND -eq 1 ] && [ -n "$BATCH_CMDS" ]; then
        if [ -n "$DEFAULT_MONITOR" ] && [ "$DEFAULT_MONITOR" != "null" ]; then
            BATCH_CMDS="${BATCH_CMDS}dispatch focusmonitor ${DEFAULT_MONITOR}"
        fi
        hyprctl --batch "$BATCH_CMDS"
    fi

    echo "$MISSING_MONITORS"
}

# First attempt
MISSING=$(apply_monitors)

# Retry up to 3 times for monitors not yet connected (e.g. slow USB-C/dock displays)
RETRY=0
MAX_RETRY=3
while [ -n "$(echo "$MISSING" | tr -d ' ')" ] && [ $RETRY -lt $MAX_RETRY ]; do
    RETRY=$((RETRY + 1))
    sleep 2
    MISSING=$(apply_monitors)
done
