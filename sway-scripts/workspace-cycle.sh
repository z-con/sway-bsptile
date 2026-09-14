#!/bin/bash
# Move to the next/previous numbered workspace. "next" always lands
# somewhere real: if workspace (current+1) doesn't exist yet, `swaymsg
# workspace number N` creates it fresh and empty -- this is what gives us
# GNOME/bsptile's "always one swipe away from a new empty workspace" feel,
# without needing to pre-create anything. "prev" stops at workspace 1
# rather than creating negative-numbered workspaces, since that's not a
# sensible direction to spawn new ones in.
set -euo pipefail

direction="${1:?usage: workspace-cycle.sh next|prev}"
current=$(swaymsg -t get_workspaces | jq '[.[] | select(.focused)][0].num')

case "$direction" in
    next)
        target=$((current + 1))
        ;;
    prev)
        target=$((current - 1))
        [ "$target" -lt 1 ] && exit 0
        ;;
    *)
        echo "usage: workspace-cycle.sh next|prev" >&2
        exit 1
        ;;
esac

swaymsg "workspace number $target"
