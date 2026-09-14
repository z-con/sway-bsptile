#!/usr/bin/env bash
# Keep sway's background in sync with GNOME's picture-uri (gsettings/dconf),
# so wallpaper changes made in a GNOME session (or via any GTK app under
# sway, e.g. nautilus "Set as Wallpaper") show up here too.
set -euo pipefail

LOCK_BG="$HOME/.cache/sway-bsptile/lock-bg.png"

apply() {
    local uri path
    uri=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")
    path=${uri#file://}
    [ -n "$path" ] && [ -f "$path" ] || return 0
    swaymsg output '*' bg "$path" fill
    make_lock_bg "$path"
}

# Pre-render a blurred, theme-tinted copy of the wallpaper for swaylock --
# swaylock has no built-in blur (that's a swaylock-effects-only feature), so
# this bakes the same look into a static image instead. Downscale-then-blur
# is much cheaper than blurring at full resolution and looks identical once
# it's re-upscaled and out of focus anyway. The colorize tints it toward the
# theme's #1c1c20 bg instead of plain black, for legible text without
# looking like an unrelated darkening filter was slapped on top.
make_lock_bg() {
    command -v convert >/dev/null 2>&1 || return 0
    mkdir -p "$(dirname "$LOCK_BG")"
    convert "$1" -resize 20% -blur 0x8 -resize 500% \
        -fill '#1c1c20' -colorize 35% "$LOCK_BG"
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
