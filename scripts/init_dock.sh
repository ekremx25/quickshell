#!/bin/bash
# init_dock.sh - Sisteme kurulu uygulamalara göre dock_config.json oluşturur.
# dock_config.json yoksa ilk çalıştırmada otomatik çağrılır.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QS_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$QS_DIR/dock_config.json"

# Zaten varsa dokunma
if [ -f "$CONFIG_FILE" ]; then
    echo "exists"
    exit 0
fi

# Popüler uygulamalar — öncelik sırasına göre
# Format: "appId|name|cmd|icon"
APPS=(
    # Dosya Yöneticisi
    "org.gnome.Nautilus|Files|nautilus --new-window|org.gnome.Nautilus"
    "dolphin|Files|dolphin|org.kde.dolphin"
    "thunar|Files|thunar|Thunar"
    "nemo|Files|nemo|nemo"
    "pcmanfm|Files|pcmanfm|system-file-manager"
    "caja|Files|caja|caja"

    # Tarayıcılar
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

    # Editörler
    "code|VS Code|code|visual-studio-code"
    "cursor|Cursor|cursor|cursor"
    "zed|Zed|zed|zed"

    # İletişim
    "telegram-desktop|Telegram|telegram-desktop|telegram"
    "discord|Discord|discord|discord"
    "vesktop|Discord|vesktop|vesktop"
    "signal-desktop|Signal|signal-desktop|signal-desktop"
    "slack|Slack|slack|slack"

    # Medya
    "spotify|Spotify|spotify|spotify"
    "vlc|VLC|vlc|vlc"

    # Araçlar
    "virt-manager|Virt Manager|virt-manager|virt-manager"
    "obs|OBS Studio|obs|com.obsproject.Studio"
    "steam|Steam|steam|steam"
    "gimp|GIMP|gimp|gimp"
    "blender|Blender|blender|blender"
    "inkscape|Inkscape|inkscape|inkscape"
    "kdenlive|Kdenlive|kdenlive|kdenlive"
    "audacity|Audacity|audacity|audacity"
)

# Hangi kategoriden kaç tane eklendi sayacı
found_filemanager=0
found_browser=0
found_terminal=0
found_editor=0

pinned="["
first=true

for entry in "${APPS[@]}"; do
    IFS='|' read -r appId name cmd icon <<< "$entry"

    # Komutun ilk kelimesini al (nautilus --new-window → nautilus)
    bin=$(echo "$cmd" | awk '{print $1}')

    # Kurulu mu kontrol et
    if ! command -v "$bin" &>/dev/null; then
        continue
    fi

    # Kategori bazlı limit (sadece ilk bulunan)
    case "$name" in
        Files) [ "$found_filemanager" -ge 1 ] && continue; found_filemanager=$((found_filemanager+1)) ;;
        Firefox|Brave|Chrome|Chromium|Vivaldi|Opera) [ "$found_browser" -ge 2 ] && continue; found_browser=$((found_browser+1)) ;;
        Alacritty|Kitty|Foot|WezTerm|Ghostty|Konsole|Terminal) [ "$found_terminal" -ge 1 ] && continue; found_terminal=$((found_terminal+1)) ;;
        "VS Code"|Cursor|Zed) [ "$found_editor" -ge 1 ] && continue; found_editor=$((found_editor+1)) ;;
    esac

    if [ "$first" = true ]; then
        first=false
    else
        pinned="$pinned,"
    fi

    pinned="$pinned
    {
      \"name\": \"$name\",
      \"icon\": \"$icon\",
      \"cmd\": \"$cmd\",
      \"appId\": \"$appId\"
    }"
done

pinned="$pinned
  ]"

# JSON dosyasını yaz
cat > "$CONFIG_FILE" << ENDJSON
{
  "pinned": $pinned,
  "showBackground": true,
  "dockScale": 1.0,
  "autoHide": false,
  "modules": [
    "Launcher",
    "Weather",
    "Clock",
    "Power",
    "Media"
  ]
}
ENDJSON

echo "generated"
