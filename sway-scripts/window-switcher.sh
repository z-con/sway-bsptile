#!/bin/bash
# Mission-Control-ish stand-in for sway: list every open window across all
# workspaces in wofi and jump straight to whichever one gets picked. Not
# spatial like macOS's exposé, but same job -- one gesture, see everything
# open, land on one. Bound to a 3-finger swipe up.
#
# Windows on the current workspace get a live thumbnail (grim can only
# screenshot what's actually being composited); everything else falls back
# to its app icon, since sway/wlroots has no way to capture a window that
# isn't on screen right now.
set -euo pipefail

tree_json=$(mktemp)
thumb_dir=$(mktemp -d)
trap 'rm -f "$tree_json"; rm -rf "$thumb_dir"' EXIT
swaymsg -t get_tree > "$tree_json"
current_ws=$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .name')

line_num=$(python3 ~/.local/share/sway-scripts/window-switcher.py list "$current_ws" "$thumb_dir" < "$tree_json" \
    | wofi --dmenu --allow-images -O default -D dmenu-print_line_num=true --prompt "Windows")

[ -n "$line_num" ] || exit 0

target=$(python3 ~/.local/share/sway-scripts/window-switcher.py id "$line_num" < "$tree_json")

[ -n "$target" ] && swaymsg "[con_id=$target] focus"
