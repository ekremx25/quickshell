#!/bin/bash

set -euo pipefail

ACTION="${1:-}"
MONITOR_NAME="${2:-}"
MONITOR_RES="${3:-}"
MONITOR_HZ="${4:-}"
MONITOR_X="${5:-}"
MONITOR_Y="${6:-}"
MONITOR_SCALE="${7:-}"
MONITOR_VRR="${8:-0}"
MONITOR_HDR="${9:-0}"

if [ "$ACTION" != "set" ]; then
    echo "Usage: $0 set NAME WIDTHxHEIGHT HZ X Y SCALE VRR HDR" >&2
    exit 2
fi

case "$MONITOR_NAME" in
    ""|*[!A-Za-z0-9._-]*) echo "Invalid monitor name" >&2; exit 2 ;;
esac
MONITOR_WIDTH="${MONITOR_RES%x*}"
MONITOR_HEIGHT="${MONITOR_RES#*x}"
if [[ ! "$MONITOR_RES" =~ ^[0-9]+x[0-9]+$ ]] \
    || [[ ! "$MONITOR_WIDTH" =~ ^[0-9]+$ ]] \
    || [[ ! "$MONITOR_HEIGHT" =~ ^[0-9]+$ ]] \
    || [[ ! "$MONITOR_HZ" =~ ^[0-9]+([.][0-9]+)?$ ]] \
    || [[ ! "$MONITOR_SCALE" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Invalid numeric monitor value" >&2
    exit 2
fi
if [[ ! "$MONITOR_X" =~ ^[0-9]+$ ]] || [[ ! "$MONITOR_Y" =~ ^[0-9]+$ ]]; then
    echo "Mango monitor positions must be non-negative integers" >&2
    exit 2
fi
case "$MONITOR_VRR:$MONITOR_HDR" in
    0:0|0:1|1:0|1:1) ;;
    *) echo "VRR and HDR must be 0 or 1" >&2; exit 2 ;;
esac

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_FILE="${MANGO_CONFIG_PATH:-$CONFIG_HOME/mango/config.conf}"
CONFIG_DIR="$(dirname "$CONFIG_FILE")"
BEGIN_MARKER="# BEGIN QUICKSHELL MANAGED MONITORS"
END_MARKER="# END QUICKSHELL MANAGED MONITORS"

mkdir -p "$CONFIG_DIR"
[ -e "$CONFIG_FILE" ] || : > "$CONFIG_FILE"

BASE_FILE="$(mktemp "$CONFIG_DIR/.mango-config-base.XXXXXX")"
RULES_FILE="$(mktemp "$CONFIG_DIR/.mango-monitor-rules.XXXXXX")"
NEXT_FILE="$(mktemp "$CONFIG_DIR/.mango-config-next.XXXXXX")"
cleanup() {
    rm -f "$BASE_FILE" "$RULES_FILE" "$NEXT_FILE"
}
trap cleanup EXIT

awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0 == begin { managed = 1; next }
    $0 == end { managed = 0; next }
    !managed { print }
' "$CONFIG_FILE" > "$BASE_FILE"

awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v name="$MONITOR_NAME" '
    $0 == begin { managed = 1; next }
    $0 == end { managed = 0; next }
    managed && index($0, "monitorrule=name:" name ",") != 1 \
        && index($0, "monitorrule=name:^" name "$,") != 1 { print }
' "$CONFIG_FILE" > "$RULES_FILE"

# Remove any legacy Quickshell rule for this exact connector outside the
# managed block while leaving the user's unrelated Mango configuration intact.
awk -v name="$MONITOR_NAME" '
    index($0, "monitorrule=name:" name ",") != 1 \
        && index($0, "monitorrule=name:^" name "$,") != 1 { print }
' "$BASE_FILE" > "$NEXT_FILE"

{
    printf '\n%s\n' "$BEGIN_MARKER"
    cat "$RULES_FILE"
    printf 'monitorrule=name:^%s$,width:%s,height:%s,refresh:%s,x:%s,y:%s,scale:%s,vrr:%s,hdr:%s\n' \
        "$MONITOR_NAME" "$MONITOR_WIDTH" "$MONITOR_HEIGHT" "$MONITOR_HZ" \
        "$MONITOR_X" "$MONITOR_Y" "$MONITOR_SCALE" "$MONITOR_VRR" "$MONITOR_HDR"
    printf '%s\n' "$END_MARKER"
} >> "$NEXT_FILE"

if command -v mango >/dev/null 2>&1; then
    mango -c "$NEXT_FILE" -p >/dev/null
fi

chmod --reference="$CONFIG_FILE" "$NEXT_FILE" 2>/dev/null || chmod 600 "$NEXT_FILE"
mv -f "$NEXT_FILE" "$CONFIG_FILE"
