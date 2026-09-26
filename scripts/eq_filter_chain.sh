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
TRANSACTION_FILE="$STATE_DIR/eq_filter_chain.pending"

mkdir -p "$EQ_DIR" "$PW_CONF_DIR" "$STATE_DIR"

FREQS=(31 63 125 250 500 1000 2000 4000 8000 16000)

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

check_deps() {
  local deps=(pactl wpctl pw-cli pw-link awk grep head sed tr systemctl mktemp mv cp cmp chmod)
  for c in "${deps[@]}"; do
    need_cmd "$c"
  done
}

read_state() {
  BASE_SINK="" BASE_SOURCE="" EQ_SINK_VOLUME="40%" EQ_SINK_MUTED="0"
  local line key value
  [[ -f "$STATE_FILE" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      BASE_SINK) BASE_SINK="$value" ;;
      BASE_SOURCE) BASE_SOURCE="$value" ;;
      EQ_SINK_VOLUME) [[ "$value" =~ ^[0-9]+%$ ]] && EQ_SINK_VOLUME="$value" ;;
      EQ_SINK_MUTED) [[ "$value" == 0 || "$value" == 1 ]] && EQ_SINK_MUTED="$value" ;;
    esac
  done < "$STATE_FILE"
  return 0
}

write_state() (
  # Replace on the same filesystem: readers see either the old or complete new state.
  umask 077
  local tmp value
  for value in "${BASE_SINK:-}" "${BASE_SOURCE:-}" "${EQ_SINK_VOLUME:-40%}" "${EQ_SINK_MUTED:-0}"; do
    if [[ "$value" == *$'\n'* || "$value" == *$'\r'* ]]; then
      echo "Invalid multiline EQ state value" >&2
      return 1
    fi
  done
  tmp="$(mktemp "$STATE_DIR/.eq-state.XXXXXX")" || return 1
  trap 'rm -f -- "$tmp"' EXIT
  printf 'BASE_SINK=%s\nBASE_SOURCE=%s\nEQ_SINK_VOLUME=%s\nEQ_SINK_MUTED=%s\n' \
    "${BASE_SINK:-}" "${BASE_SOURCE:-}" "${EQ_SINK_VOLUME:-40%}" "${EQ_SINK_MUTED:-0}" > "$tmp" || return 1
  mv -f -- "$tmp" "$STATE_FILE"
)

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
      if (line == want && id != "" && found == "") found=id
    }
    # Drain the producer: early exit can SIGPIPE pw-cli under pipefail.
    END { if (found != "") print found }
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
  pactl set-default-sink "$sink_name" >/dev/null 2>&1 || { echo "Failed to set default sink: $sink_name" >&2; return 1; }
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
  pactl set-default-source "$source_name" >/dev/null 2>&1 || { echo "Failed to restore default source: $source_name" >&2; return 1; }
}

move_sink_inputs_to() {
  local sink_name="$1"
  local input_id=""

  local inputs
  inputs="$(pactl list short sink-inputs)" || { echo "Failed to list playback streams" >&2; return 1; }
  while read -r input_id _; do
    [[ -n "$input_id" ]] || continue
    if ! pactl move-sink-input "$input_id" "$sink_name" >/dev/null 2>&1; then
      # A short-lived stream can disappear between listing and moving it.
      local current_inputs current_id still_present=false
      current_inputs="$(pactl list short sink-inputs)" || { echo "Failed to recheck playback streams" >&2; return 1; }
      while read -r current_id _; do
        if [[ "$current_id" == "$input_id" ]]; then
          still_present=true
          break
        fi
      done <<< "$current_inputs"
      if [[ "$still_present" == true ]]; then
        echo "Failed to move playback stream: $input_id" >&2
        return 1
      fi
    fi
  done <<< "$inputs"
}

capture_eq_sink_state() {
  if sink_exists "effect_input.eq"; then
    EQ_SINK_VOLUME="$(pactl get-sink-volume "effect_input.eq" 2>/dev/null | sed -n 's/.* \([0-9]\+%\).*/\1/p' | head -n1 || true)"
    EQ_SINK_MUTED="$(pactl get-sink-mute "effect_input.eq" 2>/dev/null | awk '{print ($2 == "yes" ? "1" : "0")}' || true)"
  fi

  [[ -n "${EQ_SINK_VOLUME:-}" ]] || EQ_SINK_VOLUME="40%"
  [[ -n "${EQ_SINK_MUTED:-}" ]] || EQ_SINK_MUTED="0"
}

normalize_eq_sink() {
  if sink_exists "effect_input.eq"; then
    pactl set-sink-volume "effect_input.eq" "${EQ_SINK_VOLUME:-40%}" >/dev/null 2>&1 || { echo "Failed to restore EQ volume" >&2; return 1; }
    pactl set-sink-mute "effect_input.eq" "${EQ_SINK_MUTED:-0}" >/dev/null 2>&1 || { echo "Failed to restore EQ mute state" >&2; return 1; }
  else
    echo "EQ sink disappeared while restoring volume" >&2
    return 1
  fi
}

relink_eq_output_to_base_sink() {
  local sink_name="$1"
  local candidate="" ports left_port="effect_output.eq:output_1" right_port="effect_output.eq:output_2"
  ports="$(pw-link -o)" || return 1
  if grep -Fx 'effect_output.eq:output_FL' <<< "$ports" >/dev/null; then
    left_port="effect_output.eq:output_FL"; right_port="effect_output.eq:output_FR"
  fi

  [[ -n "$sink_name" ]] || return 0

  while read -r _ candidate _; do
    [[ -n "$candidate" ]] || continue
    [[ "$candidate" == "effect_input.eq" ]] && continue
    pw-link -d "$left_port" "$candidate:playback_FL" >/dev/null 2>&1 || true
    pw-link -d "$right_port" "$candidate:playback_FR" >/dev/null 2>&1 || true
  done < <(pactl list short sinks 2>/dev/null || true)

  local left_connected=false right_connected=false
  for _ in {1..20}; do
    if [[ "$left_connected" == false ]]; then
      if pw-link "$left_port" "$sink_name:playback_FL" >/dev/null 2>&1; then left_connected=true; fi
    fi
    if [[ "$right_connected" == false ]]; then
      if pw-link "$right_port" "$sink_name:playback_FR" >/dev/null 2>&1; then right_connected=true; fi
    fi
    if [[ "$left_connected" == true && "$right_connected" == true ]]; then return 0; fi
    sleep 0.2
  done

  # Do not leave a half-connected stereo route after exhausting retries.
  if [[ "$left_connected" == true ]]; then
    pw-link -d "$left_port" "$sink_name:playback_FL" >/dev/null 2>&1 || echo "Failed to clean up left EQ channel" >&2
  fi
  if [[ "$right_connected" == true ]]; then
    pw-link -d "$right_port" "$sink_name:playback_FR" >/dev/null 2>&1 || echo "Failed to clean up right EQ channel" >&2
  fi
  echo "Failed to relink EQ output to $sink_name" >&2
  return 1
}

first_real_sink() {
  pactl list short sinks | awk '{print $2}' | grep -Ev '^effect_input\.eq$' | head -n1
}

running_real_sink() {
  pactl list short sinks | awk '$5 == "RUNNING" {print $2}' | grep -Ev '^effect_input\.eq$' | head -n1
}

sink_exists() {
  local sink="$1"
  pactl list short sinks | awk '{print $2}' | grep -Fxq -- "$sink"
}

is_virtual_eq_sink() {
  [[ "${1:-}" == "effect_input.eq" ]]
}

source_exists() {
  local source="$1"
  pactl list short sources | awk '{print $2}' | grep -Fxq -- "$source"
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
  if [[ -n "$remembered_sink" && "$remembered_sink" != "effect_input.eq" ]] && sink_exists "$remembered_sink"; then
    echo "$remembered_sink"
    return
  fi
  running_sink="$(running_real_sink || true)"
  if [[ -n "$running_sink" ]] && sink_exists "$running_sink"; then
    echo "$running_sink"
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
  if [[ -n "$remembered_source" ]] && source_exists "$remembered_source"; then
    echo "$remembered_source"
    return
  fi
  running_source="$(running_real_source || true)"
  if [[ -n "$running_source" ]] && source_exists "$running_source"; then
    echo "$running_source"
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
  local gains=("$@") i
  {
    echo '# quickshell-live-eq-v1'
    echo 'context.modules = [ { name = libpipewire-module-filter-chain args = {'
    echo 'node.description = "Quickshell EQ" audio.channels = 2 audio.position = [ FL FR ]'
    echo 'filter.graph = { nodes = ['
    for i in "${!FREQS[@]}"; do
      printf '{ type = builtin name = eq%d label = bq_peaking control = { Freq = %s Q = 1.0 Gain = %s } }\n' "$((i+1))" "${FREQS[$i]}" "${gains[$i]}"
    done
    echo '] links = ['
    for i in {1..9}; do printf '{ output = "eq%d:Out" input = "eq%d:In" }\n' "$i" "$((i+1))"; done
    echo '] inputs = [ "eq1:In" ] outputs = [ "eq10:Out" ] }'
    echo 'capture.props = { node.name = "effect_input.eq" node.description = "Quickshell EQ Sink" media.class = "Audio/Sink" }'
    echo 'playback.props = { node.name = "effect_output.eq" node.description = "Quickshell EQ Output" node.passive = true node.autoconnect = false }'
    echo '} } ]'
  } > "$PW_CONF_FILE"
}

set_live_gains() {
  local node="$1"; shift
  local params='{ params = [' i=1 gain
  for gain in "$@"; do
    [[ "$gain" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || return 1
    params+=" \"eq$i:Gain\" $gain"
    i=$((i+1))
  done
  params+=' ] }'
  pw-cli set-param "$node" Props "$params" || { echo "Failed to update live EQ controls" >&2; return 1; }
}

restart_audio_stack() {
  systemctl --user restart pipewire.service pipewire-pulse.service || { echo "Failed to restart audio services" >&2; return 1; }
  for _ in {1..30}; do
    if pactl info >/dev/null 2>&1; then
      sleep 0.2
      return
    fi
    sleep 0.2
  done
  echo "Audio server did not become ready" >&2
  return 1
}

wait_for_eq_nodes() {
  local output_id
  for _ in {1..30}; do
    if sink_exists "effect_input.eq" && output_id="$(node_id_by_name Node "effect_output.eq" 2>/dev/null)" && [[ -n "$output_id" ]]; then
      return 0
    fi
    sleep 0.2
  done
  echo "EQ nodes did not come up in time" >&2
  return 1
}

wait_for_sink() {
  local sink_name="$1"
  [[ -n "$sink_name" ]] || return 0
  for _ in {1..100}; do
    if sink_exists "$sink_name"; then
      return 0
    fi
    sleep 0.2
  done
  echo "Timed out waiting for sink: $sink_name" >&2
  return 1
}

wait_for_source() {
  local source_name="$1"
  [[ -n "$source_name" ]] || return 0
  for _ in {1..100}; do
    if source_exists "$source_name"; then
      return 0
    fi
    sleep 0.2
  done
  echo "Timed out waiting for source: $source_name" >&2
  return 1
}

stabilize_eq_route() {
  local sink_name="$1"

  [[ -n "$sink_name" ]] || return 0

  for _ in {1..5}; do
    relink_eq_output_to_base_sink "$sink_name" || return 1
    move_sink_inputs_to "effect_input.eq" || return 1
    sleep 0.3
  done
}

finalize_eq_route() {
  local sink_name="$1"

  [[ -n "$sink_name" ]] || return 0

  for _ in {1..8}; do
    relink_eq_output_to_base_sink "$sink_name" || return 1
    set_default_sink_compat "effect_input.eq" || return 1
    move_sink_inputs_to "effect_input.eq" || return 1
    sleep 0.25
  done
}

recover_eq() {
  # The delayed UI recovery may arrive after disable completed.
  if [[ ! -f "$PW_CONF_FILE" ]]; then
    echo "EQ disabled; recovery skipped"
    return 0
  fi
  read_state
  capture_eq_sink_state

  local sink
  sink="$(pick_best_sink "$(default_sink || true)" "${BASE_SINK:-}")"

  wait_for_eq_nodes || return 1
  [[ -n "$sink" ]] || { echo "No physical output sink available" >&2; return 1; }
  wait_for_sink "$sink" || return 1
  stabilize_eq_route "$sink" || return 1
  normalize_eq_sink
  set_default_sink_compat "effect_input.eq" || return 1
  [[ -n "${BASE_SOURCE:-}" ]] && set_default_source_compat "$BASE_SOURCE" || true
  BASE_SINK="$sink"
  write_state
  echo "recovered"
}

apply_eq() (
  local target_sink="${1:-auto}"
  shift
  local gains=("$@")

  read_state
  capture_eq_sink_state
  local cur_sink cur_source
  cur_sink="$(default_sink || true)"
  cur_source="$(default_source || true)"
  local rollback_base
  rollback_base="$(pick_best_sink "$cur_sink" "${BASE_SINK:-}")"

  if is_virtual_eq_sink "$target_sink"; then target_sink="auto"; fi
  if [[ "$target_sink" != "auto" ]]; then
    if sink_exists "$target_sink"; then
      BASE_SINK="$target_sink"
    else
      echo "Requested sink not found: $target_sink" >&2
      exit 1
    fi
  else
    BASE_SINK="$(pick_best_sink "$cur_sink" "${BASE_SINK:-}")"
  fi

  [[ -n "$BASE_SINK" ]] || { echo "No physical output sink available" >&2; return 1; }

  BASE_SOURCE="$(pick_best_source "$cur_source" "${BASE_SOURCE:-}")"

  local live_node="" live_applied=false props="" old_gain
  local live_previous_gains=()
  if [[ -f "$PW_CONF_FILE" && "$cur_sink" == effect_input.eq && "$BASE_SINK" == "$rollback_base" ]] && grep -Fx '# quickshell-live-eq-v1' "$PW_CONF_FILE" >/dev/null; then
    live_node="$(node_id_by_name Node effect_input.eq)" || live_node=""
    if [[ -n "$live_node" ]]; then
      props="$(pw-cli enum-params "$live_node" Props)" || props=""
      for i in {1..10}; do
        if [[ "$props" != *"\"eq$i:Gain\""* ]]; then live_node=""; break; fi
      done
      while read -r old_gain; do live_previous_gains+=("$old_gain"); done < <(awk '/^Filter / && $8 == "Gain" {print $9}' "$EQ_FILE")
      if [[ "${#live_previous_gains[@]}" != 10 ]]; then live_node=""; fi
    fi
  fi

  local rollback_dir rollback_audio=false rollback_dirty=false marker_owned=false
  local rollback_sink="$cur_sink" rollback_source="$cur_source"
  local rollback_volume="$EQ_SINK_VOLUME" rollback_muted="$EQ_SINK_MUTED"
  rollback_dir="$(mktemp -d "$STATE_DIR/.eq-rollback.XXXXXX")" || return 1
  local files=("$EQ_FILE" "$PW_CONF_FILE" "$STATE_FILE")
  local i
  for i in "${!files[@]}"; do
    if [[ -L "${files[$i]}" || ( -e "${files[$i]}" && ! -f "${files[$i]}" ) ]]; then
      echo "Cannot safely snapshot EQ path: ${files[$i]}" >&2
      rm -rf -- "$rollback_dir"
      return 1
    fi
    if [[ -f "${files[$i]}" ]]; then
      cp -p -- "${files[$i]}" "$rollback_dir/$i" || { rm -rf -- "$rollback_dir"; return 1; }
    fi
  done

  finish_apply() {
    local status="$?" restore_failed=false temp="" i
    trap - EXIT INT TERM
    # The original failure is authoritative. Secondary failures must not stop
    # attempts to restore the remaining files or replace that exit status.
    set +e
    if [[ "$status" != 0 && "$rollback_dirty" == true ]]; then
      for i in "${!files[@]}"; do
        if [[ -f "$rollback_dir/$i" ]]; then
          # An unsuccessful atomic write may have left this file unchanged.
          if cmp -s -- "$rollback_dir/$i" "${files[$i]}"; then
            if ! chmod --reference="$rollback_dir/$i" "${files[$i]}"; then
              restore_failed=true
              echo "Rollback chmod failed: ${files[$i]}" >&2
            fi
            continue
          fi
          if ! temp="$(mktemp "${files[$i]}.restore.XXXXXX")"; then
            restore_failed=true
            echo "Rollback mktemp failed: ${files[$i]}" >&2
            continue
          fi
          if ! cp -p -- "$rollback_dir/$i" "$temp"; then
            restore_failed=true
            echo "Rollback cp failed: ${files[$i]}" >&2
          elif ! mv -f -- "$temp" "${files[$i]}"; then
            restore_failed=true
            echo "Rollback mv failed: ${files[$i]}" >&2
          fi
          if ! rm -f -- "$temp"; then
            restore_failed=true
            echo "Rollback temporary-file cleanup failed: $temp" >&2
          fi
        else
          if ! rm -f -- "${files[$i]}"; then
            restore_failed=true
            echo "Rollback removal failed: ${files[$i]}" >&2
          fi
        fi
      done
      if [[ "$live_applied" == true ]]; then
        set_live_gains "$live_node" "${live_previous_gains[@]}" || restore_failed=true
      fi
      if [[ "$rollback_audio" == true && "$restore_failed" == false ]]; then
        if ! restart_audio_stack; then
          restore_failed=true
        else
          if [[ -f "$rollback_dir/1" ]]; then
            if [[ -z "$rollback_base" ]] || ! wait_for_eq_nodes || ! wait_for_sink "$rollback_base" || ! stabilize_eq_route "$rollback_base"; then
              restore_failed=true
            fi
            EQ_SINK_VOLUME="$rollback_volume" EQ_SINK_MUTED="$rollback_muted"
            normalize_eq_sink || restore_failed=true
          fi
          if [[ -n "$rollback_sink" ]]; then
            set_default_sink_compat "$rollback_sink" || restore_failed=true
            move_sink_inputs_to "$rollback_sink" || restore_failed=true
          else
            restore_failed=true
          fi
          if [[ -n "$rollback_source" ]]; then set_default_source_compat "$rollback_source" || restore_failed=true; fi
        fi
      fi
      if [[ "$restore_failed" == true ]]; then
        echo "Rollback incomplete; backup retained at $rollback_dir" >&2
      else
        echo "Apply failed; previous configuration restored" >&2
      fi
    fi
    if [[ "$restore_failed" == false && "$marker_owned" == true ]]; then
      if ! rm -f -- "$TRANSACTION_FILE"; then
        restore_failed=true
        echo "Cannot clear EQ transaction marker; backup retained at $rollback_dir" >&2
        if [[ "$status" == 0 ]]; then status=1; fi
      fi
    fi
    if [[ "$restore_failed" == false ]]; then
      if ! rm -rf -- "$rollback_dir"; then
        echo "Rollback backup cleanup failed; inspect remaining files at $rollback_dir" >&2
      fi
    fi
    if [[ "$status" == 0 ]]; then
      if [[ "$live_applied" == true ]]; then echo "applied live file=$EQ_FILE";
      else echo "applied file=$EQ_FILE"; fi
    fi
    exit "$status"
  }
  trap finish_apply EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  # Publish before mutation, so an interrupted apply also fails closed next time.
  (umask 077; printf 'version=1\nbackup=%s\neq_file=%s\npipewire_conf=%s\nstate_file=%s\n' \
    "$rollback_dir" "$EQ_FILE" "$PW_CONF_FILE" "$STATE_FILE" > "$rollback_dir/pending") || return $?
  mv -- "$rollback_dir/pending" "$TRANSACTION_FILE" || return $?
  marker_owned=true
  rollback_dirty=true

  write_eq_file "${gains[@]}"
  write_pipewire_conf "${gains[@]}"
  write_state

  if [[ -n "$live_node" ]]; then
    live_applied=true
    set_live_gains "$live_node" "${gains[@]}" || return 1
    return 0
  fi

  rollback_audio=true
  restart_audio_stack
  wait_for_eq_nodes || return 1
  wait_for_sink "$BASE_SINK" || return 1
  [[ -n "${BASE_SOURCE:-}" ]] && wait_for_source "$BASE_SOURCE" || true

  stabilize_eq_route "$BASE_SINK" || return 1
  normalize_eq_sink
  set_default_sink_compat "effect_input.eq" || return 1
  [[ -n "${BASE_SOURCE:-}" ]] && set_default_source_compat "$BASE_SOURCE" || true
  finalize_eq_route "$BASE_SINK" || return 1
  normalize_eq_sink
)

switch_eq_target() {
  local target_sink="${1:-}"

  read_state
  capture_eq_sink_state

  if [[ -z "$target_sink" ]]; then
    echo "Usage: $0 switch <target_sink>" >&2
    exit 2
  fi
  if is_virtual_eq_sink "$target_sink"; then
    echo "Refusing to switch to virtual EQ sink" >&2
    exit 2
  fi
  if ! sink_exists "$target_sink"; then
    echo "Requested sink not found: $target_sink" >&2
    exit 1
  fi

  BASE_SINK="$target_sink"

  if [[ -f "$PW_CONF_FILE" ]]; then
    wait_for_eq_nodes || return 1
    wait_for_sink "$BASE_SINK" || return 1
    stabilize_eq_route "$BASE_SINK" || return 1
    normalize_eq_sink
    set_default_sink_compat "effect_input.eq" || return 1
    [[ -n "${BASE_SOURCE:-}" ]] && set_default_source_compat "$BASE_SOURCE" || true
    finalize_eq_route "$BASE_SINK" || return 1
    normalize_eq_sink
    write_state
    echo "switched target=$BASE_SINK"
    return 0
  fi

  set_default_sink_compat "$BASE_SINK" || return 1
  write_state
  echo "switched base=$BASE_SINK"
}

disable_eq() {
  read_state
  capture_eq_sink_state
  write_state

  rm -f "$PW_CONF_FILE"
  restart_audio_stack

  local sink="${BASE_SINK:-}"
  if [[ -z "$sink" || "$sink" == "effect_input.eq" ]]; then
    sink="$(first_real_sink || true)"
  fi
  [[ -n "$sink" ]] || { echo "No physical output sink available" >&2; return 1; }
  set_default_sink_compat "$sink" || return 1

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

# All writers share this lock, including separate UI/backend instances. Never
# unlink the lock file: waiters must continue to refer to the same inode.
case "$cmd" in
  apply|switch|disable|recover)
    need_cmd flock
    previous_umask="$(umask)"
    umask 077
    exec 9>>"$STATE_DIR/eq_filter_chain.lock"
    umask "$previous_umask"
    if [[ "$cmd" == recover ]]; then
      if flock -n -E 75 9; then
        :
      else
        result=$?
        if [[ "$result" == 75 ]]; then
          echo "EQ busy; recovery skipped"
          exit 0
        fi
        echo "Failed to acquire EQ recovery lock" >&2
        exit "$result"
      fi
    else
      flock -w 60 9 || { echo "Timed out acquiring EQ operation lock" >&2; exit 1; }
    fi
    # Treat even malformed records and dangling symlinks as unresolved. Never
    # source this file or discard it automatically on a later invocation.
    if [[ -e "$TRANSACTION_FILE" || -L "$TRANSACTION_FILE" ]]; then
      echo "Unresolved EQ transaction: $TRANSACTION_FILE; restore and verify the retained backup before clearing this marker" >&2
      exit 1
    fi
    ;;
esac

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
  switch)
    switch_eq_target "${1:-}"
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
    echo "Usage: $0 {apply <10 gains> [target_sink|auto]|switch <target_sink>|disable|recover|status}" >&2
    exit 2
    ;;
esac
