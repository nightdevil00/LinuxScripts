#!/bin/bash
set -euo pipefail

echo "Making user '$USER' sudoless (NOPASSWD)..."

SUDOERS_FILE="/etc/sudoers.d/$USER-nopasswd"
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" >/dev/null
sudo chmod 440 "$SUDOERS_FILE"

echo "Done. Verify with: sudo -n true && echo 'works without password'"
