#!/bin/bash
# Mission-Control-ish stand-in for sway: list every open window across all
# workspaces in wofi and jump straight to whichever one gets picked. Not
# spatial like macOS's exposé, but same job -- one gesture, see everything
# open, land on one. Bound to a 3-finger swipe up.
#
# Each entry shows its app icon (not a live thumbnail -- simpler and more
# consistent across workspaces, since sway/wlroots can't screenshot a
# window that isn't currently on screen anyway).
set -euo pipefail

tree_json=$(mktemp)
trap 'rm -f "$tree_json"' EXIT
swaymsg -t get_tree > "$tree_json"

line_num=$(python3 ~/.local/share/sway-scripts/window-switcher.py list < "$tree_json" \
    | wofi --dmenu --allow-images -O default -D dmenu-print_line_num=true --prompt "Windows")

[ -n "$line_num" ] || exit 0

target=$(python3 ~/.local/share/sway-scripts/window-switcher.py id "$line_num" < "$tree_json")

[ -n "$target" ] && swaymsg "[con_id=$target] focus"
