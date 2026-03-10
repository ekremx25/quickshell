#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="${HOME}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME_DIR/.config}"
QS_DIR="${QUICKSHELL_CONFIG_DIR:-$CONFIG_DIR/quickshell}"
EQ_DIR="$QS_DIR/eq"
EQ_FILE="$EQ_DIR/parametric-eq.txt"
PW_CONF_DIR="${PIPEWIRE_CONF_DIR:-$CONFIG_DIR/pipewire/pipewire.conf.d}"
PW_CONF_FILE="$PW_CONF_DIR/90-quickshell-eq.conf"
STATE_DIR="${XDG_STATE_HOME:-$HOME_DIR/.local/state}/quickshell"
STATE_FILE="$STATE_DIR/eq_filter_chain.state"

mkdir -p "$EQ_DIR" "$PW_CONF_DIR" "$STATE_DIR"

FREQS=(31 63 125 250 500 1000 2000 4000 8000 16000)

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

check_deps() {
  local deps=(pactl wpctl pw-cli pw-link awk grep head sed tr systemctl)
  for c in "${deps[@]}"; do
    need_cmd "$c"
  done
}

read_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

write_state() {
  cat > "$STATE_FILE" <<STATE
BASE_SINK=${BASE_SINK:-}
BASE_SOURCE=${BASE_SOURCE:-}
STATE
}

default_sink() {
  pactl info | awk -F': ' '/^Default Sink:/ {print $2; exit}'
}

default_source() {
  pactl info | awk -F': ' '/^Default Source:/ {print $2; exit}'
}

node_id_by_name() {
  local type="$1"
  local name="$2"
  pw-cli ls "$type" | awk -v want="$name" '
    /^	id / {gsub(",","",$2); id=$2}
    /node.name = "/ {
      line=$0
      sub(/^.*node.name = "/,"",line)
      sub(/".*$/,"",line)
      if (line == want && id != "") { print id; exit }
    }
  '
}

set_default_sink_compat() {
  local sink_name="$1"
  local sink_id=""
  for _ in {1..10}; do
    sink_id="$(node_id_by_name Node "$sink_name" || true)"
    if [[ -n "$sink_id" ]]; then
      wpctl set-default "$sink_id" >/dev/null 2>&1 && break || true
    fi
    sleep 0.2
  done
  pactl set-default-sink "$sink_name" >/dev/null 2>&1 || true
}

set_default_source_compat() {
  local source_name="$1"
  local source_id=""
  for _ in {1..10}; do
    source_id="$(node_id_by_name Node "$source_name" || true)"
    if [[ -n "$source_id" ]]; then
      wpctl set-default "$source_id" >/dev/null 2>&1 && break || true
    fi
    sleep 0.2
  done
  pactl set-default-source "$source_name" >/dev/null 2>&1 || true
}

move_sink_inputs_to() {
  local sink_name="$1"
  local input_id=""

  while read -r input_id _; do
    [[ -n "$input_id" ]] || continue
    pactl move-sink-input "$input_id" "$sink_name" >/dev/null 2>&1 || true
  done < <(pactl list short sink-inputs 2>/dev/null || true)
}

relink_eq_output_to_base_sink() {
  local sink_name="$1"
  local candidate=""

  [[ -n "$sink_name" ]] || return 0

  while read -r _ candidate _; do
    [[ -n "$candidate" ]] || continue
    [[ "$candidate" == "effect_input.eq" ]] && continue
    pw-link -d effect_output.eq:output_1 "$candidate:playback_FL" >/dev/null 2>&1 || true
    pw-link -d effect_output.eq:output_2 "$candidate:playback_FR" >/dev/null 2>&1 || true
  done < <(pactl list short sinks 2>/dev/null || true)

  for _ in {1..20}; do
    if pw-link "effect_output.eq:output_1" "$sink_name:playback_FL" >/dev/null 2>&1 &&
       pw-link "effect_output.eq:output_2" "$sink_name:playback_FR" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  echo "Failed to relink EQ output to $sink_name" >&2
  return 1
}

mute_non_target_sinks() {
  :
}

first_real_sink() {
  pactl list short sinks | awk '{print $2}' | grep -Ev '^effect_input\.eq$' | head -n1
}

running_real_sink() {
  pactl list short sinks | awk '$5 == "RUNNING" {print $2}' | grep -Ev '^effect_input\.eq$' | head -n1
}

sink_exists() {
  local sink="$1"
  pactl list short sinks | awk '{print $2}' | grep -Fxq "$sink"
}

is_virtual_eq_sink() {
  [[ "${1:-}" == "effect_input.eq" ]]
}

source_exists() {
  local source="$1"
  pactl list short sources | awk '{print $2}' | grep -Fxq "$source"
}

first_real_source() {
  pactl list short sources | awk '{print $2}' | grep -Ev '^effect_(input|output)\.eq(\.monitor)?$' | head -n1
}

running_real_source() {
  pactl list short sources | awk '$5 == "RUNNING" {print $2}' | grep -Ev '^effect_(input|output)\.eq(\.monitor)?$' | head -n1
}

pick_best_sink() {
  local cur_sink="${1:-}"
  local remembered_sink="${2:-}"
  local running_sink=""
  if [[ -n "$cur_sink" && "$cur_sink" != "effect_input.eq" ]] && sink_exists "$cur_sink"; then
    echo "$cur_sink"
    return
  fi
  running_sink="$(running_real_sink || true)"
  if [[ -n "$running_sink" ]] && sink_exists "$running_sink"; then
    echo "$running_sink"
    return
  fi
  if [[ -n "$remembered_sink" ]] && sink_exists "$remembered_sink"; then
    echo "$remembered_sink"
    return
  fi
  first_real_sink || true
}

pick_best_source() {
  local cur_source="${1:-}"
  local remembered_source="${2:-}"
  local running_source=""
  if [[ -n "$cur_source" && ! "$cur_source" =~ ^effect_(input|output)\.eq(\.monitor)?$ ]] && source_exists "$cur_source"; then
    echo "$cur_source"
    return
  fi
  running_source="$(running_real_source || true)"
  if [[ -n "$running_source" ]] && source_exists "$running_source"; then
    echo "$running_source"
    return
  fi
  if [[ -n "$remembered_source" ]] && source_exists "$remembered_source"; then
    echo "$remembered_source"
    return
  fi
  first_real_source || true
}

ensure_gains() {
  if [[ "$#" -ne 10 ]]; then
    echo "Expected 10 gains, got $#" >&2
    exit 1
  fi

  local out=()
  for g in "$@"; do
    if [[ "$g" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
      out+=("$g")
    else
      out+=("0")
    fi
  done
  printf '%s\n' "${out[@]}"
}

write_eq_file() {
  local gains=("$@")
  {
    echo "Preamp: 0 dB"
    for i in "${!FREQS[@]}"; do
      local idx=$((i + 1))
      echo "Filter ${idx}: ON PK Fc ${FREQS[$i]} Hz Gain ${gains[$i]} dB Q 1.000"
    done
  } > "$EQ_FILE"
}

write_pipewire_conf() {
  cat > "$PW_CONF_FILE" <<CONF
context.modules = [
  {
    name = libpipewire-module-parametric-equalizer
    args = {
      equalizer.filepath = "$EQ_FILE"
      equalizer.description = "Quickshell EQ"

      capture.props = {
        node.name = "effect_input.eq"
        node.description = "Quickshell EQ Sink"
        media.class = "Audio/Sink"
      }

      playback.props = {
        node.name = "effect_output.eq"
        node.description = "Quickshell EQ Output"
        node.passive = true
        node.autoconnect = false
      }
    }
  }
]
CONF
}

restart_audio_stack() {
  systemctl --user restart pipewire.service pipewire-pulse.service
  for _ in {1..30}; do
    if pactl info >/dev/null 2>&1; then
      sleep 0.2
      return
    fi
    sleep 0.2
  done
}

wait_for_eq_nodes() {
  for _ in {1..30}; do
    if sink_exists "effect_input.eq" && node_id_by_name Node "effect_output.eq" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  echo "EQ nodes did not come up in time" >&2
  return 1
}

stabilize_eq_route() {
  local sink_name="$1"

  [[ -n "$sink_name" ]] || return 0

  for _ in {1..5}; do
    relink_eq_output_to_base_sink "$sink_name" || true
    move_sink_inputs_to "effect_input.eq" || true
    sleep 0.3
  done
}

recover_eq() {
  read_state

  local sink="${BASE_SINK:-}"
  if [[ -z "$sink" || "$sink" == "effect_input.eq" ]]; then
    sink="$(pick_best_sink "$(default_sink || true)" "${BASE_SINK:-}")"
  fi

  wait_for_eq_nodes || true
  [[ -n "$sink" ]] && stabilize_eq_route "$sink" || true
  set_default_sink_compat "effect_input.eq" || true
  [[ -n "${BASE_SOURCE:-}" ]] && set_default_source_compat "$BASE_SOURCE" || true
  echo "recovered"
}

apply_eq() {
  local target_sink="${1:-auto}"
  shift
  local gains=("$@")

  read_state
  local cur_sink cur_source
  cur_sink="$(default_sink || true)"
  cur_source="$(default_source || true)"

  if [[ "$target_sink" != "auto" ]]; then
    if is_virtual_eq_sink "$target_sink"; then
      target_sink="auto"
    fi
    if sink_exists "$target_sink"; then
      BASE_SINK="$target_sink"
    else
      echo "Requested sink not found: $target_sink" >&2
      exit 1
    fi
  else
    BASE_SINK="$(pick_best_sink "$cur_sink" "${BASE_SINK:-}")"
  fi

  BASE_SOURCE="$(pick_best_source "$cur_source" "${BASE_SOURCE:-}")"

  write_eq_file "${gains[@]}"
  write_pipewire_conf
  write_state

  restart_audio_stack
  wait_for_eq_nodes || true

  [[ -n "${BASE_SINK:-}" ]] && stabilize_eq_route "$BASE_SINK" || true
  set_default_sink_compat "effect_input.eq" || true
  [[ -n "${BASE_SOURCE:-}" ]] && set_default_source_compat "$BASE_SOURCE" || true
  echo "applied file=$EQ_FILE"
}

disable_eq() {
  read_state

  rm -f "$PW_CONF_FILE"
  restart_audio_stack

  local sink="${BASE_SINK:-}"
  if [[ -z "$sink" || "$sink" == "effect_input.eq" ]]; then
    sink="$(first_real_sink || true)"
  fi
  [[ -n "$sink" ]] && set_default_sink_compat "$sink" || true

  local cur_source src
  cur_source="$(default_source || true)"
  src="${BASE_SOURCE:-}"
  if [[ -z "$src" || "$src" =~ ^effect_(input|output)\.eq(\.monitor)?$ ]]; then
    src="$(first_real_source || true)"
  fi
  if [[ "$cur_source" =~ ^effect_(input|output)\.eq(\.monitor)?$ && -n "$src" ]]; then
    set_default_source_compat "$src" || true
  fi

  echo "disabled"
}

status_eq() {
  read_state
  echo "qs_dir=$QS_DIR"
  echo "conf=$PW_CONF_FILE"
  echo "eq_file=$EQ_FILE"
  echo "base_sink=${BASE_SINK:-}"
  echo "base_source=${BASE_SOURCE:-}"
  echo "default_sink=$(default_sink || true)"
  echo "default_source=$(default_source || true)"
  echo "conf_exists=$([[ -f "$PW_CONF_FILE" ]] && echo yes || echo no)"
}

cmd="${1:-status}"
shift || true

check_deps

case "$cmd" in
  apply)
    if [[ "$#" -lt 10 ]]; then
      echo "Usage: $0 apply <10 gains> [target_sink|auto]" >&2
      exit 2
    fi
    target_sink="${11:-auto}"
    mapfile -t gains < <(ensure_gains "${@:1:10}")
    apply_eq "$target_sink" "${gains[@]}"
    ;;
  disable)
    disable_eq
    ;;
  recover)
    recover_eq
    ;;
  status)
    status_eq
    ;;
  *)
    echo "Usage: $0 {apply <10 gains> [target_sink|auto]|disable|recover|status}" >&2
    exit 2
    ;;
esac
