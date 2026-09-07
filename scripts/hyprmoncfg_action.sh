#!/bin/bash

set -u

if [ "$(bash "$(dirname -- "${BASH_SOURCE[0]}")/detect_compositor.sh")" != hyprland ]; then
    echo "Hyprmoncfg profile management is only available in Hyprland." >&2
    exit 1
fi

ACTION="${1:-}"
ARGUMENT="${2:-}"

case "$ACTION" in
    save)
        [ -n "$ARGUMENT" ] || { echo "Profile name is required."; exit 2; }
        exec hyprmoncfg save "$ARGUMENT"
        ;;
    apply)
        [ -n "$ARGUMENT" ] || { echo "Profile name is required."; exit 2; }
        exec hyprmoncfg apply "$ARGUMENT"
        ;;
    delete)
        [ -n "$ARGUMENT" ] || { echo "Profile name is required."; exit 2; }
        exec hyprmoncfg delete "$ARGUMENT"
        ;;
    enable)
        if ! find "${XDG_CONFIG_HOME:-$HOME/.config}/hyprmoncfg/profiles" -maxdepth 1 -name '*.json' -print -quit 2>/dev/null | grep -q .; then
            hyprmoncfg save linuxlifex-dual || exit $?
        fi
        hyprmoncfg manage || exit $?
        systemctl --user daemon-reload || exit $?
        systemctl --user enable --now hyprmoncfgd.service || exit $?
        echo "Automatic profile switching enabled."
        ;;
    disable)
        systemctl --user disable --now hyprmoncfgd.service || exit $?
        hyprmoncfg unmanage || exit $?
        echo "Automatic switching disabled; Quickshell monitor management restored."
        ;;
    *)
        echo "Unknown hyprmoncfg action."
        exit 2
        ;;
esac
