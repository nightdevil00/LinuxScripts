#!/bin/bash
set -euo pipefail

DESC="Setup limine-snapper snapshots (omarchy-style)"

# Only root, no timeline, 5 max
NUMBER_LIMIT=5
TIMELINE_CREATE="no"

# ── Preflight ──────────────────────────────────────────────────────────────
for cmd in limine snapper limine-snapper-sync; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd not found. Install with:"
    echo "  sudo pacman -S --needed snapper limine-snapper-sync limine-mkinitcpio-hook"
    exit 1
  fi
done

if [[ $(findmnt -n -o FSTYPE /) != "btrfs" ]]; then
  echo "ERROR: root filesystem is not btrfs"
  exit 1
fi

# ── Snapper config ─────────────────────────────────────────────────────────
if sudo snapper list-configs 2>/dev/null | grep -q "^root"; then
  echo "snapper config 'root' already exists, updating..."
else
  # May need to clear a pre-existing @snapshots subvolume
  if mountpoint -q /.snapshots 2>/dev/null; then
    if grep -qs "\.snapshots" /etc/fstab; then
      sudo sed -i '/.snapshots/d' /etc/fstab
    fi
    sudo umount /.snapshots
    sudo rmdir /.snapshots 2>/dev/null || true
  fi
  sudo snapper -c root create-config /
  echo "snapper config 'root' created"
fi

sudo tee /etc/snapper/configs/root >/dev/null <<EOF
# Omarchy-style: root only, kept to ${NUMBER_LIMIT}, no timeline
SUBVOLUME="/"
FSTYPE="btrfs"
NUMBER_LIMIT="${NUMBER_LIMIT}"
NUMBER_LIMIT_IMPORTANT="${NUMBER_LIMIT}"
TIMELINE_CREATE="${TIMELINE_CREATE}"
EOF

# ── Disable btrfs quotas (performance) ─────────────────────────────────────
sudo btrfs quota disable / 2>/dev/null || true

# ── Ensure /etc/default/limine has snapshot boot entries ───────────────────
for setting in 'BOOT_ORDER="*, *fallback, Snapshots"' 'MAX_SNAPSHOT_ENTRIES=5' 'SNAPSHOT_FORMAT_CHOICE=5'; do
  key="${setting%%=*}"
  if grep -q "^${key}=" /etc/default/limine 2>/dev/null; then
    sudo sed -i "s|^${key}=.*|${setting}|" /etc/default/limine
  else
    echo "${setting}" | sudo tee -a /etc/default/limine >/dev/null
  fi
done

# ── Enable service ─────────────────────────────────────────────────────────
sudo systemctl enable --now limine-snapper-sync.service

# ── Initial snapshot ───────────────────────────────────────────────────────
sudo snapper -c root create -d "initial-state"
sudo limine-snapper-sync

# ── Report ─────────────────────────────────────────────────────────────────
echo
echo "=== Done ==="
sudo snapper -c root list
echo
echo "Snapshot boot entries added to /boot/limine.conf"
echo "At boot, pick a snapshot from the Limine menu to roll back."
echo
echo "Create pre-update snapshots manually:"
echo "  sudo snapper -c root create -d \"before-update\""
