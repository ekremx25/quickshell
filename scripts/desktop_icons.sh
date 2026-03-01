#!/bin/bash
# desktop_icons.sh - Generates app_id → icon_name JSON map from .desktop files.
# Same approach as Rofi/Wofi: Use the Icon= value in the .desktop file.
# Very fast: only text file reading (~50ms)

DESKTOP_DIRS="/usr/share/applications $HOME/.local/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/flatpak/exports/share/applications"

declare -A icon_map

for dir in $DESKTOP_DIRS; do
    [ -d "$dir" ] || continue
    for desktop_file in "$dir"/*.desktop; do
        [ -f "$desktop_file" ] || continue

        icon="" wmclass="" exec_name=""
        desktop_basename=$(basename "$desktop_file" .desktop)

        while IFS='=' read -r key value; do
            case "$key" in
                Icon) icon="$value" ;;
                StartupWMClass) wmclass="$value" ;;
                Exec)
                    # Get first word, discard parameters like %u %F
                    exec_name=$(echo "$value" | awk '{print $1}')
                    exec_name=$(basename "$exec_name")
                    ;;
            esac
        done < <(grep -E '^(Icon|StartupWMClass|Exec)=' "$desktop_file" 2>/dev/null | head -3)

        [ -z "$icon" ] && continue

        # .desktop basename → icon
        db_lower=$(echo "$desktop_basename" | tr '[:upper:]' '[:lower:]')
        icon_map["$db_lower"]="$icon"

        # WMClass → icon (window app_id is usually equal to this)
        if [ -n "$wmclass" ]; then
            wm_lower=$(echo "$wmclass" | tr '[:upper:]' '[:lower:]')
            icon_map["$wm_lower"]="$icon"
        fi

        # Exec adı → icon
        if [ -n "$exec_name" ]; then
            exec_lower=$(echo "$exec_name" | tr '[:upper:]' '[:lower:]')
            icon_map["$exec_lower"]="$icon"
        fi
    done
done

# JSON output
echo "{"
first=true
for key in "${!icon_map[@]}"; do
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    value="${icon_map[$key]}"
    printf '"%s":"%s"' "$key" "$value"
done
echo ""
echo "}"
