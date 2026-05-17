#!/bin/bash
set -euo pipefail

echo "=== Fix 1: Bluetooth AutoEnable ==="
if grep -q '^AutoEnable=false' /etc/bluetooth/main.conf 2>/dev/null; then
  sudo sed -i 's/^AutoEnable=false/AutoEnable=true/' /etc/bluetooth/main.conf
  sudo systemctl restart bluetooth
  echo "  Bluetooth AutoEnable set to true, service restarted"
else
  echo "  Bluetooth already configured correctly"
fi

echo ""
echo "=== Fix 2: Snapper snapshots ==="

# Ensure @snapshots subvolume is in fstab
if ! grep -q '@snapshots' /etc/fstab 2>/dev/null; then
  UUID=$(findmnt / -o UUID -n)
  if [[ -n $UUID ]]; then
    echo "  Adding @snapshots to /etc/fstab"
    sudo bash -c "cat >> /etc/fstab << 'FSTAB'
UUID=$UUID /.snapshots btrfs rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@snapshots 0 0
FSTAB"
  fi
else
  echo "  fstab entry already exists"
fi

# Mount @snapshots if not mounted
if ! findmnt /.snapshots &>/dev/null; then
  echo "  Mounting /.snapshots"
  sudo mount /.snapshots
fi

# Create snapper config if missing
if ! sudo snapper list-configs 2>/dev/null | grep -q '^root'; then
  echo "  Creating snapper root config"
  sudo snapper -c root create-config /
fi

# Apply omarchy-style limits
echo "  Applying snapshot limits (5 max, no timeline)"
sudo snapper -c root set-config \
  NUMBER_LIMIT=5 \
  NUMBER_LIMIT_IMPORTANT=5 \
  TIMELINE_CREATE=no \
  SPACE_LIMIT=0 \
  FREE_LIMIT=0

# Disable BTRFS quotas (performance)
echo "  Disabling BTRFS quotas"
sudo btrfs quota disable / 2>/dev/null || true

# Set ROOT_SNAPSHOTS_PATH for limine-snapper-sync
if ! grep -q 'ROOT_SNAPSHOTS_PATH' /etc/default/limine 2>/dev/null; then
  echo "  Setting ROOT_SNAPSHOTS_PATH in /etc/default/limine"
  sudo sed -i '/^ESP_PATH/a ROOT_SNAPSHOTS_PATH="/@snapshots"' /etc/default/limine
fi

# Restart services
echo "  Restarting services"
sudo systemctl restart snapperd 2>/dev/null || true
sudo systemctl restart limine-snapper-sync 2>/dev/null || true

# Create a test snapshot
echo ""
echo "=== Creating test snapshot ==="
sudo snapper -c root create -c number -d "Post-fix verification"
echo "  Done! Snapshots:"
sudo snapper -c root list

echo ""
echo "=== All fixes applied ==="
