#!/bin/sh
# Bluetooth status helper for BluetoothPage.
# Outputs structured lines: POWERED=yes/no and DEVICE=mac|name|connected|icon
# Called as direct argv from QML — no shell escaping concerns.

POWER=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}')
echo "POWERED=${POWER:-no}"

bluetoothctl paired-devices 2>/dev/null | awk '{print $2}' | while read -r MAC; do
    [ -z "$MAC" ] && continue
    INFO=$(bluetoothctl info "$MAC" 2>/dev/null)
    NAME=$(printf '%s\n' "$INFO" | awk -F': ' '/^\tName:/{print $2; exit}')
    CONN=$(printf '%s\n' "$INFO" | awk '/Connected:/{print $2; exit}')
    TYPE=$(printf '%s\n' "$INFO" | awk -F': ' '/Icon:/{print $2; exit}')
    echo "DEVICE=${MAC}|${NAME:-$MAC}|${CONN:-no}|${TYPE}"
done
