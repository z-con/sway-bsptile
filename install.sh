#!/usr/bin/env bash
# Full setup for this machine's sway/SwayFX session: every package, the
# SwayFX and nwg-dock builds, all config files, companion scripts, and the
# Nerd Font the waybar icons need.
#
# Must be run in a real terminal (needs sudo). Safe to re-run: config/script
# deploy always overwrites with the repo's copy, and the SwayFX/nwg-dock
# builds always rebuild from a fresh clone.
set -euo pipefail

REPO="$HOME/projects/sway-bsptile"

echo "==> Installing build dependencies"
sudo apt update
sudo apt install -y \
    meson pkg-config cmake git scdoc \
    wayland-protocols libwayland-dev libpcre2-dev libjson-c-dev \
    libpango1.0-dev libcairo2-dev libgdk-pixbuf-2.0-dev \
    libdrm-dev libgbm-dev libinput-dev libseat-dev libxkbcommon-dev \
    libxcb-dri3-dev libxcb-present-dev libxcb-res0-dev \
    libxcb-render-util0-dev libxcb-ewmh-dev libxcb-icccm4-dev \
    libliftoff-dev libdisplay-info-dev liblcms2-dev libpixman-1-dev \
    libgles2-mesa-dev hwdata libudev-dev \
    golang-go libgtk-3-dev libgtk-layer-shell-dev

echo "==> Installing runtime tools"
sudo apt install -y \
    waybar wofi autotiling \
    playerctl mako-notifier cliphist nwg-bar wl-clipboard swaylock swayidle wlsunset \
    blueman \
    imagemagick \
    grim jq wtype brightnessctl unzip curl \
    python3-gi gir1.2-gtk-3.0 gir1.2-gdkpixbuf-2.0

BUILD_DIR="$REPO/build-src"
echo "==> Building SwayFX 0.6 (based on sway 1.12) into $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

git clone https://github.com/WillPower3309/swayfx.git
cd swayfx
git checkout 0.6

mkdir subprojects
cd subprojects

git clone https://github.com/wlrfx/scenefx.git
(cd scenefx && git checkout 0.5)

git clone https://gitlab.freedesktop.org/wlroots/wlroots.git
(cd wlroots && git checkout 0.20.2)

cd ..

meson setup build/
ninja -C build/
sudo ninja -C build/ install
sudo ldconfig

echo "==> Building nwg-dock (macOS-style dock for sway)"
rm -rf "$BUILD_DIR/nwg-dock"
git clone --depth 1 https://github.com/nwg-piotr/nwg-dock.git "$BUILD_DIR/nwg-dock"
(
    cd "$BUILD_DIR/nwg-dock"
    make get
    make build
    sudo make install
)

echo "==> Deploying config files"
mkdir -p "$HOME/.config"
cp -r "$REPO/config/." "$HOME/.config/"
chmod +x "$HOME/.config/sway/scripts/"*.sh
systemctl --user daemon-reload

echo "==> Deploying companion scripts"
mkdir -p "$HOME/.local/share/sway-scripts"
cp "$REPO/sway-scripts/"* "$HOME/.local/share/sway-scripts/"
chmod +x "$HOME/.local/share/sway-scripts/"*.sh "$HOME/.local/share/sway-scripts/"*.py

echo "==> Deploying Nautilus scripts (right-click -> Scripts)"
mkdir -p "$HOME/.local/share/nautilus/scripts"
cp "$REPO/nautilus-scripts/"* "$HOME/.local/share/nautilus/scripts/"
chmod +x "$HOME/.local/share/nautilus/scripts/"*

echo "==> Installing Symbols Nerd Font (for waybar icon glyphs)"
FONT_DIR="$HOME/.local/share/fonts/NerdFontsSymbols"
if [ ! -f "$FONT_DIR/SymbolsNerdFont-Regular.ttf" ]; then
    TMP_ZIP=$(mktemp --suffix=.zip)
    curl -fL -o "$TMP_ZIP" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip"
    mkdir -p "$FONT_DIR"
    unzip -o -j "$TMP_ZIP" "*.ttf" -d "$FONT_DIR"
    rm -f "$TMP_ZIP"
    fc-cache -f "$FONT_DIR"
fi

echo "==> Creating screenshot directory"
mkdir -p "$HOME/Pictures/Screenshots"

echo "==> Verifying"
sway --version || true
echo
echo "If that printed 'swayfx version 0.6 ... (based on sway 1.12.0)', it worked."
echo "It installs to /usr/local/bin/sway, which should shadow the apt-packaged"
echo "/usr/bin/sway as long as /usr/local/bin comes first in PATH (the Ubuntu"
echo "default). Log out and back into the sway session to pick it up."
