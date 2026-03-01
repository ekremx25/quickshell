#!/bin/bash

# ~/.config/quickshell/scripts/apply_monitors.sh
# Applies monitor settings from monitor_config.json

CONFIG_FILE="$HOME/.config/quickshell/monitor_config.json"

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

for MON in $MONITORS; do
    RES=$(jq -r ".\"$MON\".res" "$CONFIG_FILE")
    HZ=$(jq -r ".\"$MON\".hz" "$CONFIG_FILE")
    SCALE=$(jq -r ".\"$MON\".scale" "$CONFIG_FILE")
    POS_X=$(jq -r ".\"$MON\".posX" "$CONFIG_FILE")
    POS_Y=$(jq -r ".\"$MON\".posY" "$CONFIG_FILE")

    if [ "$RES" != "null" ] && [ "$HZ" != "null" ] && [ "$SCALE" != "null" ]; then
        if [ $IS_HYPRLAND -eq 1 ]; then
            # hyprctl keyword monitor name,res@hz,XxY,scale[,extra_params]
            HDR=$(jq -r ".\"$MON\".hdr // false" "$CONFIG_FILE")
            BITDEPTH=$(jq -r ".\"$MON\".bitdepth // 8" "$CONFIG_FILE")
            VRR=$(jq -r ".\"$MON\".vrr // 0" "$CONFIG_FILE")
            SDR_LUM=$(jq -r ".\"$MON\".sdrLuminance // 450" "$CONFIG_FILE")
            SDR_BRI=$(jq -r ".\"$MON\".sdrBrightness // 1.0" "$CONFIG_FILE")
            SDR_SAT=$(jq -r ".\"$MON\".sdrSaturation // 1.0" "$CONFIG_FILE")

            MON_CMD="$MON,$RES@$HZ,${POS_X}x${POS_Y},$SCALE,bitdepth,$BITDEPTH,vrr,$VRR"
            if [ "$HDR" = "true" ]; then
                MON_CMD="$MON_CMD,cm,hdr,sdrbrightness,$SDR_BRI,sdrsaturation,$SDR_SAT"
            fi
            hyprctl keyword monitor "$MON_CMD"
        elif [ $IS_NIRI -eq 1 ]; then
            WLR_CMD="wlr-randr --output \"$MON\" --mode \"${RES}@${HZ}Hz\" --scale \"$SCALE\""
            if [ "$POS_X" != "null" ] && [ "$POS_Y" != "null" ]; then
                WLR_CMD="$WLR_CMD --pos ${POS_X},${POS_Y}"
            fi
            eval $WLR_CMD
        fi
    fi
done
