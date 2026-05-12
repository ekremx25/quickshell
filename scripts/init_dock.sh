#!/usr/bin/env bash
set -euo pipefail
# init_dock.sh - Generate dock_config.json from applications installed on the system.
# Invoked automatically on first run when dock_config.json is missing.
#
# Security note: the JSON output is produced with jq, so special characters and
# quotes inside app names, icons or commands cannot break the JSON (no injection).

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# jq is a hard dependency
if ! command_exists jq; then
    echo "error: jq not found. Please install jq." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QS_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$QS_DIR/dock_config.json"

# Don't touch an existing config
if [ -f "$CONFIG_FILE" ]; then
    echo "exists"
    exit 0
fi

# Popular applications — in priority order
# Format: "appId|name|cmd|icon"
APPS=(
    # File manager
    "org.gnome.Nautilus|Files|nautilus --new-window|org.gnome.Nautilus"
    "dolphin|Files|dolphin|org.kde.dolphin"
    "thunar|Files|thunar|Thunar"
    "nemo|Files|nemo|nemo"
    "pcmanfm|Files|pcmanfm|system-file-manager"
    "caja|Files|caja|caja"

    # Browsers
    "firefox|Firefox|firefox|firefox"
    "brave-browser|Brave|brave-browser|brave-browser"
    "google-chrome|Chrome|google-chrome-stable|google-chrome"
    "chromium|Chromium|chromium|chromium"
    "vivaldi|Vivaldi|vivaldi|vivaldi"
    "opera|Opera|opera|opera"

    # Terminal
    "Alacritty|Alacritty|alacritty|Alacritty"
    "kitty|Kitty|kitty|kitty"
    "foot|Foot|foot|foot"
    "wezterm|WezTerm|wezterm|org.wezfurlong.wezterm"
    "ghostty|Ghostty|ghostty|ghostty"
    "konsole|Konsole|konsole|konsole"
    "gnome-terminal|Terminal|gnome-terminal|org.gnome.Terminal"
    "xfce4-terminal|Terminal|xfce4-terminal|org.xfce.terminal"

    # Editors
    "code|VS Code|code|visual-studio-code"
    "cursor|Cursor|cursor|cursor"
    "zed|Zed|zed|zed"

    # Communication
    "telegram-desktop|Telegram|telegram-desktop|telegram"
    "discord|Discord|discord|discord"
    "vesktop|Discord|vesktop|vesktop"
    "signal-desktop|Signal|signal-desktop|signal-desktop"
    "slack|Slack|slack|slack"

    # Media
    "spotify|Spotify|spotify|spotify"
    "vlc|VLC|vlc|vlc"

    # Tools
    "virt-manager|Virt Manager|virt-manager|virt-manager"
    "obs|OBS Studio|obs|com.obsproject.Studio"
    "steam|Steam|steam|steam"
    "gimp|GIMP|gimp|gimp"
    "blender|Blender|blender|blender"
    "inkscape|Inkscape|inkscape|inkscape"
    "kdenlive|Kdenlive|kdenlive|kdenlive"
    "audacity|Audacity|audacity|audacity"
)

# Per-category counters
found_filemanager=0
found_browser=0
found_terminal=0
found_editor=0

# Collect jq JSON objects for each pinned app here
pinned_entries=()

for entry in "${APPS[@]}"; do
    IFS='|' read -r appId name cmd icon <<< "$entry"

    # Take the first word of the command (nautilus --new-window → nautilus)
    bin=$(printf '%s\n' "$cmd" | awk '{print $1}')

    # Skip if the binary isn't installed
    if ! command_exists "$bin"; then
        continue
    fi

    # Per-category cap (only the first match wins)
    case "$name" in
        Files) [ "$found_filemanager" -ge 1 ] && continue; found_filemanager=$((found_filemanager+1)) ;;
        Firefox|Brave|Chrome|Chromium|Vivaldi|Opera) [ "$found_browser" -ge 2 ] && continue; found_browser=$((found_browser+1)) ;;
        Alacritty|Kitty|Foot|WezTerm|Ghostty|Konsole|Terminal) [ "$found_terminal" -ge 1 ] && continue; found_terminal=$((found_terminal+1)) ;;
        "VS Code"|Cursor|Zed) [ "$found_editor" -ge 1 ] && continue; found_editor=$((found_editor+1)) ;;
    esac

    # Use jq --arg to embed values safely into JSON.
    # Quotes, backslashes, unicode — all escaped automatically.
    entry_json=$(jq -cn \
        --arg name  "$name" \
        --arg icon  "$icon" \
        --arg cmd   "$cmd" \
        --arg appId "$appId" \
        '{name: $name, icon: $icon, cmd: $cmd, appId: $appId}')

    pinned_entries+=("$entry_json")
done

# Convert the collected objects into a JSON array with jq
if [ ${#pinned_entries[@]} -eq 0 ]; then
    pinned_json="[]"
else
    pinned_json=$(printf '%s\n' "${pinned_entries[@]}" | jq -s '.')
fi

# Build the full config with jq and write it atomically (tmp + mv)
tmp_config=$(mktemp "$(dirname "$CONFIG_FILE")/.XXXXXX")
jq -n \
    --argjson pinned         "$pinned_json" \
    --argjson showDock       true \
    --argjson showBackground true \
    --argjson dockScale      1.0 \
    --argjson autoHide       false \
    '{
        pinned:         $pinned,
        leftModules:    ["Weather"],
        rightModules:   ["Power", "Media", "Tray"],
        showDock:       $showDock,
        showBackground: $showBackground,
        dockScale:      $dockScale,
        autoHide:       $autoHide
    }' > "$tmp_config" && mv -- "$tmp_config" "$CONFIG_FILE" || {
        rm -f "$tmp_config"
        echo "error: could not write dock_config.json" >&2
        exit 1
    }

echo "generated"
