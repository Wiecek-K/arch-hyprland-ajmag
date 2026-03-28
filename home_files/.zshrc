# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="/usr/share/oh-my-zsh"
export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# Set name of the theme to load
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
	git 
	zsh-autosuggestions
	zsh-syntax-highlighting
)

# Plugin Edit
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=6'

source $ZSH/oh-my-zsh.sh

# User configuration
# export LANG=en_US.UTF-8

# Source .zprofile if it exists
[[ -f ~/.zprofile ]] && source ~/.zprofile

# pnpm
export PNPM_HOME="/home/ajmag/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# --- CUSTOM FUNCTIONS & ALIASES ---

# Function to run gedit in background and detach from terminal
gedit() {
    command gedit "$@" > /dev/null 2>&1 &|
}

# Alias to copy stdin to system clipboard (Wayland)
alias clip="wl-copy"

# ==========================================
# SYSTEM MAINTENANCE TOOLS (Arch/Hyprland)
# ==========================================

# 1. RAM Management
# Usage: my-fixram
function my-fixram() {
    echo "--- [RAM] Flushing buffers (PageCache, dentries, inodes) ---"
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
    echo "--- [RAM] Done. Memory cleared. ---"
}

# 2. Storage & System Cleanup (Pacman, Yay, Nautilus)
# Usage: my-sysclean
function my-sysclean() {
    echo "--- [1/5] Removing orphan packages ---"
    if pacman -Qtdq > /dev/null 2>&1; then
        sudo pacman -Rns $(pacman -Qtdq)
    else
        echo "No orphans found."
    fi

    echo "--- [2/5] Cleaning package cache ---"
    sudo rm -rf /var/cache/pacman/pkg/download-* 2>/dev/null
    yay -Sc

    echo "--- [3/5] Removing unused make-dependencies ---"
    yay -Yc

    echo "--- [4/5] Vacuuming system logs ---"
    sudo journalctl --vacuum-time=2weeks

    echo "--- [5/5] Clearing user cache ---"
    rm -rf ~/.cache/thumbnails/*
    rm -rf ~/.local/share/Trash/*

    echo "--- [SYS] System maintenance complete! ---"
}

# 3. Development Cleanup (Project post-mortem)
# Usage: my-devclean
function my-devclean() {
    echo "--- [DEV] Cleaning NPM cache ---"
    npm cache clean --force

    echo "--- [DEV] Purging PIP (Python) cache ---"
    pip cache purge

    echo "--- [DEV] Pruning Docker (stopped containers, unused networks, dangling images) ---"
    docker system prune

    echo "--- [DEV] Cleanup finished. ---"
}

get-folder-context() {
  local target_path=$1

  if [ -z "$target_path" ]; then
    echo "❌ Error: Please provide a relative path."
    return 1
  fi

  if [ ! -d "$target_path" ]; then
    echo "❌ Error: Directory '$target_path' does not exist."
    return 1
  fi

  (
    echo "--- START OF DIRECTORY CONTEXT: $target_path ---"
    echo "--- DIRECTORY STRUCTURE ---"
    tree -L 6 "$target_path" --gitignore
    echo -e "\n"

    find "$target_path" -type f | while read -r file; do
      echo "--- FILE: $file ---"
      cat "$file"
      echo -e "\n"
    done
    echo "--- END OF DIRECTORY CONTEXT ---"
  ) | wl-copy

  echo "✅ Context for '$target_path' copied to clipboard!"
}

# --- NVM (Node Version Manager) ---
# Zakomentowane dla szybkosci startu terminala.
# Odkomentuj tylko jesli potrzebujesz zmieniac wersje Node.js
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# --- SPICETIFY FIX ---
# One command to fix Spotify after an update
my-fix-spicetify() {
    echo "🔧 Fixing permissions for Spotify folder..."
    sudo chmod a+wr /opt/spotify
    sudo chmod a+wr /opt/spotify/Apps -R
    
    echo "🎨 Applying Spicetify theme..."
    spicetify backup apply
    
    echo "✅ Done! If Spotify is running, please restart it."
}
