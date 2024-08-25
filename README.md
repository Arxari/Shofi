# Shofi
Wofi/Rofi but it's in Shell

#### Example config
```
[Apps]
Firefox=firefox
VSCode=code
Terminal=kitty

[Utils]
Convert-images=Switcheroo
Dither-images=halftone
```

### Pro Tip
Use [ezsh](https://github.com/AAATBSGSHU/ezsh) to make setting up and usingthis script easier.
If you are using Hyprland, you can setup your Hyprland.conf like this:
```
# Shofi
windowrulev2 = float, class:kitty, title:^(shofi)$           # Makes the window float
windowrulev2 = size 600 600, class:kitty, title:^(shofi)$    # Set fixed width (2560) and fixed height (40)
bind = $mainMod, L, exec, kitty --title shofi -e zsh -c "location/to/your/shofi.sh; exec zsh"
```
Make sure to change `kitty` to whatever terminal you want to use.
