#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/if-then-end/if.bar"
CONFIG_DIR="$HOME/.config/sketchybar"

echo ""
echo "=========================================="
echo "  if.bar - Installation"
echo "=========================================="
echo ""

if ! command -v brew &> /dev/null; then
    echo "[ERROR] Homebrew is not installed."
    echo ""
    echo "Please install Homebrew first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

echo "The following dependencies will be installed:"
echo ""
echo "  Required:"
echo "    - sketchybar"
echo "    - jq"
echo "    - pnpm"
echo "    - font-space-mono-nerd-font"
echo "    - sketchybar-app-font (from GitHub)"
echo ""
echo "  Optional:"
echo "    - yabai (window manager for workspace features)"
echo ""
read -p "Continue with installation? [Y/n]: " -n 1 -r REPLY < /dev/tty
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi
echo ""

echo "[1/6] Installing required packages..."
echo "----------------------------------------"
brew tap FelixKratz/formulae 2>&1 | grep -v "already tapped" || true
brew install sketchybar jq lua 2>&1 | grep -v "already installed" || true
brew install --cask font-space-mono-nerd-font 2>&1 | grep -v "already installed" || true

if [ ! -f "$HOME/.local/share/sketchybar_lua/sketchybar.so" ]; then
    echo "Installing SbarLua (Lua bindings for sketchybar)..."
    SBARLUA_TMP=$(mktemp -d)
    if git clone --depth 1 https://github.com/FelixKratz/SbarLua.git "$SBARLUA_TMP/SbarLua" > /dev/null 2>&1 \
        && make -C "$SBARLUA_TMP/SbarLua" install > /dev/null 2>&1; then
        echo "  Done"
    else
        echo "  Failed - the bar will not start without it."
        echo "  Install manually: https://github.com/FelixKratz/SbarLua"
    fi
    rm -rf "$SBARLUA_TMP"
fi
echo ""

echo "[2/6] Installing yabai (optional)..."
echo "----------------------------------------"
read -p "Install yabai? (enables workspace features) [y/N]: " -n 1 -r REPLY < /dev/tty
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    brew install koekeishiya/formulae/yabai
    brew services start yabai
fi
echo ""

echo "[3/6] Downloading configuration files..."
echo "----------------------------------------"
if [ -d "$CONFIG_DIR" ]; then
    BACKUP_DIR="${CONFIG_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backing up existing config: $BACKUP_DIR"
    mv "$CONFIG_DIR" "$BACKUP_DIR"
fi
git clone "$REPO_URL" "$CONFIG_DIR"
echo ""

echo "[4/6] Installing sketchybar-app-font..."
echo "----------------------------------------"
if ! command -v pnpm &> /dev/null; then
    echo "Installing pnpm..."
    brew install pnpm
fi

# The upstream build:install copies into a helpers/ directory this config does
# not have and reloads a bar that is not running yet, so it cannot be used here.
"$CONFIG_DIR/scripts/update-app-font.sh"
echo ""

echo "[5/6] Refreshing font cache..."
echo "----------------------------------------"
fc-cache -f -v > /dev/null 2>&1
echo "Done"
echo ""

echo "[6/6] Starting Sketchybar..."
echo "----------------------------------------"
brew services restart sketchybar
echo ""

echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Customization:"
echo "  cp $CONFIG_DIR/ifbarrc.example $CONFIG_DIR/ifbarrc"
echo "  Then edit ifbarrc - every setting is listed there."
echo ""
echo "Commands:"
echo "  - brew services start sketchybar    # Start"
echo "  - brew services restart sketchybar  # Restart"
echo "  - brew services stop sketchybar     # Stop"
echo "  - sketchybar --reload               # Reload config"
echo ""
echo "Documentation: $CONFIG_DIR/README.md"
echo ""
