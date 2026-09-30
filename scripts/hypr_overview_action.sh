#!/usr/bin/env bash
set -u -o pipefail

action="${1:-}"
window="${2:-}"
target="${3:-}"
monitor="${4:-}"

valid_window() { [[ "$1" =~ ^0x[0-9a-fA-F]+$ ]]; }
valid_workspace() { [[ "$1" =~ ^[1-9][0-9]*$ || "$1" =~ ^special:[A-Za-z0-9_.-]+$ ]]; }
valid_monitor() { [[ -z "$1" || "$1" =~ ^[A-Za-z0-9_.-]+$ ]]; }
lua_quote() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

HYPRCTL=(hyprctl)
if ! hyprctl systeminfo >/dev/null 2>&1; then
  HYPRCTL=(hyprctl -i 0)
fi
provider() { "${HYPRCTL[@]}" systeminfo 2>/dev/null | awk -F': ' '/configProvider:/ { print $2; exit }'; }
PROVIDER="$(provider)"

dispatch_window_move() {
  local address="$1" workspace="$2"
  if [[ "$PROVIDER" == "lua" ]]; then
    "${HYPRCTL[@]}" eval "hl.dispatch(hl.dsp.window.move({ workspace = \"$(lua_quote "$workspace")\", follow = false, window = \"address:$(lua_quote "$address")\" }))"
  else
    "${HYPRCTL[@]}" dispatch movetoworkspacesilent "$workspace,address:$address"
  fi
}

dispatch_workspace_move() {
  local workspace="$1" monitor_name="$2"
  if [[ "$PROVIDER" == "lua" ]]; then
    "${HYPRCTL[@]}" eval "hl.dispatch(hl.dsp.workspace.move({ workspace = \"$(lua_quote "$workspace")\", monitor = \"$(lua_quote "$monitor_name")\" }))"
  else
    "${HYPRCTL[@]}" dispatch moveworkspacetomonitor "$workspace $monitor_name"
  fi
}

clients_json() { "${HYPRCTL[@]}" clients -j; }
monitors_json() { "${HYPRCTL[@]}" monitors -j; }
workspaces_json() { "${HYPRCTL[@]}" workspaces -j; }

client_record() {
  local address="$1"
  clients_json | jq -ce --arg address "$address" '.[] | select(.address == $address)' 2>/dev/null
}

workspace_record() {
  local workspace="$1"
  workspaces_json | jq -ce --arg workspace "$workspace" '.[] | select(.name == $workspace or (.id | tostring) == $workspace)' 2>/dev/null
}

monitor_name_for_id() {
  local monitor_id="$1"
  monitors_json | jq -er --argjson id "$monitor_id" '.[] | select(.id == $id) | .name' 2>/dev/null
}

monitor_is_usable() {
  local monitor_name="$1"
  monitors_json | jq -e --arg monitor "$monitor_name" '
    any(.[];
      .name == $monitor
      and .disabled != true
      and .dpmsStatus != false
      and ((.mirrorOf // "none") == "none" or (.mirrorOf // "") == ""))
  ' >/dev/null 2>&1
}

rollback_move() {
  local address="$1" origin_workspace="$2" origin_monitor="$3"
  local target_workspace="$4" target_existed="$5" target_origin_monitor="$6"
  local rollback_failed=0

  dispatch_window_move "$address" "$origin_workspace" >/dev/null 2>&1 || rollback_failed=1
  if monitor_is_usable "$origin_monitor"; then
    dispatch_workspace_move "$origin_workspace" "$origin_monitor" >/dev/null 2>&1 || rollback_failed=1
  else
    rollback_failed=1
  fi

  if [[ "$target_existed" == "true" && -n "$target_origin_monitor" && "$target_origin_monitor" != "$monitor" ]]; then
    if monitor_is_usable "$target_origin_monitor"; then
      dispatch_workspace_move "$target_workspace" "$target_origin_monitor" >/dev/null 2>&1 || rollback_failed=1
    else
      rollback_failed=1
    fi
  fi

  local restored_client restored_workspace
  restored_client="$(client_record "$address" 2>/dev/null || true)"
  restored_workspace="$(workspace_record "$origin_workspace" 2>/dev/null || true)"
  [[ -n "$restored_client" && "$(jq -r '.workspace.name' <<<"$restored_client")" == "$origin_workspace" ]] || rollback_failed=1
  [[ -n "$restored_workspace" && "$(jq -r '.monitor' <<<"$restored_workspace")" == "$origin_monitor" ]] || rollback_failed=1

  if (( rollback_failed != 0 )); then
    echo "Workspace move failed and rollback is incomplete; window=$address origin=$origin_workspace monitor=$origin_monitor" >&2
    return 1
  fi
  return 0
}

move_transaction() {
  command -v jq >/dev/null 2>&1 || { echo "jq is required for atomic workspace moves" >&2; return 70; }

  local origin_client origin_workspace origin_monitor_id origin_monitor
  local target_before target_existed=false target_origin_monitor="" target_windows=0
  origin_client="$(client_record "$window")" || { echo "Overview window no longer exists" >&2; return 3; }
  origin_workspace="$(jq -r '.workspace.name' <<<"$origin_client")"
  origin_monitor_id="$(jq -r '.monitor' <<<"$origin_client")"
  origin_monitor="$(monitor_name_for_id "$origin_monitor_id")" || { echo "Could not resolve source monitor" >&2; return 3; }

  monitor_is_usable "$monitor" || { echo "Target monitor is disconnected, disabled, or mirrored: $monitor" >&2; return 4; }

  target_before="$(workspace_record "$target" 2>/dev/null || true)"
  if [[ -n "$target_before" ]]; then
    target_existed=true
    target_origin_monitor="$(jq -r '.monitor // ""' <<<"$target_before")"
    target_windows="$(jq -r '.windows // 0' <<<"$target_before")"
    if (( target_windows > 0 )) && [[ "$target_origin_monitor" != "$monitor" ]]; then
      echo "Target workspace moved since the overview snapshot: $target" >&2
      return 4
    fi
  fi

  if ! dispatch_window_move "$window" "$target" >/dev/null; then
    echo "Could not move window to workspace $target" >&2
    return 5
  fi

  if ! monitor_is_usable "$monitor"; then
    echo "Target monitor disconnected during workspace move: $monitor" >&2
    rollback_move "$window" "$origin_workspace" "$origin_monitor" "$target" "$target_existed" "$target_origin_monitor" || true
    return 6
  fi

  if ! dispatch_workspace_move "$target" "$monitor" >/dev/null; then
    echo "Could not place workspace $target on monitor $monitor" >&2
    rollback_move "$window" "$origin_workspace" "$origin_monitor" "$target" "$target_existed" "$target_origin_monitor" || true
    return 7
  fi

  local final_client final_workspace
  final_client="$(client_record "$window" 2>/dev/null || true)"
  final_workspace="$(workspace_record "$target" 2>/dev/null || true)"
  if ! monitor_is_usable "$monitor" \
      || [[ -z "$final_client" || "$(jq -r '.workspace.name' <<<"$final_client")" != "$target" ]] \
      || [[ -z "$final_workspace" || "$(jq -r '.monitor' <<<"$final_workspace")" != "$monitor" ]]; then
    echo "Workspace move verification failed; rolling back" >&2
    rollback_move "$window" "$origin_workspace" "$origin_monitor" "$target" "$target_existed" "$target_origin_monitor" || true
    return 8
  fi
  return 0
}

case "$action" in
  move)
    valid_window "$window" && valid_workspace "$target" && valid_monitor "$monitor" || { echo "Invalid overview move request" >&2; exit 2; }
    if [[ -n "$monitor" ]]; then
      move_transaction
    else
      dispatch_window_move "$window" "$target"
    fi
    ;;
  focus)
    valid_window "$window" || { echo "Invalid overview focus request" >&2; exit 2; }
    if [[ "$PROVIDER" == "lua" ]]; then
      "${HYPRCTL[@]}" eval "hl.dispatch(hl.dsp.focus({ window = \"address:$(lua_quote "$window")\" }))"
    else
      "${HYPRCTL[@]}" dispatch focuswindow "address:$window"
    fi
    ;;
  workspace)
    valid_workspace "$target" || { echo "Invalid overview workspace request" >&2; exit 2; }
    if [[ "$PROVIDER" == "lua" ]]; then
      "${HYPRCTL[@]}" eval "hl.dispatch(hl.dsp.focus({ workspace = \"$(lua_quote "$target")\" }))"
    else
      "${HYPRCTL[@]}" dispatch workspace "$target"
    fi
    ;;
  *) echo "Usage: $0 {move <window> <workspace> [monitor]|focus <window>|workspace <target>}" >&2; exit 2 ;;
esac
