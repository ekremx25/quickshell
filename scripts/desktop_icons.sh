#!/usr/bin/env bash
set -o pipefail
shopt -s nullglob
# desktop_icons.sh - Generates app_id → icon_name, app_id → exec_command and app_id → desktop_id maps.
# Same approach as Rofi/Wofi: resolve from .desktop metadata.
# Output: Three JSON objects separated by newline.
#   Line 1: icon map    {"app_id":"icon_name", ...}
#   Line 2: command map {"app_id":"full_exec_command", ...}
#   Line 3: desktop map {"app_id":"desktop-id", ...}

DESKTOP_DIRS="/usr/share/applications $HOME/.local/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/flatpak/exports/share/applications"

declare -A icon_map
declare -A cmd_map
declare -A desktop_map

for dir in $DESKTOP_DIRS; do
    [ -d "$dir" ] || continue
    for desktop_file in "$dir"/*.desktop; do
        [ -f "$desktop_file" ] || continue

        icon="" wmclass="" exec_name="" exec_full="" app_name=""
        desktop_basename=$(basename "$desktop_file" .desktop)

        # Parse only [Desktop Entry] section and first occurrence of keys.
        in_entry=0
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                "[Desktop Entry]") in_entry=1; continue ;;
                \[*\]) in_entry=0; continue ;;
            esac
            [ "$in_entry" -eq 1 ] || continue

            case "$line" in
                Icon=*)
                    [ -z "$icon" ] && icon="${line#Icon=}"
                    ;;
                StartupWMClass=*)
                    [ -z "$wmclass" ] && wmclass="${line#StartupWMClass=}"
                    ;;
                Exec=*)
                    if [ -z "$exec_full" ]; then
                        value="${line#Exec=}"
                        # Strip desktop field codes (%u %U %f %F %i %c %k ...)
                        exec_full=$(printf '%s' "$value" | sed -E 's/ ?%[a-zA-Z]//g')
                        # Get first token for alias mapping (quoted binary safe)
                        exec_name=$(printf '%s' "$exec_full" | awk '
                            {
                              if ($0 ~ /^"/) {
                                sub(/^"/, "", $0);
                                split($0, a, "\"");
                                print a[1];
                              } else {
                                print $1;
                              }
                            }')
                        exec_name=$(basename "$exec_name")
                    fi
                    ;;
                Name=*)
                    [ -z "$app_name" ] && app_name="${line#Name=}"
                    ;;
            esac
        done < "$desktop_file"

        [ -z "$icon" ] && continue

        # .desktop basename → icon & cmd
        db_lower=$(echo "$desktop_basename" | tr '[:upper:]' '[:lower:]')
        icon_map["$db_lower"]="$icon"
        [ -n "$exec_full" ] && cmd_map["$db_lower"]="$exec_full"
        desktop_map["$db_lower"]="$desktop_basename"

        # WMClass → icon & cmd (window app_id is usually equal to this)
        if [ -n "$wmclass" ]; then
            wm_lower=$(echo "$wmclass" | tr '[:upper:]' '[:lower:]')
            icon_map["$wm_lower"]="$icon"
            [ -n "$exec_full" ] && cmd_map["$wm_lower"]="$exec_full"
            desktop_map["$wm_lower"]="$desktop_basename"
        fi

        # Exec name → icon & cmd
        if [ -n "$exec_name" ]; then
            exec_lower=$(echo "$exec_name" | tr '[:upper:]' '[:lower:]')
            icon_map["$exec_lower"]="$icon"
            [ -n "$exec_full" ] && cmd_map["$exec_lower"]="$exec_full"
            desktop_map["$exec_lower"]="$desktop_basename"
        fi

        # Localized/visible app name → icon/cmd/desktop (helps with odd app_id/class names)
        if [ -n "$app_name" ]; then
            name_key=$(printf '%s' "$app_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+/-/g; s/[^a-z0-9._-]//g')
            if [ -n "$name_key" ]; then
                icon_map["$name_key"]="$icon"
                [ -n "$exec_full" ] && cmd_map["$name_key"]="$exec_full"
                desktop_map["$name_key"]="$desktop_basename"
            fi
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
    value=$(printf '%s' "${cmd_map[$key]}" | sed 's/"/\\"/g')
    printf '"%s":"%s"' "$key" "$value"
done
echo ""
echo "}"

# JSON output - Line 3: desktop ids
echo "{"
first=true
for key in "${!desktop_map[@]}"; do
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    value="${desktop_map[$key]}"
    printf '"%s":"%s"' "$key" "$value"
done
echo ""
echo "}"
