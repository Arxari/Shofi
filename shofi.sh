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

# cache file location
cache_file="$HOME/.cache/shofi/cache.txt"

apps=()
custom_menus=()
custom_lists=()

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

load_custom_lists() {
    if [ -f "$config_file" ]; then
        local list_name=""
        while IFS= read -r line; do
            line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')
            if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
                continue
            fi
            if [[ "$line" =~ ^\{(.*)\}$ ]]; then
                list_name="${BASH_REMATCH[1]}"
                custom_lists+=("$list_name")
                eval "${list_name}_list=()"
            elif [[ "$line" =~ ^- ]]; then
                app_name=$(echo "$line" | sed 's/^- *//')
                eval "${list_name}_list+=('$app_name')"
            fi
        done < "$config_file"
    fi
}

parse_desktop_files() {
    local cache_is_valid=true
    for dir in "${desktop_files_dirs[@]}"; do
        if [ -d "$dir" ]; then
            for desktop_file in "$dir"/*.desktop; do
                if [ -f "$desktop_file" ] && [ "$desktop_file" -nt "$cache_file" ]; then
                    cache_is_valid=false
                    break 2
                fi
            done
        fi
    done

    if [ "$cache_is_valid" = true ] && [ -f "$cache_file" ]; then
        mapfile -t apps < "$cache_file"
    else
        apps=()
        for dir in "${desktop_files_dirs[@]}"; do
            if [ -d "$dir" ]; then
                for desktop_file in "$dir"/*.desktop; do
                    if [ -f "$desktop_file" ]; then
                        name=$(grep -m 1 '^Name=' "$desktop_file" | cut -d'=' -f2-)
                        name=$(echo "$name" | sed 's/ /-/g')
                        exec_command=$(grep -m 1 '^Exec=' "$desktop_file" | cut -d'=' -f2-)
                        exec_command=$(echo "$exec_command" | sed 's/ *%[UuFfNn]//g')
                        if [ -n "$name" ] && [ -n "$exec_command" ]; then
                            apps+=("$name:$exec_command")
                        fi
                    fi
                done
            fi
        done

        mkdir -p "$(dirname "$cache_file")"
        printf "%s\n" "${apps[@]}" > "$cache_file"
    fi
}

display_menu() {
    local current_menu="$1"
    local search_term=""
    local mode="menu"
    local selected_index=0

    while true; do
        clear
        echo "Current ${mode^}: $current_menu"
        echo "-------------------------------------------"
        echo "Use Up/Down arrows to select apps. Left/Right arrows to switch ${mode}s."
        echo "Type to search. Press Enter to launch."
        echo

        if [[ "$mode" == "menu" ]]; then
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
                if [ $i -eq $selected_index ]; then
                    echo "> $((i+1))) ${filtered_apps[$i]}"
                else
                    echo "  $((i+1))) ${filtered_apps[$i]}"
                fi
            done
        else
            eval "list_apps=(\"\${${current_menu}_list[@]}\")"
            if [ -n "$search_term" ]; then
                filtered_list_apps=($(printf "%s\n" "${list_apps[@]}" | grep -i "$search_term"))
            else
                filtered_list_apps=("${list_apps[@]}")
            fi
            for i in "${!filtered_list_apps[@]}"; do
                if [ $i -eq $selected_index ]; then
                    echo "> $((i+1))) ${filtered_list_apps[$i]}"
                else
                    echo "  $((i+1))) ${filtered_list_apps[$i]}"
                fi
            done
        fi

        echo
        echo "Search: $search_term"
        echo "Use arrow keys to navigate, type to search, or press Enter to launch."
        read -rsn1 key

        case "$key" in
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[C')
                        if [[ "$mode" == "menu" ]]; then
                            current_menu=$(next_menu "$current_menu")
                        else
                            current_menu=$(next_list "$current_menu")
                        fi
                        search_term=""
                        selected_index=0
                        ;;
                    '[D')
                        if [[ "$mode" == "menu" ]]; then
                            current_menu=$(previous_menu "$current_menu")
                        else
                            current_menu=$(previous_list "$current_menu")
                        fi
                        search_term=""
                        selected_index=0
                        ;;
                    '[A')
                        if [ $selected_index -gt 0 ]; then
                            selected_index=$((selected_index - 1))
                        fi
                        ;;
                    '[B')
                        if [[ "$mode" == "menu" ]]; then
                            if [ $selected_index -lt $((${#filtered_apps[@]} - 1)) ]; then
                                selected_index=$((selected_index + 1))
                            fi
                        else
                            if [ $selected_index -lt $((${#filtered_list_apps[@]} - 1)) ]; then
                                selected_index=$((selected_index + 1))
                            fi
                        fi
                        ;;
                esac
                ;;
            "")
                if [[ "$mode" == "menu" ]]; then
                    if [ $selected_index -lt ${#filtered_apps[@]} ]; then
                        selected_name="${filtered_apps[$selected_index]}"
                        exec_command=$(printf "%s\n" "${menu_apps[@]}" | grep "^${selected_name}:" | awk -F ':' '{print $2}')
                        launch_app "$exec_command"
                        break
                    fi
                else
                    if [ $selected_index -lt ${#filtered_list_apps[@]} ]; then
                        selected_name="${filtered_list_apps[$selected_index]}"
                        exec_command=$(printf "%s\n" "${apps[@]}" | grep "^${selected_name}:" | awk -F ':' '{print $2}')
                        launch_app "$exec_command"
                        break
                    fi
                fi
                ;;
            $'\x7f')
                search_term="${search_term%?}"
                selected_index=0
                ;;
            *)
                search_term+="$key"
                selected_index=0
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

previous_list() {
    local current_list="$1"
    local index=-1
    for i in "${!custom_lists[@]}"; do
        if [ "${custom_lists[$i]}" == "$current_list" ]; then
            index=$i
            break
        fi
    done
    if [ "$index" -le 0 ]; then
        echo "${custom_lists[-1]}"
    else
        echo "${custom_lists[$((index-1))]}"
    fi
}

next_list() {
    local current_list="$1"
    local index=-1
    for i in "${!custom_lists[@]}"; do
        if [ "${custom_lists[$i]}" == "$current_list" ]; then
            index=$i
            break
        fi
    done
    if [ "$index" -ge $((${#custom_lists[@]} - 1)) ]; then
        echo "${custom_lists[0]}"
    else
        echo "${custom_lists[$((index+1))]}"
    fi
}

launch_app() {
    local exec_command="$1"

    if [ -n "$exec_command" ]; then
        echo "Executing: $exec_command"
        setsid $exec_command >/dev/null 2>&1 &
        disown
        exit_script
    else
        echo "Error: Command not found."
    fi
}

exit_script() {
    exit 0
    exec $SHELL -c "exit"
}

load_custom_menus
load_custom_lists
parse_desktop_files

if [ ${#apps[@]} -eq 0 ] && [ ${#custom_menus[@]} -eq 0 ] && [ ${#custom_lists[@]} -eq 0 ]; then
    echo "No applications found."
    exit 1
else
    current_menu="Default"
    display_menu "$current_menu"
fi
