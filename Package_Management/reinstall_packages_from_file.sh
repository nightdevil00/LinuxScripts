#!/bin/bash
cat packages.x86_64 | sudo pacman -S --needed -
sudo systemctl enable bluetooth --now
