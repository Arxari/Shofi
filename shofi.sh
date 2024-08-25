#!/bin/bash

# .desktop directories
desktop_files_dirs=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
    "/usr/local/share/applications"
#    "/var/lib/flatpak/exports/share/applications/" Flatpak support is currently in the works

)

# Config file location
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
                    name=$(grep -m 1 '^Name=' "$desktop_file" | cut -d'=' -f2)
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
            filtered_apps=($(printf "%s\n" "${menu_apps[@]}" | grep -i "$search_term"))
        else
            filtered_apps=("${menu_apps[@]}")
        fi

        for i in "${!filtered_apps[@]}"; do
            echo "$((i+1))) ${filtered_apps[$i]%%:*}"
        done

        echo
        echo "Type to search or enter the number of the application: "
        read -rsn1 user_input

        case "$user_input" in
            $'\x1b')
                read -rsn2 -t 0.1 key
                if [[ "$key" == "[D" ]]; then
                    current_menu=$(previous_menu "$current_menu")
                elif [[ "$key" == "[C" ]]; then
                    current_menu=$(next_menu "$current_menu")
                fi
                ;;
            [0-9]*)
                if [[ "$user_input" =~ ^[0-9]+$ ]] && [ "$user_input" -le "${#filtered_apps[@]}" ] && [ "$user_input" -ge 1 ]; then
                    selected_app="${filtered_apps[$((user_input-1))]%%:*}"
                    launch_app "$selected_app" "$current_menu"
                    break
                fi
                ;;
            *)
                search_term+="$user_input"
                ;;
        esac
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
    local selected_app="$1"
    local current_menu="$2"
    if [[ "$current_menu" == "Default" ]]; then
        for app in "${apps[@]}"; do
            if [[ "$app" == "$selected_app:"* ]]; then
                exec_command="${app#*:}"
                echo "Executing: $exec_command"
                eval "$exec_command" &
                break
            fi
        done
    else
        eval "menu_apps=(\"\${${current_menu}_apps[@]}\")"
        for app in "${menu_apps[@]}"; do
            if [[ "$app" == "$selected_app:"* ]]; then
                exec_command="${app#*:}"
                echo "Executing: $exec_command"
                eval "$exec_command" &
                break
            fi
        done
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
