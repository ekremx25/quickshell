#!/bin/bash

set -u

workspace="${1:-}"
monitor="${2:-}"

case "$workspace" in
    ""|*[!0-9]*) exit 0 ;;
esac

if [ -n "$monitor" ]; then
    niri msg action focus-monitor "$monitor" >/dev/null 2>&1 || exit 1
fi

niri msg action focus-workspace "$workspace" >/dev/null 2>&1
