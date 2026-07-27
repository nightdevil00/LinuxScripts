#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/wallpapers/here"
random=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) | shuf -n 1)
omarchy-theme-bg-set "$random"

