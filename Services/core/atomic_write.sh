#!/bin/sh
# Atomic write helper for TextDataStore.
# Writes $2 (content) to $1 (target path) via temp file + mv.
# Invoked as direct argv from QML — content never enters shell interpretation.
#
# Guarantees:
#   - Crash-safe: partial write leaves original file intact
#   - Race-safe: readers always see complete old or complete new content
#   - Directory is created if it doesn't exist
TARGET="$1"
CONTENT="$2"
DIR=$(dirname "$TARGET")
mkdir -p "$DIR" || exit 1
TMP=$(mktemp "$DIR/.XXXXXX") || exit 1
if printf '%s' "$CONTENT" > "$TMP" && mv -- "$TMP" "$TARGET"; then
    exit 0
else
    rm -f "$TMP"
    exit 1
fi
