#!/bin/bash
set -euo pipefail

KEYRING_PKG=$(ls /var/cache/pacman/pkg/omarchy-keyring-*.pkg.tar.zst 2>/dev/null | head -1)

if [ -z "$KEYRING_PKG" ]; then
  echo "Error: omarchy-keyring package not found in /var/cache/pacman/pkg/"
  echo "Run the Omarchy installer first so it downloads the package, then run this script."
  exit 1
fi

echo "Found: $KEYRING_PKG"

# Temporarily disable local-file signature checks
sudo sed -i 's/LocalFileSigLevel = Optional/LocalFileSigLevel = Never/' /etc/pacman.conf

# Install the keyring package
sudo pacman -Udd --noconfirm "$KEYRING_PKG"

# Restore signature checks
sudo sed -i 's/LocalFileSigLevel = Never/LocalFileSigLevel = Optional/' /etc/pacman.conf

echo ""
echo "Omarchy keyring installed. PGP key is now in your local keyring."
echo "You can re-run the Omarchy installer."
