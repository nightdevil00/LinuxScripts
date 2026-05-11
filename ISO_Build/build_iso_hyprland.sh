#!/usr/bin/env bash
# ==============================================================================
# Custom Arch ISO Builder - Hyprland Live Environment
# Packages: fuzzel, nautilus, chromium, kitty, hyprland, gedit,
#           gnome-disk-utility, waybar
# User: live / Password: live (autologin via SDDM)
# ==============================================================================

set -euo pipefail

C_BLUE="\e[34m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_RESET="\e[0m"
info() { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
success() { echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2; exit 1; }
warn() { echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"; }

[[ $EUID -eq 0 ]] || error "This script must be run as root"

WORK_DIR="$(pwd)/archiso-work"
PROFILE_DIR="$WORK_DIR/releng"
OUT_DIR="$(pwd)/out"
AIROOTFS="$PROFILE_DIR/airootfs"

mkdir -p "$WORK_DIR" "$OUT_DIR"
[[ -d "$PROFILE_DIR" ]] && rm -rf "$PROFILE_DIR"

# ==============================================================================
# Copy base archiso profile
# ==============================================================================
info "Copying archiso releng profile..."
cp -r /usr/share/archiso/configs/releng "$WORK_DIR/"
chmod u+w "$PROFILE_DIR/profiledef.sh"

# ==============================================================================
# Package list
# ==============================================================================
info "Configuring package list..."
cat >> "$PROFILE_DIR/packages.x86_64" <<'PKGEOF'

# Display Manager
sddm
qt5-wayland
qt6-wayland

# Wayland Compositor
hyprland
xdg-desktop-portal-hyprland

# Essential Wayland
wayland
wayland-protocols
xorg-xwayland

# Terminal
kitty

# Application Launcher
fuzzel

# File Manager
nautilus
gnome-themes-extra

# Browser
chromium

# Text Editor
gedit

# Disk Utility
gnome-disk-utility

# Status Bar
waybar

# Audio
pipewire
pipewire-alsa
pipewire-pulse
wireplumber
pavucontrol

# Network
networkmanager
network-manager-applet

# Fonts
noto-fonts
noto-fonts-emoji
ttf-dejavu
ttf-liberation

# Tools
bash-completion
git
curl
wget
vim
nano
htop
btop
polkit-gnome
gnome-keyring
libnotify

PKGEOF

# ==============================================================================
# Airootfs structure
# ==============================================================================
info "Setting up airootfs..."
mkdir -p "$AIROOTFS/etc/skel/.config"/{hypr,kitty,fuzzel}
mkdir -p "$AIROOTFS/etc/sddm.conf.d"
mkdir -p "$AIROOTFS/etc/systemd/system"
mkdir -p "$AIROOTFS/root"

# ==============================================================================
# Enable services
# ==============================================================================
info "Enabling services..."
mkdir -p "$AIROOTFS/etc/systemd/system/multi-user.target.wants"
mkdir -p "$AIROOTFS/etc/systemd/system/graphical.target.wants"

ln -sf /usr/lib/systemd/system/sddm.service \
    "$AIROOTFS/etc/systemd/system/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/graphical.target \
    "$AIROOTFS/etc/systemd/system/default.target"

# ==============================================================================
# SDDM autologin
# ==============================================================================
info "Configuring SDDM autologin..."
cat > "$AIROOTFS/etc/sddm.conf.d/autologin.conf" <<'SDDMEOF'
[Autologin]
User=live
Session=hyprland

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Theme]
Current=breeze
SDDMEOF

# ==============================================================================
# Hyprland config
# ==============================================================================
info "Creating Hyprland config..."
cat > "$AIROOTFS/etc/skel/.config/hypr/hyprland.conf" <<'HYPRLANDEOF'
monitor=,preferred,auto,1

env = XDG_SESSION_TYPE,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_DESKTOP,Hyprland

input {
    kb_layout = us
    follow_mouse = 1
    touchpad { natural_scroll = true }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

$mainMod = SUPER
bind = $mainMod, SPACE, exec, fuzzel
bind = $mainMod, RETURN, exec, kitty
bind = $mainMod, F, exec, nautilus
bind = $mainMod, B, exec, chromium
bind = $mainMod, D, exec, gnome-disks
bind = $mainMod, Q, killactive
bind = $mainMod SHIFT, Q, exit
bind = $mainMod, V, togglefloating

bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = nm-applet --indicator
exec-once = waybar &
HYPRLANDEOF

# ==============================================================================
# Kitty config
# ==============================================================================
cat > "$AIROOTFS/etc/skel/.config/kitty/kitty.conf" <<'KITTYEOF'
font_size 12.0
background_opacity 0.9
KITTYEOF

# ==============================================================================
# Fuzzel config
# ==============================================================================
cat > "$AIROOTFS/etc/skel/.config/fuzzel/fuzzel.ini" <<'FUZZELEOF'
[main]
terminal=kitty
layer=overlay
width=50

[colors]
background=1e1e2edd
text=cdd6f4ff
match=89b4faff
selection=313244ff
selection-text=cdd6f4ff
border=89b4faff

[border]
width=2
radius=8
FUZZELEOF

# ==============================================================================
# User setup script (runs during build in airootfs chroot)
# ==============================================================================
info "Creating user setup script..."
cat > "$AIROOTFS/root/customize_airootfs.sh" <<'CUSTOMIZE_SCRIPT'
#!/usr/bin/env bash
set -e

echo "==> Creating live user..."

if ! id live &>/dev/null 2>&1; then
    useradd -m -u 1000 -G wheel,audio,video,network,storage -s /bin/bash live
    echo 'live:live' | chpasswd
fi

echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

cp -r /etc/skel/. /home/live/ 2>/dev/null || true
chown -R live:live /home/live

cat > /home/live/.bashrc <<'BASHRC_EOF'
[[ $- == *i* ]] && echo "Welcome to Hyprland Live ISO | User: live | Password: live"
[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion
alias ll='ls -la'
BASHRC_EOF

chown live:live /home/live/.bashrc
echo "==> User setup complete"
CUSTOMIZE_SCRIPT
chmod +x "$AIROOTFS/root/customize_airootfs.sh"

# ==============================================================================
# Copy arch-install script into ISO
# ==============================================================================
info "Copying install script into ISO..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/../Arch_Install/arch_install.sh" ]]; then
    cp "$SCRIPT_DIR/../Arch_Install/arch_install.sh" "$AIROOTFS/etc/skel/"
else
    warn "arch_install.sh not found at $SCRIPT_DIR/../Arch_Install/arch_install.sh"
    warn "ISO will build without the install script (add it later to /etc/skel/)"
fi

# ==============================================================================
# Modify profiledef.sh to call our setup
# ==============================================================================
cat >> "$PROFILE_DIR/profiledef.sh" <<'PROFILEDEF_EOF'

file_permissions+=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/etc/skel/arch_install.sh"]="0:0:755"
)

customize_airootfs() {
    if [ -f "${airootfs_dir}/root/customize_airootfs.sh" ]; then
        arch-chroot "${airootfs_dir}" /root/customize_airootfs.sh
    fi
}
PROFILEDEF_EOF

# ==============================================================================
# Ask about offline installation packages
# ==============================================================================
echo ""
info "Include offline installation packages in the ISO?"
echo "This downloads base + Hyprland packages for installing without internet."
echo "Estimated extra size: ~2-3GB"
echo ""
echo "1) Yes - include offline packages"
echo "2) No - live environment only (smaller ISO)"
echo ""
read -rp "Choice [1-2]: " offline_choice

if [[ "$offline_choice" == "1" ]]; then
    info "Downloading packages for offline installation..."
    TMP_DL_DIR="/tmp/offline-pkgs-$$"
    OFFLINE_DIR="$AIROOTFS/opt/offline-pkgs"
    mkdir -p "$TMP_DL_DIR" "$OFFLINE_DIR"

    if ! pacman -Sw --cachedir "$TMP_DL_DIR" --noconfirm \
        base base-devel linux linux-firmware linux-headers \
        btrfs-progs cryptsetup efibootmgr grub limine \
        networkmanager sudo vim man-db man-pages \
        amd-ucode intel-ucode \
        pipewire pipewire-alsa pipewire-pulse wireplumber \
        hyprland xdg-desktop-portal-hyprland waybar kitty fuzzel \
        nautilus chromium gedit gnome-disk-utility \
        noto-fonts ttf-dejavu bash-completion git curl wget; then
        warn "Some packages failed to download. Continuing with what we have."
    fi

    cp "$TMP_DL_DIR"/*.pkg.tar.zst "$OFFLINE_DIR/" 2>/dev/null || true
    rm -rf "$TMP_DL_DIR"

    repo-add "$OFFLINE_DIR/offline.db.tar.gz" "$OFFLINE_DIR"/*.pkg.tar.zst 2>/dev/null || true

    cat > "$AIROOTFS/etc/pacman.d/offline-mirrorlist" <<'REPOEOF'
# Offline package repository (from ISO)
Server = file:///opt/offline-pkgs
REPOEOF

    success "Offline packages: $(du -sh "$OFFLINE_DIR" | cut -f1)"
fi

# ==============================================================================
# Build ISO
# ==============================================================================
info "Starting mkarchiso build. This may take 15-30 minutes..."
cd "$WORK_DIR"
[[ -d "$PROFILE_DIR/work" ]] && rm -rf "$PROFILE_DIR/work"

mkarchiso -v -w "$PROFILE_DIR/work" -o "$OUT_DIR" "$PROFILE_DIR"

ISO_FILE=$(find "$OUT_DIR" -name "*.iso" -type f | sort | tail -1)

if [[ -n "$ISO_FILE" ]]; then
    success "ISO built successfully!"
    echo "Location: $ISO_FILE"
    echo "Size: $(du -h "$ISO_FILE" | cut -f1)"
    echo ""
    echo "Write to USB:"
    echo "  dd if=\"$ISO_FILE\" of=/dev/sdX bs=4M status=progress && sync"
    echo ""
    echo "Test with QEMU:"
    echo "  qemu-system-x86_64 -enable-kvm -m 4G -cdrom \"$ISO_FILE\""
else
    error "ISO file not found in $OUT_DIR"
fi
