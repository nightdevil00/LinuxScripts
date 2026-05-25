#!/bin/bash
set -euo pipefail

COUNTRIES="Romania,Bulgaria,Hungary,Serbia,Ukraine,Moldova,Greece"

if ! command -v reflector &>/dev/null; then
    echo "Installing reflector..."
    sudo pacman -S --noconfirm reflector
fi

echo "Writing reflector config..."
sudo tee /etc/xdg/reflector/reflector.conf > /dev/null << EOF
--save /etc/pacman.d/mirrorlist
--protocol https
--country $COUNTRIES
--latest 20
--sort rate
EOF

echo "Running reflector..."
sudo reflector --country "$COUNTRIES" \
    --age 12 \
    --protocol https \
    --sort rate \
    --save /etc/pacman.d/mirrorlist

echo "Enabling weekly reflector timer..."
sudo systemctl enable --now reflector.timer

echo "Done! $(grep -c '^Server' /etc/pacman.d/mirrorlist) mirrors saved."
