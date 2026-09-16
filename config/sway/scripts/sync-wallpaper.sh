#!/usr/bin/env bash
# Keep sway's background in sync with GNOME's picture-uri (gsettings/dconf),
# so wallpaper changes made in a GNOME session (or via any GTK app under
# sway, e.g. nautilus "Set as Wallpaper") show up here too.
set -euo pipefail

apply() {
    local uri path
    uri=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")
    path=${uri#file://}
    [ -n "$path" ] && [ -f "$path" ] || return 0
    swaymsg output '*' bg "$path" fill
}

case "${1:-apply}" in
    apply)
        apply
        ;;
    watch)
        # Apply unconditionally on every invocation (every `sway reload` runs
        # this): config's static fallback `output * bg` line re-fires on
        # reload too, so without this the wallpaper would flip back to it
        # whenever a reload lands after the first one, since the flock below
        # only lets the *first* invocation's monitor loop survive.
        apply
        # flock keeps repeated `swaymsg reload`s from stacking up watchers.
        exec flock -n /tmp/sway-wallpaper-sync.lock -c '
            gsettings monitor org.gnome.desktop.background picture-uri |
            while read -r _; do "'"$0"'" apply; done
        '
        ;;
esac
