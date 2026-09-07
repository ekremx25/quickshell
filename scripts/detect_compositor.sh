#!/bin/bash
set -o pipefail
# Read-only session detection. Never infer Hyprland from another live session.
desktop=":${XDG_CURRENT_DESKTOP,,}:"
session="${XDG_SESSION_DESKTOP,,}"
for candidate in niri mango hyprland; do
    if [[ "$desktop" == *":$candidate:"* || ( -z "${XDG_CURRENT_DESKTOP:-}" && "$session" == "$candidate" ) ]]; then
        printf '%s\n' "$candidate"
        exit 0
    fi
done
# A declared foreign desktop must not inherit an old compositor's environment.
if [[ -n "${XDG_CURRENT_DESKTOP:-}${XDG_SESSION_DESKTOP:-}" ]]; then
    printf 'unknown\n'
    exit 0
fi
count=0
result=unknown
for candidate in niri mango hyprland; do
    case "$candidate" in
        niri) hint="${NIRI_SOCKET:-}" ;;
        mango) hint="${MANGO_INSTANCE_SIGNATURE:-}" ;;
        hyprland) hint="${HYPRLAND_INSTANCE_SIGNATURE:-}" ;;
    esac
    if [[ -n "$hint" ]]; then result="$candidate"; ((count+=1)); fi
done
if (( count > 1 )); then result=unknown; fi
if (( count == 0 )) && mmsg get version 2>/dev/null | grep -q '"version"'; then
    result=mango
fi
printf '%s\n' "$result"
