#!/usr/bin/env python3
# Reads `swaymsg -t get_tree` JSON (once, cached to a temp file by the caller
# so both invocations below see an identical window list) and either:
#   list          -- prints one wofi image-entry line per window, in a fixed
#                     order ("img:<icon path>:text:[<workspace>] <title>")
#   id <line_num> -- prints the con_id for the Nth (0-indexed) window in that
#                     same order, matching wofi's `print_line_num` output
#
# Two passes over the same fixed order (rather than parsing wofi's raw text
# back) sidesteps ever having to know exactly how wofi's image-escape syntax
# interacts with selection output.
import os
import sys
import json
import subprocess
import warnings

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gio, Gtk, GdkPixbuf

warnings.filterwarnings("ignore", category=DeprecationWarning)

ICON_SIZE = 32
FALLBACK_ICON = "application-x-executable"
THUMB_WIDTH = 220  # live thumbnails are downscaled to this width


def capture_thumbnail(rect, dest_path):
    """Grab just this window's on-screen region and downscale it. Only
    works for windows on the currently-visible workspace -- sway/wlroots
    has no way to screenshot a window that isn't actually being
    composited, so this is never attempted for other workspaces."""
    geometry = f"{rect['x']},{rect['y']} {rect['width']}x{rect['height']}"
    raw_path = dest_path + ".raw.png"
    result = subprocess.run(
        ["grim", "-g", geometry, raw_path], capture_output=True
    )
    if result.returncode != 0:
        return None
    pixbuf = GdkPixbuf.Pixbuf.new_from_file(raw_path)
    scale = THUMB_WIDTH / pixbuf.get_width()
    thumb_height = max(1, round(pixbuf.get_height() * scale))
    scaled = pixbuf.scale_simple(
        THUMB_WIDTH, thumb_height, GdkPixbuf.InterpType.BILINEAR
    )
    scaled.savev(dest_path, "png", [], [])
    os.remove(raw_path)
    return dest_path


def resolve_icon(app_id):
    theme = Gtk.IconTheme.get_default()
    info = None
    try:
        info = Gio.DesktopAppInfo.new(f"{app_id}.desktop")
    except TypeError:
        pass
    if info is None:
        for candidate in Gio.AppInfo.get_all():
            if (
                isinstance(candidate, Gio.DesktopAppInfo)
                and candidate.get_startup_wm_class() == app_id
            ):
                info = candidate
                break
    gicon = info.get_icon() if info else None
    icon_info = (
        theme.lookup_by_gicon(gicon, ICON_SIZE, 0)
        if gicon
        else theme.lookup_icon(FALLBACK_ICON, ICON_SIZE, 0)
    )
    if icon_info is None:
        icon_info = theme.lookup_icon(FALLBACK_ICON, ICON_SIZE, 0)
    return icon_info.get_filename() if icon_info else None


def collect_windows(tree):
    found = []

    def walk(node, ws_name=None):
        if node.get("type") == "workspace":
            ws_name = node.get("name")
        if node.get("pid") is not None and node.get("type") in ("con", "floating_con"):
            title = node.get("name") or node.get("app_id") or "?"
            found.append(
                {
                    "id": node["id"],
                    "ws": ws_name,
                    "title": title,
                    "app_id": node.get("app_id"),
                    "rect": node.get("rect"),
                }
            )
        for child in node.get("nodes", []) + node.get("floating_nodes", []):
            walk(child, ws_name)

    walk(tree)
    return found


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "list"
    tree = json.load(sys.stdin)
    windows = collect_windows(tree)

    if mode == "list":
        current_ws = sys.argv[2] if len(sys.argv) > 2 else None
        thumb_dir = sys.argv[3] if len(sys.argv) > 3 else None
        for i, w in enumerate(windows):
            image = None
            if current_ws and w["ws"] == current_ws and thumb_dir and w["rect"]:
                image = capture_thumbnail(w["rect"], f"{thumb_dir}/{i}.png")
            if image is None:
                image = resolve_icon(w["app_id"]) if w["app_id"] else None
            label = f"[{w['ws']}] {w['title']}"
            if image:
                print(f"img:{image}:text:{label}")
            else:
                print(label)
    elif mode == "id":
        line_num = int(sys.argv[2])
        if 0 <= line_num < len(windows):
            print(windows[line_num]["id"])
    else:
        sys.exit(f"unknown mode: {mode}")


if __name__ == "__main__":
    main()
