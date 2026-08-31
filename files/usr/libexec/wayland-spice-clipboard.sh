#!/bin/bash
# Smart clipboard bridge - only syncs text, not files

while true; do
    # Get the MIME type of the current clipboard
    MIME=$(wl-paste --list-types 2>/dev/null | head -1)
    
    # Only sync if it's plain text and NOT a file list
    if [[ "$MIME" == "text/plain" ]]; then
        PRIMARY=$(wl-paste --primary 2>/dev/null || echo "")
        if [ -n "$PRIMARY" ]; then
            echo "$PRIMARY" | xclip -selection clipboard -in 2>/dev/null
            echo "Synced text: $PRIMARY"  # Debug output
        fi
    fi
    # For text/uri-list (files), do nothing - let Dolphin handle it
    
    sleep 0.5
done


