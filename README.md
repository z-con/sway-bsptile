# sway-bsptile

Sway config built to feel like [bsptile](https://github.com/z-con/bsptile) (the
GNOME Shell tiling extension this machine also runs) and its macOS sibling
[bsptile-mac](https://github.com/z-con/bsptile-mac), plus a handful of
sway-native extras (live-synced GNOME wallpaper, a gesture-driven window
switcher with live thumbnails) that don't map back to either of those.

This repo is the source of truth for all of it. `install.sh` builds/installs
everything and deploys `config/` -> `~/.config/` and `sway-scripts/` ->
`~/.local/share/sway-scripts/`. The live files under `~/.config/` are just a
deployed copy -- edit them there day-to-day, then copy changes back into this
repo (there's no symlink/live-sync between the two).

```
~/projects/sway-bsptile/install.sh
```

Needs a real terminal (sudo, and multiple `apt install` passes + a from-source
build). Safe to re-run.

## What install.sh does

1. Installs build deps and every runtime tool this config touches: `waybar`,
   `wofi`, `autotiling`, `playerctl`, `mako-notifier`, `cliphist`, `nwg-bar`,
   `wl-clipboard`, `hyprlock`, `swayidle`, `wlsunset`, `grim`, `jq`, `wtype`,
   `brightnessctl`, the PyGObject/Gtk bindings the window switcher's
   thumbnail generation uses (`python3-gi`, `gir1.2-gtk-3.0`,
   `gir1.2-gdkpixbuf-2.0`), and `golang-go`/`libgtk-3-dev`/
   `libgtk-layer-shell-dev` to build nwg-dock (step 3 below). All via `apt`.
2. Builds **SwayFX** from source (0.6, based on sway 1.12) with **scenefx**
   0.5 and **wlroots** 0.20.2 as pinned meson subprojects, per SwayFX's own
   `INSTALL-deb.md`. SwayFX is a drop-in sway fork adding blur, rounded
   corners, and drop shadows -- vanilla sway has no equivalent, and without
   it `corner_radius`/`blur`/`layer_effects`/`animation_duration_ms` in the
   sway config are silently ignored. Installs to `/usr/local/bin/sway`,
   which should shadow the apt-packaged `/usr/bin/sway` on PATH (Ubuntu's
   default `PATH` puts `/usr/local/bin` first, and GDM's `sway.desktop` just
   runs bare `sway`).
3. Builds and installs **nwg-dock** from source (the macOS-style dock -- no
   apt package exists, and its own `Makefile` is the install path upstream
   documents). See "Sway-native extras" below.
4. Copies `config/` over `~/.config/` (sway, waybar, wofi, mako, nwg-bar,
   nwg-dock, hypr, and the `systemd/user/sway-session.target`/`waybar.service`
   units -- see "Known rough edges" below) and `sway-scripts/` into
   `~/.local/share/sway-scripts/`, `chmod +x`ing everything that needs it.
   Also copies `nautilus-scripts/` into `~/.local/share/nautilus/scripts/`
   (see "Known rough edges"), and installs `config/pam.d/hyprlock` to
   `/etc/pam.d/hyprlock` (needs root, so it's a separate `sudo install` step
   rather than part of the `~/.config` copy) -- this is what makes hyprlock's
   password check skip `pam_fprintd` in favor of its own native, parallel
   fingerprint support (see that file for why).
5. Downloads the Symbols Nerd Font (waybar's icon glyphs need it) into
   `~/.local/share/fonts/NerdFontsSymbols/` and runs `fc-cache`.
6. Creates `~/Pictures/Screenshots` (grim's target dir, see below).

`sway --version` should then print `swayfx version 0.6 ... (based on sway
1.12.0)`. If GDM still launches the old vanilla sway instead, the fallback is
editing `/usr/share/wayland-sessions/sway.desktop`'s `Exec=` line to the full
`/usr/local/bin/sway` path. Log out and back into the Sway session to pick
everything up.

## Feature mapping

| bsptile (GNOME)                                    | sway equivalent |
|-----------------------------------------------------|-----------------|
| Dynamic BSP/dwindle auto-tiling                      | sway's manual split tree + `autotiling` daemon picking split direction from container aspect ratio |
| 12px gaps, equal everywhere                          | `gaps inner 12` / `gaps outer 0` (sway's inner gap alone already produces 12px both between windows and at screen edges; `outer` stacks additively on top at edges only, so it has to be 0, not halved, to keep edges equal) |
| Thin accent-color focus border                       | `client.focused` border color (`#9d4edd`, same purple as bsptile-mac's JankyBorders) |
| 12px universal window corner radius (shader)         | SwayFX `corner_radius 12` |
| Blurred, tinted popup menus (Quick Settings, calendar)| SwayFX `layer_effects "wofi" { blur; corner_radius; }` -- wofi is the closest sway has to a shell popup |
| Translucent (0.6 opacity) top panel                  | waybar + `window#waybar { background-color: rgba(...,0.6); }` |
| Subtle open/close/switch animation                    | SwayFX `animation_duration_ms 150` -- one knob, covers window open/close, workspace-switch crossfade, and tiling-layout slide/resize together (no way to isolate just one) |
| `focus-mode=mouse` (focus-follows-cursor)             | `focus_follows_mouse yes` |
| Super+W closes focused window                        | `bindsym $mod+w kill` |
| Super+Space opens Activities Overview (Spotlight-like)| `bindsym $mod+space exec wofi --show drun` |
| Super+T pulls a window into/out of the tiled layout  | `bindsym $mod+t floating toggle` (sway's floating/tiling toggle covers both directions bsptile needed two keys for) |
| Per-monitor virtual workspaces (simulated in bsptile via minimize/unminimize) | Native: sway workspaces are already per-output. Assign them with `workspace N output <name>` in the config once you know your output names (`swaymsg -t get_outputs`) |
| Numbered workspace switch/move (Super+1-9,0 / Super+Shift+1-9,0) | Same bindings, sway's built-in `workspace number N` / `move container to workspace number N` |
| Three-finger swipe between workspaces                | `bindgesture swipe:3:left/right`, spawning a fresh empty workspace on-demand past the last existing one (`sway-scripts/workspace-cycle.sh`) |

## Sway-native extras (no bsptile equivalent)

- **nwg-dock** -- a macOS-style bottom dock (pinned/running-app icons +
  workspace switcher + launcher button), auto-hidden until the mouse hits
  the bottom edge (`-d`). It's Go + GTK3 + gtk-layer-shell, targets sway
  specifically (there's a separate `nwg-dock-hyprland` fork for Hyprland --
  not a drop-in for this repo), and has no apt package, so `install.sh`
  builds it from source into `$BUILD_DIR/nwg-dock` the same way it builds
  SwayFX. Styled to match waybar/wofi's dark/purple palette via
  `config/nwg-dock/style.css`.
- **GNOME wallpaper live-sync** -- `config/sway/scripts/sync-wallpaper.sh`
  (deployed to `~/.config/sway/scripts/`) adopts whatever GNOME's
  `picture-uri` gsettings key currently points at as sway's background, and
  watches (`gsettings monitor`) for live changes. Applies on every
  `sway reload` too, not just once at startup -- see the comment in the
  script for why that isn't automatic.
- **Mission-Control-ish window switcher** (`swipe:3:up`) --
  `sway-scripts/window-switcher.{sh,py}` lists every open window across all
  workspaces in wofi. Windows on your *current* workspace get a live
  thumbnail (grim crops that window's exact on-screen region, downscaled via
  GdkPixbuf); windows elsewhere fall back to their app icon, since
  sway/wlroots has no way to screenshot a window that isn't actually being
  composited. Selection round-trips through wofi's `print_line_num` output
  rather than parsing entry text back, so it's unaffected by wofi's own
  sorting/filtering.
- **Volume keys / waybar volume widget** -- both call `wpctl` (WirePlumber),
  not `pactl` -- this machine runs pipewire/wireplumber natively and never
  had `pulseaudio-utils` installed, so `pactl` doesn't exist here.
- **Screenshots** -- `Print` runs `grim` with `GRIM_DEFAULT_DIR` pointed at
  `~/Pictures/Screenshots` (grim's own fallback order is
  `$GRIM_DEFAULT_DIR` -> `$XDG_PICTURES_DIR` -> cwd).

## Deliberately not ported

- **Swap-on-drop** (drag one tiled window onto another to exchange places) --
  no sway primitive for drag-triggered swap; would need a custom IPC script,
  skipped as out of scope for a config-only pass.
- **Border-drag resize** -- already native to sway (`floating_modifier $mod
  normal`: `$mod`+right-drag resizes, works on tiled windows too), no porting
  needed.
- Ghostty's own opacity/blur (`~/.config/ghostty/config`, already at
  `background-opacity = 0.65`) was left as-is -- that's terminal-app config,
  not window-manager config, and already matches bsptile's terminal-opacity
  treatment.
- **True spatial exposé** (macOS Mission Control's exploded thumbnail grid)
  -- would mean writing a Wayland client against `wlr-screencopy`/
  `wlr-foreign-toplevel-management`, not a config tweak. The wofi-based
  window switcher above is the practical stand-in.

## Known rough edges

- **Nautilus's built-in "Set as Wallpaper" doesn't work under sway.** Since
  GTK4 Nautilus this action goes exclusively through the
  `org.freedesktop.impl.portal.Wallpaper` xdg-desktop-portal interface, no
  direct-gsettings fallback. Of the installed portal backends, only
  `xdg-desktop-portal-gnome` declares support for it (`xdg-desktop-portal-gtk`
  doesn't) -- and that backend refuses to actually implement it outside a
  real GNOME/Mutter session (`xdg-desktop-portal-gnome -v` prints
  "Non-compatible display server, exposing settings only" on this machine).
  So the portal call just times out and Nautilus silently does nothing.
  Confirmed by fixing `graphical-session.target` activation (see below,
  needed anyway for other systemd/D-Bus-gated user services) and forcing the
  Wallpaper interface to the gnome backend via a `sway-portals.conf` -- it
  still refused, for the reason above, so that override was reverted as
  dead weight (it only adds a timeout before the same failure). The fix
  instead is `nautilus-scripts/Set as Wallpaper`, deployed to
  `~/.local/share/nautilus/scripts/`: it sets `picture-uri`/`picture-uri-dark`
  directly, which `sync-wallpaper.sh`'s watcher already picks up. It shows up
  under right-click -> **Scripts -> Set as Wallpaper** instead of as a
  top-level context-menu item -- Nautilus doesn't offer a way to promote a
  script to the top level.
- **sway doesn't activate `graphical-session.target` on its own** the way
  gnome-session/ksmserver do for their sessions -- without it, any
  D-Bus-activated systemd user service gated behind it
  (`Requisite=graphical-session.target`, e.g. `xdg-desktop-portal-gnome`)
  can never start. Fixed by shipping `config/systemd/user/sway-session.target`
  (`BindsTo=graphical-session.target`) and having sway config run
  `dbus-update-activation-environment --systemd --all` +
  `systemctl --user start sway-session.target` on startup (`graphical-session.target`
  itself refuses direct manual start). This is generally-correct systemd
  session integration per the sway wiki, independent of the Wallpaper issue
  above, which it turned out not to fix.
- wofi's `drun` mode is an app launcher, not a true "workspace overview" --
  closest available primitive to GNOME's Activities Overview, but it won't
  show a spread of open windows the way Overview does (that's what the
  window switcher above is for instead).
- The window switcher's live thumbnails only cover the current workspace;
  anything elsewhere shows its app icon instead (see above -- this is a
  wlroots capture limitation, not a bug).
