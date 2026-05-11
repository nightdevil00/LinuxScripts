#!/bin/bash
cat pacman_explicit_packages.txt | sudo pacman -S --needed -
sudo systemctl enable bluetooth --now
