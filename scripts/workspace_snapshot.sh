#!/usr/bin/env bash
set -u

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
