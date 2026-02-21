#!/usr/bin/env bash
# script to parse .desktop applications and output JSON

DIRS="/usr/share/applications /var/lib/flatpak/exports/share/applications ~/.local/share/applications"

# Array to hold JSON objects
apps=()

# Process each .desktop file
for dir in $DIRS; do
    if [ ! -d "$dir" ]; then continue; fi

    while IFS= read -r -d $'\0' file; do
        # Extract fields
        name=$(grep -m 1 "^Name=" "$file" | cut -d'=' -f2-)
        exec_cmd=$(grep -m 1 "^Exec=" "$file" | cut -d'=' -f2- | sed 's/ %[a-zA-Z]//g')
        icon=$(grep -m 1 "^Icon=" "$file" | cut -d'=' -f2-)
        nodisplay=$(grep -m 1 "^NoDisplay=" "$file" | cut -d'=' -f2-)
        
        # Skip if NoDisplay is true or if basic info is missing
        if [[ "$nodisplay" == "true" ]] || [[ -z "$name" ]] || [[ -z "$exec_cmd" ]]; then
            continue
        fi

        # Escape quotes for JSON
        name="${name//\"/\\\"}"
        exec_cmd="${exec_cmd//\"/\\\"}"
        icon="${icon//\"/\\\"}"

        # Build JSON object for this app
        apps+=("{\"name\":\"$name\",\"exec\":\"$exec_cmd\",\"icon\":\"$icon\"}")

    done < <(find "$dir" -maxdepth 2 -name "*.desktop" -print0 2>/dev/null)
done

# Output formatted JSON Array
printf "[\n"
for i in "${!apps[@]}"; do
    printf "  %s" "${apps[$i]}"
    # Print comma if it isn't the last element
    if [[ $i -lt $((${#apps[@]} - 1)) ]]; then
        printf ",\n"
    else
        printf "\n"
    fi
done
printf "]\n"
