# Shofi
Wofi/Rofi but it's in Shell

#### Features!
- Runs in your terminal, no need for GUIs
- Customizable app menus/lists
- Supports both Wayland and X11*
- Configuration and cache files respect XDG Base Directory Specifications
###### *as long as your terminal does

#### Example config
###### (~/.config/shofi/menus.conf by default)
```
[Apps]
[Apps]
Zen-browser=zen-browser
Zed=zeditor
Terminal=alacritty

[Utils]
Convert-images=flatpak run io.gitlab.adhami3310.Converter
Dither-images=flatpak run halftone io.github.tfuxu.Halftone
```
Currently the menus work by just executing the thing behind =, this means that for pacman/aur apps you need to use the same name you'd use to execute it from the terminal and for flatpak apps you need to use flatpak run

###### I won't support snaps in the script, if you want snap support you need to edit the script yourself locally to add support (I won't accept PRs adding snap support)

<details closed>

<summary>How to install</summary>

- Git clone the repo
```git clone https://github.com/Arxari/Shofi.git```
- Make the shell script executable
```chmod +x location/to/your/shofi.sh```
- If you want to make your life easy it, add it to your .bashrc/.zshrc
```alias shofi='location/to/your/shofi.sh```

</details closed>


<details closed>
<summary>Do you want to use shofi as a popup window?</summary>

If you are using Hyprland, you can setup your Hyprland.conf like this:
```
# Shofi
windowrulev2 = float, class:kitty, title:^(shofi)$           # Makes the window float
windowrulev2 = size 600 600, class:kitty, title:^(shofi)$    # Set fixed width (600) and fixed height (600)
bind = $mainMod, L, exec, kitty --title shofi -e zsh -c "location/to/your/shofi.sh; exec zsh"
```
If you've used ezsh to set up the script, you can just just ```shofi``` instead of ```location/to/your/shofi.sh```
Make sure to change ```kitty``` to whatever terminal you want to use (note, cool-retro-term does not work with the --title command)

</details closed>
