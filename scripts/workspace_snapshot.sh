#!/usr/bin/env bash
set -u

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    printf '%s\n' '<<<MONITORS>>>'
    hyprctl -j monitors 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<WORKSPACES>>>'
    hyprctl -j workspaces 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<CLIENTS>>>'
    hyprctl -j clients 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<END>>>'
    exit 0
fi

if [ -n "${NIRI_SOCKET:-}" ]; then
    printf '%s\n' '<<<OUTPUTS>>>'
    niri msg --json outputs 2>/dev/null || printf '%s\n' '{}'
    printf '%s\n' '<<<WORKSPACES>>>'
    niri msg --json workspaces 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<CLIENTS>>>'
    niri msg --json windows 2>/dev/null || printf '%s\n' '[]'
    printf '%s\n' '<<<END>>>'
    exit 0
fi

if [ -n "${MANGO_INSTANCE_SIGNATURE:-}" ]; then
    printf '%s\n' '<<<MANGO_TAGS>>>'
    mmsg get all-tags 2>/dev/null || printf '%s\n' '{"all_tags":[]}'
    printf '%s\n' '<<<MANGO_CLIENTS>>>'
    mmsg get all-clients 2>/dev/null || printf '%s\n' '{"clients":[]}'
    printf '%s\n' '<<<END>>>'
    exit 0
fi

printf '%s\n' '<<<END>>>'
exit 1
