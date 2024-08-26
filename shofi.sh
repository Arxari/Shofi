#!/bin/bash

# .desktop directories
desktop_files_dirs=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
    "/usr/local/share/applications"
    "/var/lib/flatpak/exports/share/applications"
)

# config file location
config_file="$HOME/.config/shofi/menus.conf"

apps=()
custom_menus=()

load_custom_menus() {
    if [ -f "$config_file" ]; then
        local menu_name=""
        while IFS= read -r line; do
            line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')
            if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
                continue
            fi
            if [[ "$line" =~ ^\[(.*)\]$ ]]; then
                menu_name="${BASH_REMATCH[1]}"
                custom_menus+=("$menu_name")
                eval "${menu_name}_apps=()"
            elif [[ "$line" =~ = ]]; then
                app_name=$(echo "$line" | cut -d'=' -f1)
                app_command=$(echo "$line" | cut -d'=' -f2-)
                eval "${menu_name}_apps+=('$app_name:$app_command')"
            fi
        done < "$config_file"
    fi
}

parse_desktop_files() {
    for dir in "${desktop_files_dirs[@]}"; do
        if [ -d "$dir" ]; then
            for desktop_file in "$dir"/*.desktop; do
                if [ -f "$desktop_file" ]; then
                    name=$(grep -m 1 '^Name=' "$desktop_file" | cut -d'=' -f2-)
                    name=$(echo "$name" | sed 's/ /-/g')  # Replace spaces with hyphens
                    exec_command=$(grep -m 1 '^Exec=' "$desktop_file" | cut -d'=' -f2-)
                    exec_command=$(echo "$exec_command" | sed 's/ *%[UuFfNn]//g')
                    if [ -n "$name" ] && [ -n "$exec_command" ]; then
                        apps+=("$name:$exec_command")
                    fi
                fi
            done
        fi
    done
}

display_menu() {
    local current_menu="$1"
    local search_term=""

    while true; do
        clear
        echo "Current Menu: $current_menu"
        echo "-------------------------------------------"
        echo "Use Left/Right arrows to switch menus. Press Enter to launch."
        echo

        if [[ "$current_menu" == "Default" ]]; then
            menu_apps=("${apps[@]}")
        else
            eval "menu_apps=(\"\${${current_menu}_apps[@]}\")"
        fi

        if [ -n "$search_term" ]; then
            filtered_apps=($(printf "%s\n" "${menu_apps[@]}" | grep -i "$search_term" | awk -F ':' '{print $1}'))
        else
            filtered_apps=($(printf "%s\n" "${menu_apps[@]}" | awk -F ':' '{print $1}'))
        fi

        for i in "${!filtered_apps[@]}"; do
            echo "$((i+1))) ${filtered_apps[$i]}"
        done

        echo
        echo "Type to search or enter the number of the application: "
        read -r user_input

        if [[ "$user_input" =~ ^[0-9]+$ ]] && [ "$user_input" -le "${#filtered_apps[@]}" ] && [ "$user_input" -ge 1 ]; then
            selected_index=$((user_input-1))
            selected_name="${filtered_apps[$selected_index]}"
            exec_command=$(printf "%s\n" "${menu_apps[@]}" | grep "^${selected_name}:" | awk -F ':' '{print $2}')
            launch_app "$exec_command"
            break
        elif [[ -n "$user_input" ]]; then
            search_term="$user_input"
        fi
    done
}

previous_menu() {
    local current_menu="$1"
    local index=-1
    for i in "${!custom_menus[@]}"; do
        if [ "${custom_menus[$i]}" == "$current_menu" ]; then
            index=$i
            break
        fi
    done
    if [ "$index" -le 0 ]; then
        echo "Default"
    else
        echo "${custom_menus[$((index-1))]}"
    fi
}

next_menu() {
    local current_menu="$1"
    local index=-1
    for i in "${!custom_menus[@]}"; do
        if [ "${custom_menus[$i]}" == "$current_menu" ]; then
            index=$i
            break
        fi
    done
    if [ "$index" -ge $((${#custom_menus[@]} - 1)) ]; then
        echo "Default"
    else
        echo "${custom_menus[$((index+1))]}"
    fi
}

launch_app() {
    local exec_command="$1"

    if [ -n "$exec_command" ]; then
        echo "Executing: $exec_command"
        eval "$exec_command" &
    else
        echo "Error: Command not found."
    fi
}

load_custom_menus
parse_desktop_files

if [ ${#apps[@]} -eq 0 ] && [ ${#custom_menus[@]} -eq 0 ]; then
    echo "No applications found."
    exit 1
else
    current_menu="Default"
    display_menu "$current_menu"
fi
