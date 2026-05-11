#!/bin/bash
cat packages.x86_64 | sudo pacman -S --needed -
sudo systemctl enable bluetooth --now

git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin || exit
makepkg -si
cd ... || exit
./reinstall_aur.sh
