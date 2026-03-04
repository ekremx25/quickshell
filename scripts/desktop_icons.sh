#!/bin/bash
# desktop_icons.sh - Generates app_id → icon_name AND app_id → exec_command JSON maps from .desktop files.
# Same approach as Rofi/Wofi: Use the Icon= and Exec= values in the .desktop file.
# Output: Two lines of JSON separated by newline.
#   Line 1: icon map   {"app_id": "icon_name", ...}
#   Line 2: command map {"app_id": "full_exec_command", ...}

DESKTOP_DIRS="/usr/share/applications $HOME/.local/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/flatpak/exports/share/applications"

declare -A icon_map
declare -A cmd_map

for dir in $DESKTOP_DIRS; do
    [ -d "$dir" ] || continue
    for desktop_file in "$dir"/*.desktop; do
        [ -f "$desktop_file" ] || continue

        icon="" wmclass="" exec_name="" exec_full=""
        desktop_basename=$(basename "$desktop_file" .desktop)

        while IFS='=' read -r key value; do
            case "$key" in
                Icon) icon="$value" ;;
                StartupWMClass) wmclass="$value" ;;
                Exec)
                    # Full exec line, strip %u %U %f %F %i %c %k field codes
                    exec_full=$(echo "$value" | sed 's/ %[uUfFickdDnNvm]//g')
                    # Get first word for short name
                    exec_name=$(echo "$value" | awk '{print $1}')
                    exec_name=$(basename "$exec_name")
                    ;;
            esac
        done < <(grep -E '^(Icon|StartupWMClass|Exec)=' "$desktop_file" 2>/dev/null | head -3)

        [ -z "$icon" ] && continue

        # .desktop basename → icon & cmd
        db_lower=$(echo "$desktop_basename" | tr '[:upper:]' '[:lower:]')
        icon_map["$db_lower"]="$icon"
        [ -n "$exec_full" ] && cmd_map["$db_lower"]="$exec_full"

        # WMClass → icon & cmd (window app_id is usually equal to this)
        if [ -n "$wmclass" ]; then
            wm_lower=$(echo "$wmclass" | tr '[:upper:]' '[:lower:]')
            icon_map["$wm_lower"]="$icon"
            [ -n "$exec_full" ] && cmd_map["$wm_lower"]="$exec_full"
        fi

        # Exec adı → icon & cmd
        if [ -n "$exec_name" ]; then
            exec_lower=$(echo "$exec_name" | tr '[:upper:]' '[:lower:]')
            icon_map["$exec_lower"]="$icon"
            [ -n "$exec_full" ] && cmd_map["$exec_lower"]="$exec_full"
        fi
    done
done

# JSON output - Line 1: icons
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

# JSON output - Line 2: commands
echo "{"
first=true
for key in "${!cmd_map[@]}"; do
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    # Escape double quotes in command values
    value=$(echo "${cmd_map[$key]}" | sed 's/"/\\"/g')
    printf '"%s":"%s"' "$key" "$value"
done
echo ""
echo "}"
