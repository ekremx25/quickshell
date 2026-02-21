#!/bin/bash

# Detect running wallpaper process
# Supports: swww, waypaper, swaybg

# 1. Try swww query
if pgrep -x "swww-daemon" > /dev/null || pgrep -x "swww" > /dev/null; then
    # Output format: ... image: /path/to/image.jpg
    SWWW_OUT=$(swww query 2>/dev/null)
    # Extract path after "currently displaying: image: "
    WALLPAPER_PATH=$(echo "$SWWW_OUT" | grep -oP '(?<=currently displaying: image: ).*')
    
    # If not found, try simpler grep (sometimes output varies)
    if [ -z "$WALLPAPER_PATH" ]; then
        WALLPAPER_PATH=$(echo "$SWWW_OUT" | grep -oP '(?<=image: ).*')
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
    WALLPAPER_PATH=$(grep -oP '(?<=wallpaper = ).*' "$WAYPAPER_CONFIG" | head -n 1)
    # Expand ~ to home
    WALLPAPER_PATH="${WALLPAPER_PATH/#\~/$HOME}"
    
    if [ -f "$WALLPAPER_PATH" ]; then
        echo "$WALLPAPER_PATH"
        exit 0
    fi
fi

# 3. Fallback to swaybg
if pgrep -x "swaybg" > /dev/null; then
    CMDLINE=$(ps -o args= -C swaybg)
    WALLPAPER_PATH=$(echo "$CMDLINE" | grep -oP '(?<=-i\s)[^\s]*')
    
    if [ -f "$WALLPAPER_PATH" ]; then
        echo "$WALLPAPER_PATH"
        exit 0
    fi
fi

# Not found
echo ""
exit 1
