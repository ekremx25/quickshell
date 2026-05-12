#!/bin/sh
# Audio info helper for SoundService.
# Queries default sink/source name, volume, and mute state via pactl.
# Outputs structured KEY=VALUE lines for QML-side parsing.

S=$(/usr/bin/pactl info 2>/dev/null | /usr/bin/awk -F': ' '/^Default Sink:/{print $2; exit}')
SR=$(/usr/bin/pactl info 2>/dev/null | /usr/bin/awk -F': ' '/^Default Source:/{print $2; exit}')

SV=$(/usr/bin/pactl get-sink-volume "$S" 2>/dev/null | /usr/bin/sed -n 's/.* \([0-9]\+\)%.*/\1/p' | /usr/bin/head -n1)
SM=$(/usr/bin/pactl get-sink-mute "$S" 2>/dev/null | /usr/bin/awk '{print $2}')

SRV=$(/usr/bin/pactl get-source-volume "$SR" 2>/dev/null | /usr/bin/sed -n 's/.* \([0-9]\+\)%.*/\1/p' | /usr/bin/head -n1)
SRM=$(/usr/bin/pactl get-source-mute "$SR" 2>/dev/null | /usr/bin/awk '{print $2}')

echo "SINK=${S}"
echo "SOURCE=${SR}"
echo "SINKVOL=${SV:-0}"
echo "SINKMUTE=${SM:-no}"
echo "SOURCEVOL=${SRV:-0}"
echo "SOURCEMUTE=${SRM:-no}"
