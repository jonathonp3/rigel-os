#!/bin/bash
# SPDX-License-Identifier: MIT
#
# wayland-spice-clipboard - Syncs the Wayland primary clipboard to the X11 clipboard
# for use with SPICE in KDE environments

set -euo pipefail

# Function to get the primary selection from Wayland
get_primary() {
    wl-paste --primary 2>/dev/null || echo ""
}

# Function to set the X11 clipboard
set_x11_clipboard() {
    local text="$1"
    if [ -n "$text" ]; then
        echo "$text" | xclip -selection clipboard -in 2>/dev/null
    fi
}

# Main loop - continuously sync Wayland primary to X11 clipboard
while true; do
    # Watch the Wayland primary selection for changes
    wl-paste --primary --watch 2>/dev/null | while read -r data; do
        if [ -n "$data" ]; then
            echo "$data" | xclip -selection clipboard -in 2>/dev/null
        fi
    done
    # Small sleep to prevent CPU spinning if something goes wrong
    sleep 1
done
