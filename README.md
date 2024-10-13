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
Firefox=firefox
VSCode=code
Terminal=kitty

[Utils]
Convert-images=Switcheroo
Dither-images=Halftone
```

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
