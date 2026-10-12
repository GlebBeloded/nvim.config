#!/usr/bin/env bash
# Move Alacritty's app-menu Quit and Hide off Cmd+Q / Cmd+H so those keys reach the terminal.
# Usage: macos_menu_keys.sh [domain]   (default org.alacritty; tests pass a plist path)
set -euo pipefail

domain="${1:-org.alacritty}"

defaults write "$domain" NSUserKeyEquivalents -dict-add \
	"Quit alacritty" "@~^q" \
	"Hide alacritty" "@~^h"

echo "Menu keys set in $domain: Quit = Cmd+Option+Control+Q, Hide = Cmd+Option+Control+H."
echo "Quit and relaunch Alacritty for them to take effect."
