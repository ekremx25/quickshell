#!/bin/bash

# 1. Prioritize passed arguments
if [ -n "$1" ]; then
  WALLPAPER="$1"
else
  # Only ask swww if no arguments passed (fallback logic)
  sleep 0.5
  WALLPAPER=$(swww query | head -n1 | grep -oP 'image: \K.*')
fi

# Check if path was obtained
if [ -z "$WALLPAPER" ]; then
  echo "$(date) - ERROR: No wallpaper path found!" >>/tmp/wp_debug.log
  exit 1
fi

CACHE_DIR="$HOME/.cache/wallpaper_blur"
CACHE_DIR_OVERVIEW="$HOME/.cache/wallpaper_overview/"
mkdir -p "$CACHE_DIR" "$CACHE_DIR_OVERVIEW"

# Get filename and define output path
FILENAME=$(basename "$WALLPAPER")
BLURRED_WALLPAPER_OVERVIEW="$CACHE_DIR_OVERVIEW/overview_$FILENAME"
BLURRED_WALLPAPER="$CACHE_DIR/blurred_$FILENAME"

# Generate blurred wallpaper if not cached
# Use convert or magick for blurring
if [ ! -f "$BLURRED_WALLPAPER" ] || [ ! -f "$BLURRED_WALLPAPER_OVERVIEW" ]; then
  magick "$WALLPAPER" -blur 0x15 -fill black -colorize 40% "$BLURRED_WALLPAPER_OVERVIEW"
  magick "$WALLPAPER" -blur 0x30 "$BLURRED_WALLPAPER"
fi

# swww img here is actually redundant, as QML handles switching
# But keeping it for fade transition effect is fine
swww img -n overview "$BLURRED_WALLPAPER_OVERVIEW" \
  --transition-type fade \
  --transition-duration 0.5

# ============================================================
# Core Save Logic
# ============================================================
CACHE_ROFI="$HOME/.cache/wallpaper_rofi"
mkdir -p "$CACHE_ROFI"

# Force copy, log result
cp -f "$WALLPAPER" "$CACHE_ROFI/current" && echo "Saved current" >>/tmp/wp_debug.log || echo "Failed to save current" >>/tmp/wp_debug.log
cp -f "$BLURRED_WALLPAPER" "$CACHE_ROFI/blurred" && echo "Saved blurred" >>/tmp/wp_debug.log || echo "Failed to save blurred" >>/tmp/wp_debug.log

echo "$(date) - Done" >>/tmp/wp_debug.log
