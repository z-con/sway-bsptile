#!/bin/sh
# Synthesizes a paste keystroke into whatever window is currently focused.
# Most apps treat Ctrl+V as paste, but terminal emulators (ghostty included)
# reserve plain Ctrl+V for readline/shell use and bind paste to
# Ctrl+Shift+V instead -- so pick the keystroke based on the focused app_id.
app_id=$(swaymsg -t get_tree | jq -r '.. | objects | select(.focused == true) | .app_id // .window_properties.class // empty')

case "$app_id" in
    com.mitchellh.ghostty|kitty|Alacritty|foot|org.gnome.Terminal|xterm|wezterm)
        wtype -M ctrl -M shift -P v -p v -m shift -m ctrl
        ;;
    *)
        wtype -M ctrl -P v -p v -m ctrl
        ;;
esac
