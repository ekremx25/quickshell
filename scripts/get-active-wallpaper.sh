#!/usr/bin/env bash
set -o pipefail

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect running wallpaper process
# Supports: swww, waypaper, swaybg

# 1. Try swww query
if command_exists swww && { pgrep -x "swww-daemon" > /dev/null || pgrep -x "swww" > /dev/null; }; then
    # Output format: ... image: /path/to/image.jpg
    SWWW_OUT=$(swww query 2>/dev/null || true)
    # Extract path after "currently displaying: image: "
    WALLPAPER_PATH=$(printf '%s\n' "$SWWW_OUT" | grep -oP '(?<=currently displaying: image: ).*' || true)
    
    # If not found, try simpler grep (sometimes output varies)
    if [ -z "$WALLPAPER_PATH" ]; then
        WALLPAPER_PATH=$(printf '%s\n' "$SWWW_OUT" | grep -oP '(?<=image: ).*' || true)
    fi

    if [ -f "$WALLPAPER_PATH" ]; then
        echo "$WALLPAPER_PATH"
        exit 0
    fi
fi

# 2. Try waypaper config
WAYPAPER_CONFIG="$HOME/.config/waypaper/config.ini"
if [ -f "$WAYPAPER_CONFIG" ]; then
    # Extract wallpaper = /path/to/image
    WALLPAPER_PATH=$(grep -oP '(?<=wallpaper = ).*' "$WAYPAPER_CONFIG" | head -n 1 || true)
    # Expand ~ to home
    WALLPAPER_PATH="${WALLPAPER_PATH/#\~/$HOME}"
    
    if [ -f "$WALLPAPER_PATH" ]; then
        echo "$WALLPAPER_PATH"
        exit 0
    fi
fi

# 3. Fallback to swaybg
if pgrep -x "swaybg" > /dev/null; then
    CMDLINE=$(ps -o args= -C swaybg || true)
    WALLPAPER_PATH=$(printf '%s\n' "$CMDLINE" | grep -oP '(?<=-i\s)[^\s]*' || true)
    
    if [ -f "$WALLPAPER_PATH" ]; then
        echo "$WALLPAPER_PATH"
        exit 0
    fi
fi

# Not found
printf '\n'
exit 1
