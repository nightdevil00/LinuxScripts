#!/bin/bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$CONFIG_DIR"

if command -v xdg-user-dirs-update &>/dev/null; then
    LANG=C xdg-user-dirs-update
    echo "Directories created via xdg-user-dirs-update"
else
    DIRS=(Desktop Downloads Templates Public Documents Music Pictures Videos Projects)
    for dir in "${DIRS[@]}"; do
        mkdir -p "$HOME/$dir"
    done

    cat > "$CONFIG_DIR/user-dirs.dirs" <<'EOF'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
XDG_PROJECTS_DIR="$HOME/Projects"
EOF
    echo "Directories created manually"
fi

BOOKMARKS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0"
mkdir -p "$BOOKMARKS_DIR"
BOOKMARKS_FILE="$BOOKMARKS_DIR/bookmarks"
for dir in Downloads Projects; do
    entry="file://$HOME/$dir"
    grep -qxF "$entry" "$BOOKMARKS_FILE" 2>/dev/null || echo "$entry" >> "$BOOKMARKS_FILE"
done

echo "Done. Restart Nautilus: nautilus -q"
