#!/usr/bin/env bash
# volume_snapshot.sh — Read a snapshot of the active audio output's state.
#
# When the EQ virtual sink (effect_input.eq) is active, the physical device
# (BASE_SINK) is used as the target so that the displayed volume always
# corresponds to the physical device.
#
# Output (one value per line):
#   SINK=<sink-name>    ← sink under control
#   VOL=<0-150>         ← volume as a percentage
#   MUTE=<yes|no>       ← mute state
#
# Dependencies: pactl (pulseaudio-utils), awk, sed

set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/eq_filter_chain.state"

# Find the default sink and any RUNNING sink.
# `|| true` — avoid pipefail when there's no match.
DEFAULT_SINK=$(pactl info | sed -n 's/^Default Sink: //p' | head -n1 || true)
RUNNING_SINK=$(pactl list short sinks \
    | awk '$5 == "RUNNING" {print $2}' \
    | { grep -v '^effect_input\.eq$' || true; } \
    | head -n1)

# Read the persistent BASE_SINK from the EQ state file.
STATE_SINK=""
if [ -f "$STATE_FILE" ]; then
    STATE_SINK=$(awk -F'=' '/^BASE_SINK=/{print $2; exit}' "$STATE_FILE" || true)
fi

# Pick the control target.
CONTROL="$DEFAULT_SINK"
TARGET="$DEFAULT_SINK"

[ -z "$CONTROL" ] && CONTROL="@DEFAULT_SINK@"

if [ -z "$TARGET" ] || [ "$TARGET" = "effect_input.eq" ]; then
    if   [ -n "$RUNNING_SINK" ]; then TARGET="$RUNNING_SINK"
    elif [ -n "$STATE_SINK"   ]; then TARGET="$STATE_SINK"
    else                              TARGET="@DEFAULT_SINK@"
    fi
fi

[ -z "$CONTROL" ] && CONTROL="$TARGET"

# Read volume and mute state.
VOL=$(pactl get-sink-volume "$CONTROL" 2>/dev/null \
    | sed -n 's/.* \([0-9]\+\)%.*/\1/p' \
    | head -n1)
MUTE=$(pactl get-sink-mute "$CONTROL" 2>/dev/null | awk '{print $2}')

[ -z "$VOL"  ] && VOL=0
[ -z "$MUTE" ] && MUTE=no

printf 'SINK=%s\nVOL=%s\nMUTE=%s\n' "$CONTROL" "$VOL" "$MUTE"
