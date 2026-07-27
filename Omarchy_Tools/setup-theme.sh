#!/bin/bash
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
THEME_NAME="my-wallpapers"
WALLPAPER_DIR="$HOME/Pictures/wallpapers/here"
THEME_DIR="$HOME/.config/omarchy/themes/$THEME_NAME"
MAX_WALLPAPERS=20  # limit for the background switcher menu (keep low or it stalls)

# ── Create theme directory ──────────────────────────────────────────
mkdir -p "$THEME_DIR/backgrounds"

# ── Color palette (cyberphunk) ─────────────────────────────────────
cat > "$THEME_DIR/colors.toml" << 'EOF'
accent = "#2BE3FC"
cursor = "#00f0ff"
foreground = "#c8c8e8"
background = "#15191F"
selection_foreground = "#080814"
selection_background = "#00f0ff"

color0 = "#15191F"
color1 = "#F865A5"
color2 = "#29EDBE"
color3 = "#FFC457"
color4 = "#33AEFF"
color5 = "#AF54FF"
color6 = "#2BE3FC"
color7 = "#c8c8e8"
color8 = "#61656B"
color9 = "#FF598B"
color10 = "#1FE0A6"
color11 = "#FFB630"
color12 = "#33AEFF"
color13 = "#B467F9"
color14 = "#2BCAFC"
color15 = "#e8e8ff"
EOF

# ── Symlink first N wallpapers into theme (for the menu carousel) ──
find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) | sort | head -n "$MAX_WALLPAPERS" | while read -r f; do
  ln -s "$f" "$THEME_DIR/backgrounds/"
done

# ── Apply the theme ────────────────────────────────────────────────
omarchy theme set "$THEME_NAME"

# ── Random wallpaper script (pulls from ALL wallpapers, not just the 20) ──
cat > "$HOME/random-wallpaper.sh" << 'SCRIPT'
#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/wallpapers/here"
random=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) | shuf -n 1)
omarchy-theme-bg-set "$random"
SCRIPT
chmod +x "$HOME/random-wallpaper.sh"

# ── Systemd timer: change wallpaper every 5 minutes ────────────────
mkdir -p "$HOME/.config/systemd/user"

cat > "$HOME/.config/systemd/user/random-wallpaper.service" << 'SERVICE'
[Unit]
Description=Random wallpaper

[Service]
Type=oneshot
ExecStart=%h/random-wallpaper.sh
SERVICE

cat > "$HOME/.config/systemd/user/random-wallpaper.timer" << 'TIMER'
[Unit]
Description=Random wallpaper every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=default.target
TIMER

systemctl --user daemon-reload
systemctl --user enable --now random-wallpaper.timer
