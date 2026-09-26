#!/usr/bin/env bash

# List of applications that don't track workspaces correctly (e.g., Electron apps)
APPS=("spotify" "discord" "obsidian" "code" "steam")
SRC="/usr/share/applications"
DEST="${DEST:-$HOME/.local/share/applications}"

mkdir -p "$DEST"

for app in "${APPS[@]}"; do
    if [[ -f "$SRC/$app.desktop" ]]; then
        cp "$SRC/$app.desktop" "$DEST/"
        
        # Check if the file was already patched to avoid double patching
        if ! grep -q "hyprctl dispatch" "$DEST/$app.desktop"; then
            echo "Patching $app.desktop..."
            
            # Set extra flags based on the app
            EXTRA_FLAGS=""
            if [[ "$app" == "steam" ]]; then
                EXTRA_FLAGS=" -silent"
            fi

            # Patch the Exec line once, incorporating extra flags if present
            # Using ',' as sed delimiter to avoid collision with '|'
            # Lua (Hyprland 0.56+): komenda w długim stringu [[...]] — bez problemów z cudzysłowami
            sed -i "s,^Exec=\(.*\),Exec=sh -c 'hyprctl dispatch \"hl.dsp.exec_cmd([[\1$EXTRA_FLAGS]]\, { workspace = tostring(\$(hyprctl activeworkspace -j | jq -r .id)) })\"'," "$DEST/$app.desktop"
            
        else
            echo "$app.desktop is already patched."
        fi
    fi
done
