#!/bin/bash

install_deps() {
  local missing=()

  for cmd in iw dhcpcd ip; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done

  if [ ${#missing[@]} -eq 0 ]; then
    return 0
  fi

  echo "Missing dependencies: ${missing[*]}"

  local pm=""
  local pkgs=()

  if command -v pacman &>/dev/null; then
    pm="pacman"
    for cmd in "${missing[@]}"; do
      case "$cmd" in
        iw) pkgs+=(iw) ;;
        dhcpcd) pkgs+=(dhcpcd) ;;
        ip) pkgs+=(iproute2) ;;
      esac
    done
  elif command -v apt &>/dev/null; then
    pm="apt"
    for cmd in "${missing[@]}"; do
      case "$cmd" in
        iw) pkgs+=(iw) ;;
        dhcpcd) pkgs+=(dhcpcd5) ;;
        ip) pkgs+=(iproute2) ;;
      esac
    done
  elif command -v dnf &>/dev/null; then
    pm="dnf"
    for cmd in "${missing[@]}"; do
      case "$cmd" in
        iw) pkgs+=(iw) ;;
        dhcpcd) pkgs+=(dhcpcd) ;;
        ip) pkgs+=(iproute2) ;;
      esac
    done
  elif command -v yum &>/dev/null; then
    pm="yum"
    for cmd in "${missing[@]}"; do
      case "$cmd" in
        iw) pkgs+=(iw) ;;
        dhcpcd) pkgs+=(dhcpcd) ;;
        ip) pkgs+=(iproute) ;;
      esac
    done
  elif command -v zypper &>/dev/null; then
    pm="zypper"
    for cmd in "${missing[@]}"; do
      case "$cmd" in
        iw) pkgs+=(iw) ;;
        dhcpcd) pkgs+=(dhcpcd) ;;
        ip) pkgs+=(iproute2) ;;
      esac
    done
  else
    echo "No supported package manager found."
    echo "Install manually: ${missing[*]}"
    exit 1
  fi

  case "$pm" in
    pacman) sudo pacman -S --noconfirm "${pkgs[@]}" ;;
    apt) sudo apt install -y "${pkgs[@]}" ;;
    dnf) sudo dnf install -y "${pkgs[@]}" ;;
    yum) sudo yum install -y "${pkgs[@]}" ;;
    zypper) sudo zypper install -y "${pkgs[@]}" ;;
  esac
}

install_deps

IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | while read iface; do
  iw dev "$iface" link 2>/dev/null | grep -q "Connected" && echo "$iface" && break
done)

if [ -z "$IFACE" ]; then
  echo "No connected WiFi interface found."
  exit 1
fi

echo "Active WiFi interface: $IFACE"

HAS_IPV4=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -v "127.0.0.1" | grep "inet " | grep -v "scope host")

if [ -n "$HAS_IPV4" ]; then
  echo "IPv4 already configured:"
  echo "$HAS_IPV4"
else
  echo "No IPv4 address, requesting via DHCP..."
  if pgrep -x dhcpcd >/dev/null; then
    sudo dhcpcd -4 "$IFACE" -t 30
  else
    sudo dhcpcd "$IFACE" -t 30
  fi
fi

echo "---"
ip -4 addr show "$IFACE" | grep "inet " | grep -v "127.0.0.1"
echo "IPv6:"
ip -6 addr show "$IFACE" | grep "inet6 " | grep -v "fe80::" | grep -v "scope link"
