#!/usr/bin/env bash
set -euo pipefail
# init_dock.sh - Sisteme kurulu uygulamalara göre dock_config.json oluşturur.
# dock_config.json yoksa ilk çalıştırmada otomatik çağrılır.
#
# Güvenlik notu: JSON çıktısı jq ile üretilir; uygulama adı, ikon veya komut
# içinde özel karakter / tırnak bulunsa bile JSON bozulmaz (injection yok).

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# jq zorunlu bağımlılık
if ! command_exists jq; then
    echo "error: jq bulunamadı. Lütfen jq kurun." >&2
    exit 1
fi

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

# Bulunan uygulamaların jq JSON nesnelerini bu diziye topla
pinned_entries=()

for entry in "${APPS[@]}"; do
    IFS='|' read -r appId name cmd icon <<< "$entry"

    # Komutun ilk kelimesini al (nautilus --new-window → nautilus)
    bin=$(printf '%s\n' "$cmd" | awk '{print $1}')

    # Kurulu mu kontrol et
    if ! command_exists "$bin"; then
        continue
    fi

    # Kategori bazlı limit (sadece ilk bulunan)
    case "$name" in
        Files) [ "$found_filemanager" -ge 1 ] && continue; found_filemanager=$((found_filemanager+1)) ;;
        Firefox|Brave|Chrome|Chromium|Vivaldi|Opera) [ "$found_browser" -ge 2 ] && continue; found_browser=$((found_browser+1)) ;;
        Alacritty|Kitty|Foot|WezTerm|Ghostty|Konsole|Terminal) [ "$found_terminal" -ge 1 ] && continue; found_terminal=$((found_terminal+1)) ;;
        "VS Code"|Cursor|Zed) [ "$found_editor" -ge 1 ] && continue; found_editor=$((found_editor+1)) ;;
    esac

    # jq --arg ile değişkenleri güvenli şekilde JSON'a yerleştir.
    # Tırnak, ters eğik çizgi veya unicode içeren değerler otomatik escape edilir.
    entry_json=$(jq -cn \
        --arg name  "$name" \
        --arg icon  "$icon" \
        --arg cmd   "$cmd" \
        --arg appId "$appId" \
        '{name: $name, icon: $icon, cmd: $cmd, appId: $appId}')

    pinned_entries+=("$entry_json")
done

# Dizi elemanlarını jq ile JSON array'e dönüştür
if [ ${#pinned_entries[@]} -eq 0 ]; then
    pinned_json="[]"
else
    pinned_json=$(printf '%s\n' "${pinned_entries[@]}" | jq -s '.')
fi

# Tam konfigürasyonu jq ile üret ve atomik geçici dosya + mv ile yaz
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
        echo "error: dock_config.json yazılamadı" >&2
        exit 1
    }

echo "generated"
