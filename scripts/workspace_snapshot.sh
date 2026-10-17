#!/usr/bin/env bash
set -u

if [ -n "${SWAYSOCK:-}" ]; then
    outputs="$(swaymsg -t get_outputs -r)" || exit 1
    workspaces="$(swaymsg -t get_workspaces -r)" || exit 1
    tree="$(swaymsg -t get_tree -r)" || exit 1
    printf '%s\n' '<<<MONITORS>>>'
    jq '[.[] | select(.active == true) | {name, activeWorkspace: {id: .current_workspace}}]' <<<"$outputs"
    printf '%s\n' '<<<WORKSPACES>>>'
    jq '[.[] | {id: .name, name: .name, monitor: .output}]' <<<"$workspaces"
    printf '%s\n' '<<<CLIENTS>>>'
    jq 'def windows($workspace):
        (if .type == "workspace" then .name else $workspace end) as $current
        | (if .type == "con" and (.app_id != null or .window_properties.class != null)
           then [{workspace: {id: $current}, address: (.id | tostring),
                  class: (.app_id // .window_properties.class), title: (.name // ""),
                  is_focused: (.focused // false), urgent: (.urgent // false)}]
           else [] end)
          + ([.nodes[]?, .floating_nodes[]?] | map(windows($current)) | add // []);
        windows(null)' <<<"$tree"
    printf '%s\n' '<<<END>>>'
    exit 0
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 1
compositor="$(bash "$script_dir/detect_compositor.sh")" || compositor=unknown

if [ "$compositor" = "hyprland" ]; then
    printf '%s\n' '<<<MONITORS>>>'
    hyprctl -j monitors 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<WORKSPACES>>>'
    hyprctl -j workspaces 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<CLIENTS>>>'
    hyprctl -j clients 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<END>>>'
    exit 0
fi

if [ "$compositor" = "niri" ]; then
    printf '%s\n' '<<<OUTPUTS>>>'
    niri msg --json outputs 2>/dev/null || printf '%s\n' '{}'
    printf '%s\n' '<<<WORKSPACES>>>'
    niri msg --json workspaces 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<CLIENTS>>>'
    niri msg --json windows 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<END>>>'
    exit 0
fi

if [ "$compositor" = "mango" ]; then
    printf '%s\n' '<<<MANGO_TAGS>>>'
    mmsg get all-tags 2>/dev/null || printf '%s\n' '{"all_tags":[]}'
    printf '%s\n' '<<<MANGO_CLIENTS>>>'
    mmsg get all-clients 2>/dev/null || printf '%s\n' '{"clients":[]}'
    printf '%s\n' '<<<END>>>'
    exit 0
fi

printf '%s\n' '<<<END>>>'
exit 1
