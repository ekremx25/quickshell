#!/usr/bin/env bash
# volume_snapshot.sh — Aktif ses çıkışının anlık durumunu okur.
#
# EQ sanal sink (effect_input.eq) aktifken gerçek cihazı (BASE_SINK)
# hedef olarak kullanır; böylece görünen ses seviyesi her zaman fiziksel
# cihaza karşılık gelir.
#
# Çıktı (her satır bir değer):
#   SINK=<sink-adı>     ← kontrol edilen sink
#   VOL=<0-150>         ← yüzde olarak ses seviyesi
#   MUTE=<yes|no>       ← sessizleştirme durumu
#
# Bağımlılıklar: pactl (pulseaudio-utils), awk, sed

set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/eq_filter_chain.state"

# Varsayılan ve çalışan (RUNNING) sink'i al
# "|| true": boş sonuç veya eşleşme olmadığında pipefail'dan kaçın
DEFAULT_SINK=$(pactl info | sed -n 's/^Default Sink: //p' | head -n1 || true)
RUNNING_SINK=$(pactl list short sinks \
    | awk '$5 == "RUNNING" {print $2}' \
    | { grep -v '^effect_input\.eq$' || true; } \
    | head -n1)

# EQ state dosyasından kalıcı BASE_SINK'i oku
STATE_SINK=""
if [ -f "$STATE_FILE" ]; then
    STATE_SINK=$(awk -F'=' '/^BASE_SINK=/{print $2; exit}' "$STATE_FILE" || true)
fi

# Kontrol hedefini belirle
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

# Ses seviyesi ve sessizlik durumunu oku
VOL=$(pactl get-sink-volume "$CONTROL" 2>/dev/null \
    | sed -n 's/.* \([0-9]\+\)%.*/\1/p' \
    | head -n1)
MUTE=$(pactl get-sink-mute "$CONTROL" 2>/dev/null | awk '{print $2}')

[ -z "$VOL"  ] && VOL=0
[ -z "$MUTE" ] && MUTE=no

printf 'SINK=%s\nVOL=%s\nMUTE=%s\n' "$CONTROL" "$VOL" "$MUTE"
