#!/bin/bash
set -euo pipefail

# ── 1. Set DNS to Google ───────────────────────────────────────────────────
echo "[1/3] Setting DNS to Google..."
if command -v resolvectl &>/dev/null; then
  # systemd-resolved: set global DNS
  sudo resolvectl dns global 8.8.8.8 8.8.4.4
  sudo resolvectl domain global "~."
  # Make it persistent
  sudo mkdir -p /etc/systemd/resolved.conf.d
  sudo tee /etc/systemd/resolved.conf.d/dns.conf >/dev/null <<'EOF'
[Resolve]
DNS=8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
Domains=~.
EOF
  echo "  DNS set via systemd-resolved"
elif command -v nmcli &>/dev/null; then
  # NetworkManager
  for conn in $(nmcli -t -f NAME con show --active 2>/dev/null); do
    sudo nmcli con mod "$conn" ipv4.dns "8.8.8.8 8.8.4.4"
    sudo nmcli con mod "$conn" ipv4.ignore-auto-dns yes
  done
  echo "  DNS set via NetworkManager"
else
  # Fallback: /etc/resolv.conf
  echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
  echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
  echo "  DNS set via /etc/resolv.conf"
fi

# ── 2. Enable Bluetooth by default ─────────────────────────────────────────
echo "[2/3] Enabling Bluetooth..."
sudo systemctl enable --now bluetooth.service
# Ensure the BT adapter is powered on at boot
sudo tee /etc/systemd/system/bluetooth-auto-poweron.service >/dev/null <<'EOF'
[Unit]
Description=Power on Bluetooth adapter at boot
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/bluetoothctl power on
RemainAfterExit=yes

[Install]
WantedBy=bluetooth.target
EOF
sudo systemctl enable --now bluetooth-auto-poweron.service
echo "  Bluetooth enabled and auto-powered"

# ── 3. WiFi watchdog service ───────────────────────────────────────────────
echo "[3/3] Creating WiFi watchdog..."
sudo tee /usr/local/bin/wifi-watchdog.sh >/dev/null <<'WIFISCRIPT'
#!/bin/bash
# WiFi watchdog — ensures connectivity after boot
# Pings Google, bounces iwd+dhcpcd if needed
# Logs to journal: journalctl -u wifi-watchdog

TARGET="8.8.8.8"
RETRIES=6
SLEEP=10

# Wait for interface to exist
for i in $(seq 1 15); do
  if iw dev wlan0 info &>/dev/null; then
    break
  fi
  sleep 1
done

# Retry loop
for i in $(seq 1 $RETRIES); do
  if ping -c1 -W5 "$TARGET" &>/dev/null; then
    echo "WiFi OK (attempt $i)"
    exit 0
  fi
  echo "WiFi down (attempt $i/$RETRIES), restarting iwd+dhcpcd..."
  systemctl restart iwd dhcpcd
  sleep "$SLEEP"
done

if ping -c1 -W5 "$TARGET" &>/dev/null; then
  echo "WiFi reconnected successfully"
  exit 0
else
  echo "WiFi watchdog failed after $RETRIES retries"
  exit 1
fi
WIFISCRIPT
sudo chmod +x /usr/local/bin/wifi-watchdog.sh

sudo tee /etc/systemd/system/wifi-watchdog.service >/dev/null <<'EOF'
[Unit]
Description=WiFi connectivity watchdog (iwd)
After=network.target iwd.service
Wants=iwd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wifi-watchdog.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wifi-watchdog.service

echo "  WiFi watchdog installed (runs once at boot)"

# ── Summary ────────────────────────────────────────────────────────────────
echo
echo "=== Done ==="
echo "  DNS:       Google 8.8.8.8 / 8.8.4.4"
echo "  Bluetooth: enabled + auto-power on"
echo "  WiFi:      wifi-watchdog.service will reconnect on boot"
echo
echo "Check WiFi watchdog logs: journalctl -u wifi-watchdog -b"
echo "Run it now:              sudo systemctl start wifi-watchdog"
