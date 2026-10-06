#!/usr/bin/env bash

# List of applications that don't track workspaces correctly (e.g., Electron apps)
APPS=("spotify" "discord" "obsidian" "com.microsoft.VSCode" "steam")
SRC="/usr/share/applications"
DEST="${DEST:-$HOME/.local/share/applications}"
HELPER="$HOME/.config/hypr/scripts/exec-on-active-workspace.sh"

mkdir -p "$DEST"

for app in "${APPS[@]}"; do
    if [[ -f "$SRC/$app.desktop" ]]; then
        cp "$SRC/$app.desktop" "$DEST/"
        
        # Check if the file was already patched to avoid double patching
        if ! grep -q "$HELPER" "$DEST/$app.desktop"; then
            echo "Patching $app.desktop..."
            
            # Set extra flags based on the app
            EXTRA_FLAGS=""
            if [[ "$app" == "steam" ]]; then
                EXTRA_FLAGS=" -silent"
            fi

            # Patch the Exec line once, incorporating extra flags if present
            # Using ',' as sed delimiter to avoid collision with '|'
            # Plain Exec= with a helper (dispatch to the active workspace lives there): `sh -c '...'` is not
            # Desktop Entry syntax (only double quotes are) and the Ajmashell launcher split it (2026-10-06)
            sed -i "s,^Exec=\(.*\),Exec=$HELPER \1$EXTRA_FLAGS," "$DEST/$app.desktop"
            
        else
            echo "$app.desktop is already patched."
        fi
    fi
done
