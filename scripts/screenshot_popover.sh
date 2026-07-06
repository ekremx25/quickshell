#!/usr/bin/env bash
# screenshot_popover.sh — Take a delayed screenshot for popovers / menus
# that auto-close on focus loss.
#
# Usage:
#   ./screenshot_popover.sh <filename> [delay_seconds] [output_name]
#
# Example:
#   ./screenshot_popover.sh eq.png            # 3s delay, full default screen
#   ./screenshot_popover.sh eq.png 5          # 5s delay
#   ./screenshot_popover.sh eq.png 3 DP-3     # specific output
#
# After running, you have <delay> seconds to open the popover before the
# shot is captured silently in the background.

set -euo pipefail

FILENAME="${1:-screenshot.png}"
DELAY="${2:-3}"
OUTPUT="${3:-}"
DEST_DIR="${SCREENSHOT_DIR:-$HOME/Pictures/screen}"

mkdir -p "$DEST_DIR"
DEST="$DEST_DIR/$FILENAME"

if ! command -v grim >/dev/null 2>&1; then
    echo "error: grim is not installed" >&2
    exit 1
fi

echo "Capturing $DEST in ${DELAY}s — open the popover NOW..."

if [ -n "$OUTPUT" ]; then
    ( sleep "$DELAY" && grim -o "$OUTPUT" "$DEST" && echo "saved → $DEST" ) &
else
    ( sleep "$DELAY" && grim "$DEST" && echo "saved → $DEST" ) &
fi
