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

# oo prettyh
declare -A colors=(
    [GREEN]="\033[0;32m"
    [YELLOW]="\033[1;33m"
    [BLUE]="\033[1;34m"
    [RED]="\033[0;31m"
    [CYAN]="\033[0;36m"
    [BOLD]="\033[1m"
    [RESET]="\033[0m"
)

apps=()
declare -A custom_menus
declare -A custom_lists

load_custom_menus() {
    [[ ! -f "$config_file" ]] && return

    local menu_name=""
    while IFS= read -r line; do
        line=${line##*( )}
        line=${line%%*( )}
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            menu_name="${BASH_REMATCH[1]}"
            custom_menus["$menu_name"]=""
        elif [[ "$line" == *=* ]]; then
            IFS='=' read -r app_name app_command <<< "$line"
            custom_menus["$menu_name"]+="${app_name}:${app_command}"$'\n'
        fi
    done < "$config_file"
}

load_custom_lists() {
    [[ ! -f "$config_file" ]] && return

    local list_name=""
    while IFS= read -r line; do
        line=${line##*( )}
        line=${line%%*( )}
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" =~ ^\{(.*)\}$ ]]; then
            list_name="${BASH_REMATCH[1]}"
            custom_lists["$list_name"]=()
        elif [[ "$line" == -* ]]; then
            custom_lists["$list_name"]+="${line#- }"$'\n'
        fi
    done < "$config_file"
}

parse_desktop_files() {
    apps=()
    for dir in "${desktop_files_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r desktop_file; do
            [[ -f "$desktop_file" ]] || continue
            local name exec_command
            name=$(sed -n 's/^Name=//p' "$desktop_file" | head -n1)
            exec_command=$(sed -n 's/^Exec=//p' "$desktop_file" | head -n1 | sed 's/ *%[UuFfNn]//g')
            [[ -n "$name" && -n "$exec_command" ]] && apps+=("$name:$exec_command")
        done < <(find "$dir" -name '*.desktop')
    done
}

display_menu() {
    local current_menu="$1"
    local search_term=""
    local mode="menu"
    local selected_index=0

    while true; do
        clear
        echo -e "${colors[BLUE]}${colors[BOLD]}Current ${mode^}: $current_menu${colors[RESET]}"
        echo -e "${colors[CYAN]}-------------------------------------------${colors[RESET]}"
        echo -e "${colors[YELLOW]}Use Up/Down arrows to select apps. Left/Right arrows to switch ${mode}s.${colors[RESET]}"
        echo -e "${colors[YELLOW]}Type to search. Press Enter to launch.${colors[RESET]}"
        echo

        local -a filtered_items
        if [[ "$mode" == "menu" ]]; then
            if [[ "$current_menu" == "Default" ]]; then
                mapfile -t filtered_items < <(printf '%s\n' "${apps[@]}" | cut -d: -f1 | grep -i "$search_term")
            else
                mapfile -t filtered_items < <(echo -n "${custom_menus[$current_menu]}" | grep -i "$search_term" | cut -d: -f1)
            fi
        else
            mapfile -t filtered_items < <(echo -n "${custom_lists[$current_menu]}" | grep -i "$search_term")
        fi

        for i in "${!filtered_items[@]}"; do
            if [ $i -eq $selected_index ]; then
                echo -e "${colors[GREEN]}> $((i+1))) ${filtered_items[$i]}${colors[RESET]}"
            else
                echo "  $((i+1))) ${filtered_items[$i]}"
            fi
        done

        echo
        echo -e "${colors[CYAN]}Search: $search_term${colors[RESET]}"
        echo -e "${colors[YELLOW]}Use arrow keys to navigate, type to search, or press Enter to launch.${colors[RESET]}"
        read -rsn1 key

        case "$key" in
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[C') current_menu=$(next_menu "$current_menu" "$mode"); search_term=""; selected_index=0 ;;
                    '[D') current_menu=$(previous_menu "$current_menu" "$mode"); search_term=""; selected_index=0 ;;
                    '[A') ((selected_index > 0)) && ((selected_index--)) ;;
                    '[B') ((selected_index < ${#filtered_items[@]} - 1)) && ((selected_index++)) ;;
                esac
                ;;
            "")
                if ((selected_index < ${#filtered_items[@]})); then
                    local selected_name="${filtered_items[$selected_index]}"
                    local exec_command
                    if [[ "$mode" == "menu" ]]; then
                        if [[ "$current_menu" == "Default" ]]; then
                            exec_command=$(printf '%s\n' "${apps[@]}" | grep "^${selected_name}:" | cut -d: -f2-)
                        else
                            exec_command=$(echo -n "${custom_menus[$current_menu]}" | grep "^${selected_name}:" | cut -d: -f2-)
                        fi
                    else
                        exec_command=$(printf '%s\n' "${apps[@]}" | grep "^${selected_name}:" | cut -d: -f2-)
                    fi
                    launch_app "$exec_command"
                    break
                fi
                ;;
            $'\x7f') search_term="${search_term%?}"; selected_index=0 ;;
            *) search_term+="$key"; selected_index=0 ;;
        esac
    done
}

previous_menu() {
    local current_menu="$1"
    local mode="$2"
    local -a menu_list
    if [[ "$mode" == "menu" ]]; then
        menu_list=("Default" "${!custom_menus[@]}")
    else
        menu_list=("${!custom_lists[@]}")
    fi
    local index
    for i in "${!menu_list[@]}"; do
        [[ "${menu_list[$i]}" == "$current_menu" ]] && { index=$i; break; }
    done
    ((index <= 0)) && echo "${menu_list[-1]}" || echo "${menu_list[$((index-1))]}"
}

next_menu() {
    local current_menu="$1"
    local mode="$2"
    local -a menu_list
    if [[ "$mode" == "menu" ]]; then
        menu_list=("Default" "${!custom_menus[@]}")
    else
        menu_list=("${!custom_lists[@]}")
    fi
    local index
    for i in "${!menu_list[@]}"; do
        [[ "${menu_list[$i]}" == "$current_menu" ]] && { index=$i; break; }
    done
    ((index >= ${#menu_list[@]} - 1)) && echo "${menu_list[0]}" || echo "${menu_list[$((index+1))]}"
}

launch_app() {
    local exec_command="$1"
    if [[ -n "$exec_command" ]]; then
        echo -e "${colors[GREEN]}Executing: $exec_command${colors[RESET]}"
        setsid $exec_command >/dev/null 2>&1 &
        disown
        exit 0
    else
        echo -e "${colors[RED]}Error: Command not found.${colors[RESET]}"
    fi
}

load_custom_menus
load_custom_lists
parse_desktop_files

if [[ ${#apps[@]} -eq 0 && ${#custom_menus[@]} -eq 0 && ${#custom_lists[@]} -eq 0 ]]; then
    echo -e "${colors[RED]}No applications found.${colors[RESET]}"
    exit 1
else
    display_menu "Default"
fi
