#!/bin/bash
# matugen-worker.sh — Generate Material You colors from wallpaper
# Adapted from Event Horizon dotfiles for personal Quickshell config
# Dependencies: matugen, jq

set -euo pipefail

WALLPAPER="${1:-}"
MODE="${2:-dark}"
TYPE="${3:-scheme-tonal-spot}"
APPLY_KITTY="${4:-true}"

if [ -z "$WALLPAPER" ]; then
    echo "Usage: $0 <wallpaper_path> [dark|light] [scheme-type] [apply_kitty]"
    exit 1
fi

if ! command -v matugen &>/dev/null; then
    echo "Error: matugen not found"
    exit 1
fi

# Generate colors
COLORS=$(matugen image "$WALLPAPER" --json "$TYPE" 2>/dev/null)

if [ -z "$COLORS" ]; then
    echo "Error: matugen returned empty output"
    exit 1
fi

# Extract primary color for external use
PRIMARY=$(echo "$COLORS" | jq -r ".colors.${MODE}.primary // empty" 2>/dev/null)
SURFACE=$(echo "$COLORS" | jq -r ".colors.${MODE}.surface // empty" 2>/dev/null)
ON_SURFACE=$(echo "$COLORS" | jq -r ".colors.${MODE}.on_surface // empty" 2>/dev/null)

echo "Generated colors (mode: $MODE, type: $TYPE)"
echo "  Primary: $PRIMARY"
echo "  Surface: $SURFACE"
echo "  On Surface: $ON_SURFACE"

# Apply to Kitty terminal if requested
if [ "$APPLY_KITTY" = "true" ] && command -v kitty &>/dev/null; then
    BG=$(echo "$COLORS" | jq -r ".colors.${MODE}.surface // empty" 2>/dev/null)
    FG=$(echo "$COLORS" | jq -r ".colors.${MODE}.on_surface // empty" 2>/dev/null)
    ACCENT=$(echo "$COLORS" | jq -r ".colors.${MODE}.primary // empty" 2>/dev/null)

    if [ -n "$BG" ] && [ -n "$FG" ]; then
        kitty @ set-colors --all background="$BG" foreground="$FG" cursor="$ACCENT" 2>/dev/null || true
    fi
fi

# Output JSON for Quickshell to consume
echo "$COLORS"
