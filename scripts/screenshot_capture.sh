#!/usr/bin/env bash

set -u

mode="${1:-full}"
pictures_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}"
destination_dir="${SCREENSHOT_DIR:-$pictures_dir/screen}"
timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
destination="$destination_dir/screenshot_$timestamp.png"

mkdir -p "$destination_dir" || exit 1

case "$mode" in
    full)
        grim "$destination" || exit 1
        ;;
    region)
        geometry="$(slurp)" || exit 0
        [ -n "$geometry" ] || exit 0
        grim -g "$geometry" "$destination" || exit 1
        ;;
    *)
        printf 'Usage: %s [full|region]\n' "$0" >&2
        exit 2
        ;;
esac

copy_message=""
if command -v wl-copy >/dev/null 2>&1; then
    if wl-copy --type image/png < "$destination"; then
        copy_message=" and copied to the clipboard"
    fi
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Quickshell" -i camera-photo "Screenshot saved" "$destination$copy_message"
fi

printf '%s\n' "$destination"
