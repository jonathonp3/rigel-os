#!/bin/bash
# MIME-aware clipboard bridge - only syncs text, skips files

while true; do
    # Get the MIME type of the current clipboard content
    MIME=$(wl-paste --list-types 2>/dev/null | head -1)

    # Only sync if it's plain text
    if [[ "$MIME" == "text/plain"* ]]; then
        # Get the clipboard content
        CLIP=$(wl-paste 2>/dev/null || echo "")
        if [ -n "$CLIP" ]; then
            # Sync to X11 clipboard
            echo "$CLIP" | xclip -selection clipboard -in 2>/dev/null
        fi
    fi
    # If MIME is text/uri-list (files), do nothing

    sleep 0.5
done

