#!/bin/bash
# Simple clipboard bridge for Wayland → X11

set -euo pipefail

# Keep running forever
while true; do
    # Get the Wayland primary selection (selected text)
    PRIMARY=$(wl-paste --primary 2>/dev/null || echo "")
    
    # If there's text, copy it to X11 clipboard
    if [ -n "$PRIMARY" ]; then
        echo "$PRIMARY" | xclip -selection clipboard -in 2>/dev/null
    fi
    
    # Wait a moment before checking again
    sleep 0.5
done

