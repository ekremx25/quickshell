#!/usr/bin/env bash
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

# Generate colors in the token.mode.color shape consumed by the shell.
COLORS=$(matugen image "$WALLPAPER" -t "$TYPE" --json hex --source-color-index 0 2>/dev/null)

if [ -z "$COLORS" ]; then
    echo "Error: matugen returned empty output"
    exit 1
fi

# Matugen deliberately builds a harmonious palette from one source colour.
# Quickshell's Wallpaper Spectrum mode additionally needs several colours
# that actually occur in the image so different modules can retain distinct
# identities. ImageMagick is optional; ordinary Material You generation keeps
# working when it is unavailable.
SPECTRUM_JSON='[]'
if command -v magick &>/dev/null && command -v jq &>/dev/null; then
    HISTOGRAM=$(magick "$WALLPAPER" \
        -auto-orient -resize '192x192>' -alpha off -colorspace sRGB \
        -colors 24 -format '%c' histogram:info:- 2>/dev/null || true)

    if [ -n "$HISTOGRAM" ]; then
        # Start with the dominant colour, then use perceptual distance in
        # OKLab so the remaining module accents do not collapse into twelve
        # nearly identical shades.
        if command -v python3 &>/dev/null; then
            SPECTRUM_TEXT=$(printf '%s\n' "$HISTOGRAM" \
                | python3 "$(dirname "$0")/extract-wallpaper-spectrum.py")
        else
            SPECTRUM_TEXT=$(printf '%s\n' "$HISTOGRAM" \
                | sort -nr \
                | sed -nE 's/.*#([0-9A-Fa-f]{6}).*/#\1/p' \
                | awk 'NF && count < 12 { print; count++ }')
        fi
        SPECTRUM_JSON=$(printf '%s\n' "$SPECTRUM_TEXT" \
            | jq -Rsc 'split("\n") | map(select(length > 0))')
    fi
fi

COLORS=$(printf '%s' "$COLORS" \
    | jq --argjson spectrum "$SPECTRUM_JSON" '. + {quickshell_spectrum: $spectrum}')

color_from_palette() {
    local token="$1"
    jq -r --arg token "$token" --arg mode "$MODE" '
        .colors[$token][$mode].color
        // .colors[$mode][$token]
        // empty
    ' 2>/dev/null
}

PRIMARY=$(printf '%s' "$COLORS" | color_from_palette "primary")
SURFACE=$(printf '%s' "$COLORS" | color_from_palette "surface")
ON_SURFACE=$(printf '%s' "$COLORS" | color_from_palette "on_surface")

{
    echo "Generated colors (mode: $MODE, type: $TYPE)"
    echo "  Primary: $PRIMARY"
    echo "  Surface: $SURFACE"
    echo "  On Surface: $ON_SURFACE"
} >&2

# Apply to Kitty terminal if requested
if [ "$APPLY_KITTY" = "true" ] && command -v kitty &>/dev/null; then
    BG=$(printf '%s' "$COLORS" | color_from_palette "surface")
    FG=$(printf '%s' "$COLORS" | color_from_palette "on_surface")
    ACCENT=$(printf '%s' "$COLORS" | color_from_palette "primary")

    if [ -n "$BG" ] && [ -n "$FG" ]; then
        kitty @ set-colors --all background="$BG" foreground="$FG" cursor="$ACCENT" 2>/dev/null || true
    fi
fi

# Output JSON for Quickshell to consume
printf '%s\n' "$COLORS"
