#!/usr/bin/env bash
# ==============================================================================
# Arch Linux Installer
# Modes: 1) Online Install  2) Offline Install (from ISO)  3) Repair System
# Dualboot: Auto-detects Windows, supports dualboot or full wipe
# Bootloaders: GRUB, Limine
# Desktops: niri, hyprland, gnome, plasma
# Filesystems: btrfs (with/without encryption), ext4
# ==============================================================================

set -uo pipefail

# Colors
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; N='\033[0m'
info() { echo -e "${B}[INFO]${N} $1"; }
ok()  { echo -e "${G}[OK]${N} $1"; }
warn(){ echo -e "${Y}[WARN]${N} $1"; }
err() { echo -e "${R}[ERROR]${N} $1" >&2; }

[[ $EUID -ne 0 ]] && err "Run as root" && exit 1

LOG_FILE="/home/live/arch-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""; info "Log file: $LOG_FILE"; echo ""

cleanup() {
    umount -R /mnt 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true
}
trap cleanup EXIT

# ==============================================================================
# Helper functions
# ==============================================================================
part_name() {
    local d=$1 n=$2
    if [[ "$d" =~ nvme ]] || [[ "$d" =~ mmcblk ]]; then
        echo "${d}p${n}"
    else
        echo "${d}${n}"
    fi
}

detect_microcode() {
    if grep -q "GenuineIntel" /proc/cpuinfo 2>/dev/null; then echo "intel-ucode"
    elif grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then echo "amd-ucode"
    else echo ""; fi
}

detect_timezone() {
    local tz=""
    if ping -c 1 -W 1 archlinux.org &>/dev/null || ping -c 1 -W 1 google.com &>/dev/null; then
        tz=$(curl -s --max-time 3 https://ipapi.co/timezone 2>/dev/null || echo "")
    fi
    echo "${tz:-UTC}"
}

select_disk() {
    clear
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v loop | grep -v rom
    echo ""
    while true; do
        read -rp "Enter disk (e.g. /dev/nvme0n1, /dev/sda): " DISK
        [[ -b "$DISK" ]] && break
        err "Disk not found: $DISK"
    done
}

select_de() {
    clear
    echo "Select Desktop Environment:"
    echo "1) GNOME"
    echo "2) KDE Plasma"
    echo "3) Hyprland"
    echo "4) Niri"
    echo "5) None (minimal)"
    read -rp "Choice [1-5]: " de_choice
    case "$de_choice" in
        1) DE="gnome"; DM_PKG="gdm" ;;
        2) DE="plasma"; DM_PKG="sddm" ;;
        3) DE="hyprland"; DM_PKG="sddm" ;;
        4) DE="niri"; DM_PKG="sddm" ;;
        5) DE="none"; DM_PKG="" ;;
        *) DE="none"; DM_PKG="" ;;
    esac
}

select_bootloader() {
    clear
    echo "Select Bootloader:"
    echo "1) GRUB"
    echo "2) Limine"
    read -rp "Choice [1-2]: " bl_choice
    case "$bl_choice" in
        1) BOOTLOADER="grub" ;;
        2) BOOTLOADER="limine" ;;
        *) BOOTLOADER="grub" ;;
    esac
}

select_filesystem() {
    clear
    echo "Select Root Filesystem:"
    echo "1) ext4"
    echo "2) btrfs"
    read -rp "Choice [1-2]: " fs_choice
    case "$fs_choice" in
        1) FSTYPE="ext4" ;;
        2) FSTYPE="btrfs" ;;
        *) FSTYPE="btrfs" ;;
    esac
}

ask_encryption() {
    read -rp "Enable LUKS encryption? (y/N): " enc
    [[ "$enc" =~ ^[Yy]$ ]] && ENCRYPT=true || ENCRYPT=false
}

get_user_info() {
    clear
    read -rp "Hostname [arch]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-arch}
    read -rp "Username: " USERNAME
    while true; do
        read -rsp "User password: " USER_PASS; echo
        read -rsp "Confirm password: " USER_PASS2; echo
        [[ "$USER_PASS" == "$USER_PASS2" && -n "$USER_PASS" ]] && break
        err "Passwords don't match or empty"
    done
    while true; do
        read -rsp "Root password: " ROOT_PASS; echo
        read -rsp "Confirm root password: " ROOT_PASS2; echo
        [[ "$ROOT_PASS" == "$ROOT_PASS2" && -n "$ROOT_PASS" ]] && break
        err "Passwords don't match or empty"
    done
}

confirm_install() {
    clear
    echo "========== Installation Summary =========="
    echo "Install type: $INSTALL_TYPE"
    echo "Disk:         $DISK"
    echo "Filesystem:   $FSTYPE"
    echo "Encryption:   $ENCRYPT"
    echo "Desktop:      $DE"
    echo "Bootloader:   $BOOTLOADER"
    echo "Hostname:     $HOSTNAME"
    echo "Username:     $USERNAME"
    echo ""
    if [[ "$INSTALL_TYPE" == "dualboot" ]]; then
        warn "This will install Arch alongside Windows (uses free space)"
    else
        warn "This will WIPE the entire disk!"
    fi
    read -rp "Proceed? (yes/NO): " confirm
    if [[ "$confirm" != "yes" ]]; then
        err "Aborted"
        exit 1
    fi
}

# ==============================================================================
# Windows detection
# ==============================================================================
detect_windows() {
    INSTALL_TYPE="fullwipe"
    EXISTING_EFI=""
    WINDOWS_DETECTED=false

    info "Checking for Windows installation on $DISK..."
    local tmp_mount
    tmp_mount=$(mktemp -d)

    while IFS= read -r part; do
        [[ ! -b "$part" ]] && continue
        local ft
        ft=$(blkid -s TYPE -o value "$part" 2>/dev/null || echo "")

        if [[ "$ft" =~ ^(vfat|fat32)$ ]]; then
            if mount -o ro "$part" "$tmp_mount" 2>/dev/null; then
                if [[ -d "$tmp_mount/EFI/Microsoft" ]]; then
                    WINDOWS_DETECTED=true
                    ok "Windows EFI found: $part"
                fi
                umount "$tmp_mount"
            fi
        fi

        if [[ "$ft" == "ntfs" ]]; then
            if mount -o ro "$part" "$tmp_mount" 2>/dev/null; then
                if [[ -d "$tmp_mount/Windows" ]]; then
                    WINDOWS_DETECTED=true
                    ok "Windows system found: $part"
                fi
                umount "$tmp_mount"
            fi
        fi
    done < <(lsblk -npo NAME "$DISK" 2>/dev/null | tail -n +2 || true)

    rmdir "$tmp_mount" 2>/dev/null || true

    if [[ "$WINDOWS_DETECTED" == false ]]; then
        info "No Windows installation detected"
    fi
}

select_install_type() {
    clear
    echo "Windows installation detected on $DISK!"
    echo "1) Install alongside Windows (dualboot)"
    echo "2) Wipe entire disk (destroys Windows)"
    echo ""
    read -rp "Choice [1-2]: " inst_choice

    case "$inst_choice" in
        2)
            warn "This will destroy all data including Windows!"
            read -rp "Type 'YES' to confirm: " confirm
            if [[ "$confirm" == "YES" ]]; then
                INSTALL_TYPE="fullwipe"
                info "Full wipe selected"
            else
                info "Defaulting to dualboot"
                INSTALL_TYPE="dualboot"
            fi
            ;;
        *)
            INSTALL_TYPE="dualboot"
            info "Dualboot selected"
            ;;
    esac

    if [[ "$INSTALL_TYPE" == "dualboot" ]]; then
        info "New EFI (+1GB) and ROOT partitions will be created in free space"
        info "Existing Windows partitions will NOT be touched"
    fi
}

# ==============================================================================
# Partitioning
# ==============================================================================
partition_disk() {
    if [[ "$INSTALL_TYPE" == "dualboot" ]]; then
        info "Partitioning for dualboot (free space only)..."

        local free_sectors free_bytes free_gb
        free_sectors=$(sgdisk -f "$DISK" 2>/dev/null || echo 0)
        free_bytes=$((free_sectors * 512))
        free_gb=$((free_bytes / 1073741824))
        if [[ "$free_gb" -lt 21 ]]; then
            err "Insufficient free space: ${free_gb}GB (need at least 21GB)"
            return 1
        fi
        info "Free space: ${free_gb}GB"

        sgdisk -n 0:0:+1G -t 0:ef00 "$DISK" || { err "Failed to create EFI partition"; return 1; }
        udevadm settle; sleep 1
        EFI_PART=$(lsblk -npo NAME "$DISK" | tail -1)
        [[ -z "$EFI_PART" ]] && EFI_PART=$(part_name "$DISK" "$(sgdisk -p "$DISK" 2>/dev/null | awk '/^Number/{next} {print $1}' | tail -1)")
        ok "Created EFI: $EFI_PART"

        sgdisk -n 0:0:0 -t 0:8300 "$DISK" || { err "Failed to create root partition"; return 1; }
        udevadm settle; sleep 1
        ROOT_PART=$(lsblk -npo NAME "$DISK" | tail -1)
        [[ -z "$ROOT_PART" ]] && ROOT_PART=$(part_name "$DISK" "$(sgdisk -p "$DISK" 2>/dev/null | awk '/^Number/{next} {print $1}' | tail -1)")
        ok "Created root: $ROOT_PART"
    else
        info "Partitioning $DISK (full wipe)..."
        sgdisk --zap-all "$DISK" || { err "sgdisk --zap-all failed on $DISK"; return 1; }
        sgdisk -o "$DISK" || { err "sgdisk -o failed on $DISK"; return 1; }
        sgdisk -n 1:0:+1G -t 1:ef00 "$DISK" || { err "Failed to create EFI partition"; return 1; }
        sgdisk -n 2:0:0 -t 2:8300 "$DISK" || { err "Failed to create root partition"; return 1; }

        EFI_PART=$(part_name "$DISK" 1)
        ROOT_PART=$(part_name "$DISK" 2)
    fi

    udevadm settle; sleep 2
    local retries=10
    while [[ $retries -gt 0 ]]; do
        if [[ -b "$EFI_PART" && -b "$ROOT_PART" ]]; then
            break
        fi
        info "Waiting for partition device nodes... (${retries})"
        sleep 1
        ((retries--))
    done
    if [[ ! -b "$EFI_PART" || ! -b "$ROOT_PART" ]]; then
        err "Partition device nodes not found after 10s: EFI=$EFI_PART ROOT=$ROOT_PART"
        lsblk "$DISK" 2>/dev/null || true
        return 1
    fi
    ok "Partitions: EFI=$EFI_PART ROOT=$ROOT_PART"
}

# ==============================================================================
# Filesystem creation
# ==============================================================================
create_filesystems() {
    info "Formatting EFI partition..."
    mkfs.fat -F 32 "$EFI_PART" || { err "Failed to format EFI partition $EFI_PART"; return 1; }

    if [[ "$ENCRYPT" == true ]]; then
        LUKS_PASS_SET=false
        if [[ "$LUKS_PASS" == "" ]]; then
            read -rsp "LUKS passphrase: " LUKS_PASS; echo
            read -rsp "Confirm LUKS passphrase: " LUKS_PASS2; echo
            [[ "$LUKS_PASS" != "$LUKS_PASS2" ]] && err "Passwords don't match" && return 1
        fi
        info "Setting up LUKS on $ROOT_PART..."
        echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks2 "$ROOT_PART" - || { err "LUKS format failed on $ROOT_PART"; return 1; }
        echo -n "$LUKS_PASS" | cryptsetup open "$ROOT_PART" cryptroot - || { err "Failed to open LUKS $ROOT_PART"; return 1; }
        ROOT_DEV="/dev/mapper/cryptroot"
    else
        ROOT_DEV="$ROOT_PART"
    fi

    if [[ "$FSTYPE" == "btrfs" ]]; then
        info "Creating BTRFS filesystem..."
        mkfs.btrfs -f "$ROOT_DEV" || { err "Failed to create btrfs on $ROOT_DEV"; return 1; }
        mount "$ROOT_DEV" /mnt || { err "Failed to mount $ROOT_DEV"; return 1; }
        btrfs su cr /mnt/@ || { err "Failed to create @ subvolume"; return 1; }
        btrfs su cr /mnt/@home || { err "Failed to create @home subvolume"; return 1; }
        [[ "$ENCRYPT" == true ]] && btrfs su cr /mnt/@snapshots 2>/dev/null || true
        umount /mnt || true
        mount -o compress=zstd:1,noatime,subvol=@ "$ROOT_DEV" /mnt || { err "Failed to mount @ subvolume"; return 1; }
        mkdir -p /mnt/home
        mount -o compress=zstd:1,noatime,subvol=@home "$ROOT_DEV" /mnt/home || { err "Failed to mount @home"; return 1; }
        [[ "$ENCRYPT" == true ]] && mkdir -p /mnt/.snapshots && \
            mount -o compress=zstd:1,noatime,subvol=@snapshots "$ROOT_DEV" /mnt/.snapshots 2>/dev/null || true
    else
        info "Creating ext4 filesystem..."
        mkfs.ext4 -F "$ROOT_DEV" || { err "Failed to create ext4 on $ROOT_DEV"; return 1; }
        mount "$ROOT_DEV" /mnt || { err "Failed to mount $ROOT_DEV"; return 1; }
    fi

    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot
    ok "Filesystems created and mounted"
}

# ==============================================================================
# Determine DE packages
# ==============================================================================
de_packages() {
    case "$DE" in
        gnome)
            echo "gnome gnome-extra $DM_PKG"
            ;;
        plasma)
            echo "plasma plasma-wayland-session kde-applications $DM_PKG"
            ;;
        hyprland)
            echo "hyprland xdg-desktop-portal-hyprland waybar kitty fuzzel $DM_PKG"
            ;;
        niri)
            echo "niri xdg-desktop-portal-gnome kitty fuzzel $DM_PKG"
            ;;
        *) echo "" ;;
    esac
}

# ==============================================================================
# Base install
# ==============================================================================
install_base() {
    local mode="$1"
    info "Installing base system ($mode)..."

    local microcode
    microcode=$(detect_microcode)
    local de_pkgs
    de_pkgs=$(de_packages)

    local base_pkgs="base base-devel linux linux-firmware linux-headers
        ${microcode}
        btrfs-progs cryptsetup efibootmgr
        networkmanager sudo vim bash-completion git curl wget man-db
        pipewire pipewire-alsa pipewire-pulse wireplumber
        noto-fonts ttf-dejavu ${de_pkgs}"

    if [[ "$mode" == "offline" ]]; then
        offline_pacstrap "$base_pkgs" || return 1
    else
        pacstrap -K /mnt $base_pkgs || return 1
    fi

    genfstab -U /mnt >> /mnt/etc/fstab || return 1
    ok "Base system installed"
}

offline_pacstrap() {
    local pkgs="$1"

    if [[ -d /opt/offline-pkgs && -f /opt/offline-pkgs/offline.db.tar.gz ]]; then
        info "Installing from offline repo at /opt/offline-pkgs..."

        local pac_conf="/tmp/offline-pacstrap-$$.conf"
        cat > "$pac_conf" <<'PACEOF'
[options]
Architecture = auto
SigLevel = Never
LocalFileSigLevel = Never

[offline]
SigLevel = Never
Server = file:///opt/offline-pkgs

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist
PACEOF

        pacstrap -C "$pac_conf" -K /mnt $pkgs
        local ret=$?
        rm -f "$pac_conf"
        return $ret
    fi

    warn "No offline repo found at /opt/offline-pkgs. Falling back to online install."
    pacstrap -K /mnt $pkgs
}

# ==============================================================================
# Chroot configuration
# ==============================================================================
configure_system() {
    local timezone="$1"
    info "Configuring system..."

    local bl_pkg
    if [[ "$BOOTLOADER" == "grub" ]]; then
        bl_pkg="grub"
        [[ "$INSTALL_TYPE" == "dualboot" ]] && bl_pkg="$bl_pkg os-prober"
    else
        bl_pkg="limine"
    fi

    arch-chroot /mnt /bin/bash <<CHROOTEOF
set -e

ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts <<HOSTSEOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTSEOF

echo "root:$ROOT_PASS" | chpasswd
useradd -mG wheel "$USERNAME"
echo "$USERNAME:$USER_PASS" | chpasswd
mkdir -p /etc/sudoers.d
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel

cat > /home/$USERNAME/.bashrc <<BASHRCEOF
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
BASHRCEOF
chown $USERNAME:$USERNAME /home/$USERNAME/.bashrc

systemctl enable NetworkManager systemd-timesyncd

# Bootloader package
pacman -S --noconfirm $bl_pkg

# Display manager
if [[ -n "$DM_PKG" ]]; then
    systemctl enable "$DM_PKG"
fi

# mkinitcpio for encryption
if [[ "$ENCRYPT" == true ]]; then
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
fi
mkinitcpio -P

CHROOTEOF

    ok "System configured"
}

# ==============================================================================
# Bootloader installation
# ==============================================================================
install_bootloader() {
    info "Installing $BOOTLOADER bootloader..."
    local root_uuid

    if [[ "$ENCRYPT" == true ]]; then
        root_uuid=$(blkid -s UUID -o value "$ROOT_PART")
    else
        root_uuid=$(blkid -s UUID -o value "$ROOT_DEV")
    fi

    if [[ "$BOOTLOADER" == "grub" ]]; then
        arch-chroot /mnt /bin/bash <<GRUBEOF
set -e
if [[ "$ENCRYPT" == true ]]; then
    echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
    sed -i 's|GRUB_CMDLINE_LINUX=""|GRUB_CMDLINE_LINUX="cryptdevice=UUID=$root_uuid:cryptroot root=/dev/mapper/cryptroot rw"|' /etc/default/grub
fi
if [[ "$INSTALL_TYPE" == "dualboot" ]]; then
    pacman -S --noconfirm os-prober
    echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
fi
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
GRUBEOF
        if [[ $? -ne 0 ]]; then
            err "GRUB installation failed"
            return 1
        fi

    elif [[ "$BOOTLOADER" == "limine" ]]; then
        local efi_part_num="${EFI_PART##*[a-z]}"
        arch-chroot /mnt /bin/bash <<LIMINEEOF
set -e
mkdir -p /boot/EFI/limine
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/
efibootmgr --create --disk $DISK --part $efi_part_num --label "Arch Linux" --loader '\\EFI\\limine\\BOOTX64.EFI' --unicode
LIMINEEOF
        if [[ $? -ne 0 ]]; then
            err "Limine installation failed"
            return 1
        fi

        local kernel_cmdline
        if [[ "$ENCRYPT" == true ]]; then
            if [[ "$FSTYPE" == "btrfs" ]]; then
                kernel_cmdline="cryptdevice=UUID=$root_uuid:cryptroot root=/dev/mapper/cryptroot rw rootflags=subvol=@ rootfstype=btrfs quiet"
            else
                kernel_cmdline="cryptdevice=UUID=$root_uuid:cryptroot root=/dev/mapper/cryptroot rw quiet"
            fi
        else
            if [[ "$FSTYPE" == "btrfs" ]]; then
                kernel_cmdline="root=UUID=$root_uuid rw rootflags=subvol=@ rootfstype=btrfs quiet"
            else
                kernel_cmdline="root=UUID=$root_uuid rw quiet"
            fi
        fi

        cat > /mnt/boot/limine.conf <<LIMINECONF
timeout: 3

/Arch Linux
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: $kernel_cmdline
    module_path: boot():/initramfs-linux.img

/Arch Linux (fallback)
    protocol: linux
    path: boot():/vmlinuz-linux
    cmdline: $kernel_cmdline
    module_path: boot():/initramfs-linux-fallback.img
LIMINECONF
    fi
    ok "$BOOTLOADER installed"
}

# ==============================================================================
# WiFi connection
# ==============================================================================
connect_wifi() {
    info "Opening iwctl for WiFi configuration..."
    echo "  Inside iwctl:"
    echo "  1. device list"
    echo "  2. station <dev> scan"
    echo "  3. station <dev> get-networks"
    echo "  4. station <dev> connect <SSID>"
    echo "  5. exit"
    echo ""
    iwctl
    sleep 2
    if ping -c 1 archlinux.org &>/dev/null; then
        ok "Internet connected"
    else
        warn "No internet detected. You may continue anyway."
    fi
}

# ==============================================================================
# Full install routine
# ==============================================================================
do_install() {
    local mode="$1"

    info "Checking required tools..."
    local missing=0
    for tool in sgdisk mkfs.fat mkfs.ext4 mkfs.btrfs mount umount cryptsetup pacstrap arch-chroot genfstab curl lsblk blkid; do
        if ! command -v "$tool" &>/dev/null; then
            err "Missing required tool: $tool"
            missing=1
        fi
    done
    if [[ "$missing" -eq 1 ]]; then
        err "Install missing tools and try again."
        return 1
    fi
    ok "All required tools found"

    if [[ "$mode" == "online" ]]; then
        if ! ping -c 1 archlinux.org &>/dev/null; then
            connect_wifi
        else
            ok "Internet already connected (LAN)"
        fi
    fi
    select_disk
    detect_windows
    if [[ "$WINDOWS_DETECTED" == true ]]; then
        select_install_type
    fi
    ask_encryption
    select_filesystem
    select_de
    select_bootloader
    get_user_info
    confirm_install

    local timezone
    timezone=$(detect_timezone)

    partition_disk || { err "Partitioning failed"; return 1; }
    create_filesystems || { err "Filesystem creation failed"; return 1; }
    install_base "$mode" || { err "Base installation failed"; return 1; }
    configure_system "$timezone" || { err "System configuration failed"; return 1; }
    install_bootloader || { err "Bootloader installation failed"; return 1; }

    # Copy offline packages to target if available
    if [[ -d /opt/offline-pkgs ]]; then
        mkdir -p /mnt/var/cache/pacman/pkg
        cp /opt/offline-pkgs/*.pkg.tar.zst /mnt/var/cache/pacman/pkg/ 2>/dev/null || true
    fi

    umount -R /mnt 2>/dev/null || true
    [[ "$ENCRYPT" == true ]] && cryptsetup close cryptroot 2>/dev/null || true

    clear
    ok "Installation complete! You can reboot now."
    read -rp "Reboot now? (y/N): " rb
    [[ "$rb" =~ ^[Yy]$ ]] && reboot
}

# ==============================================================================
# --- REPAIR SYSTEM ---
# ==============================================================================
repair_system() {
    clear
    info "=== System Repair ==="
    echo ""

    # List all block devices
    echo "Available devices:"
    lsblk -f
    echo ""

    # Detect all disk types
    local disks=()
    for d in /dev/nvme*n1 /dev/sd[a-z] /dev/mmcblk* /dev/vda; do
        [[ -b "$d" ]] && disks+=("$d")
    done

    if [[ ${#disks[@]} -eq 0 ]]; then
        err "No disks found"
        return 1
    fi

    echo "Select disk:"
    for i in "${!disks[@]}"; do
        local sz
        sz=$(lsblk -bno SIZE "${disks[i]}" | head -1 | numfmt --to=iec 2>/dev/null || echo "?")
        echo "$((i+1))) ${disks[i]} ($sz)"
    done
    read -rp "Disk [1-${#disks[@]}]: " disk_nr
    local DISK="${disks[$((disk_nr-1))]}"

    # Scan partitions
    local parts=()
    while IFS= read -r line; do
        parts+=("$line")
    done < <(lsblk -npo NAME,TYPE "$DISK" | grep "part" | cut -d' ' -f1)

    if [[ ${#parts[@]} -eq 0 ]]; then
        err "No partitions found on $DISK"
        return 1
    fi

    echo ""
    echo "Partitions on $DISK:"
    for i in "${!parts[@]}"; do
        local fstype
        fstype=$(blkid -s TYPE -o value "${parts[i]}" 2>/dev/null || echo "unknown")
        local size
        size=$(lsblk -bno SIZE "${parts[i]}" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
        local label
        label=$(blkid -s LABEL -o value "${parts[i]}" 2>/dev/null || echo "")
        echo "$((i+1))) ${parts[i]} - $fstype - $size ${label:+[$label]}"
    done

    # Auto-detect partition roles
    local EFI_PART=""
    local ROOT_PART=""  
    local LUKS_PART=""
    local is_btrfs=false
    local is_encrypted=false
    local ROOT_DEV=""

    for p in "${parts[@]}"; do
        local ft
        ft=$(blkid -s TYPE -o value "$p" 2>/dev/null || echo "")
        case "$ft" in
            vfat|fat32)
                if mount -o ro "$p" /mnt 2>/dev/null; then
                    if ls /mnt/EFI 2>/dev/null | grep -qi .; then
                        EFI_PART="$p"
                    fi
                    umount /mnt
                fi
                ;;
            crypto_LUKS)
                LUKS_PART="$p"
                is_encrypted=true
                ;;
            btrfs|ext4|xfs)
                ROOT_PART="$p"
                [[ "$ft" == "btrfs" ]] && is_btrfs=true
                ;;
        esac
    done

    # If no direct root but LUKS found
    if [[ -z "$ROOT_PART" && -n "$LUKS_PART" ]]; then
        ROOT_PART="$LUKS_PART"
        is_encrypted=true
    fi

    # Manual selection if auto-detect fails
    if [[ -z "$ROOT_PART" ]]; then
        echo ""
        warn "Could not auto-detect partitions."
        read -rp "Enter root/LUKS partition (e.g. ${parts[-1]}): " ROOT_PART
    fi
    if [[ -z "$EFI_PART" ]]; then
        read -rp "Enter EFI partition (e.g. ${parts[0]}): " EFI_PART
    fi

    # Unlock if encrypted
    if [[ "$is_encrypted" == true ]]; then
        info "Unlocking LUKS partition..."
        if cryptsetup open "$ROOT_PART" cryptroot 2>/dev/null; then
            ROOT_DEV="/dev/mapper/cryptroot"
            ok "LUKS unlocked"
        else
            err "Failed to unlock $ROOT_PART"
            return 1
        fi
    else
        ROOT_DEV="$ROOT_PART"
    fi

    # Mount root
    info "Mounting root filesystem..."
    mkdir -p /mnt

    if [[ "$is_btrfs" == true ]] || blkid "$ROOT_DEV" | grep -q "btrfs"; then
        is_btrfs=true
        mount "$ROOT_DEV" /mnt
        local subvols
        subvols=$(btrfs subvolume list /mnt 2>/dev/null | awk '{print $NF}' || true)
        if echo "$subvols" | grep -q "^@$"; then
            umount /mnt
            mount -o subvol=@ "$ROOT_DEV" /mnt
            for sv in @home @snapshots @var_log @var_cache; do
                local mountpoint=""
                case "$sv" in
                    @home) mountpoint="/mnt/home" ;;
                    @snapshots) mountpoint="/mnt/.snapshots" ;;
                    @var_log) mountpoint="/mnt/var/log" ;;
                    @var_cache) mountpoint="/mnt/var/cache" ;;
                esac
                if echo "$subvols" | grep -q "^$sv$"; then
                    mkdir -p "$mountpoint"
                    mount -o subvol="$sv" "$ROOT_DEV" "$mountpoint"
                    ok "Mounted $sv"
                fi
            done
        else
            warn "No @ subvolume found, mounted whole device"
        fi
    else
        mount "$ROOT_DEV" /mnt
    fi

    # Mount EFI
    if [[ -n "$EFI_PART" && -b "$EFI_PART" ]]; then
        mkdir -p /mnt/boot
        mount "$EFI_PART" /mnt/boot
        ok "EFI mounted"
    fi

    # Bind virtual filesystems
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    mount --bind /run /mnt/run
    cp -L /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null || true

    ok "System mounted at /mnt"

    # Repair menu
    while true; do
        clear
        echo "========== Repair Menu =========="
        echo "1) Enter chroot (interactive shell)"
        echo "2) Reinstall kernel"
        echo "3) Regenerate initramfs"
        echo "4) Fix bootloader + mkinitcpio"
        echo "5) Reset user password"
        echo "6) Set root password"
        echo "7) Fix mkinitcpio.conf (add encrypt hook)"
        echo "8) Unmount and exit"
        echo "================================="
        read -rp "Choice [1-8]: " rp_choice

        case "$rp_choice" in
            1)
                info "Entering chroot. Type 'exit' to return."
                arch-chroot /mnt
                ;;
            2)
                arch-chroot /mnt pacman -Syu --noconfirm linux linux-headers
                ok "Kernel reinstalled"
                read -rp "Press Enter..."
                ;;
            3)
                arch-chroot /mnt mkinitcpio -P
                ok "Initramfs regenerated"
                read -rp "Press Enter..."
                ;;
            4)
                local detected_bl=""
                if arch-chroot /mnt command -v grub-install &>/dev/null 2>&1 || [[ -f /mnt/boot/grub/grub.cfg ]]; then
                    detected_bl="grub"
                fi
                if arch-chroot /mnt command -v limine &>/dev/null 2>&1 || [[ -f /mnt/boot/limine.conf ]] || [[ -f /mnt/boot/EFI/limine/BOOTX64.EFI ]]; then
                    if [[ -n "$detected_bl" ]]; then
                        detected_bl="both"
                    else
                        detected_bl="limine"
                    fi
                fi

                echo "Detected bootloader: ${detected_bl:-none}"
                echo "1) Reinstall GRUB"
                echo "2) Reinstall Limine"
                if [[ -n "$detected_bl" && "$detected_bl" != "none" && "$detected_bl" != "both" ]]; then
                    echo "3) Auto-fix detected bootloader ($detected_bl)"
                fi
                read -rp "Choice [1-3]: " bl_r

                case "$bl_r" in
                    1)
                        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
                        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
                        ok "GRUB reinstalled"
                        ;;
                    2)
                        local efi_num="${EFI_PART##*[a-z]}"
                        arch-chroot /mnt bash -c "mkdir -p /boot/EFI/limine && cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/ && efibootmgr --create --disk $DISK --part $efi_num --label 'Arch Linux' --loader '\\EFI\\limine\\BOOTX64.EFI' --unicode"
                        ok "Limine reinstalled"
                        ;;
                    3)
                        if [[ "$detected_bl" == "grub" ]]; then
                            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
                            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
                            ok "GRUB fixed"
                        elif [[ "$detected_bl" == "limine" ]]; then
                            local efi_num="${EFI_PART##*[a-z]}"
                            arch-chroot /mnt bash -c "mkdir -p /boot/EFI/limine && cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine/ && efibootmgr --create --disk $DISK --part $efi_num --label 'Arch Linux' --loader '\\EFI\\limine\\BOOTX64.EFI' --unicode"
                            ok "Limine fixed"
                        else
                            warn "Could not auto-detect bootloader, nothing to fix"
                        fi
                        ;;
                esac

                info "Regenerating initramfs..."
                arch-chroot /mnt mkinitcpio -P
                ok "Initramfs regenerated"
                read -rp "Press Enter..."
                ;;
            5)
                echo "Available users:"
                arch-chroot /mnt ls /home 2>/dev/null || true
                read -rp "Username: " ruser
                arch-chroot /mnt passwd "$ruser"
                read -rp "Press Enter..."
                ;;
            6)
                arch-chroot /mnt passwd
                read -rp "Press Enter..."
                ;;
            7)
                arch-chroot /mnt sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
                arch-chroot /mnt mkinitcpio -P
                ok "mkinitcpio fixed with encrypt hook"
                read -rp "Press Enter..."
                ;;
            8)
                info "Unmounting..."
                umount -R /mnt 2>/dev/null || true
                cryptsetup close cryptroot 2>/dev/null || true
                ok "Unmounted. Exiting repair."
                return 0
                ;;
        esac
    done
}

# ==============================================================================
# Main menu
# ==============================================================================
while true; do
    clear
    echo "========================================"
    echo "   Arch Linux Installer & Rescue Kit"
    echo "========================================"
    echo "1) Install Arch Linux (Online)"
    echo "2) Install Arch Linux (Offline - from ISO)"
    echo "3) Repair System"
    echo "4) Exit"
    echo "========================================"
    read -rp "Choice [1-4]: " main_choice

    case "$main_choice" in
        1) do_install "online" ;;
        2) do_install "offline" ;;
        3) repair_system ;;
        4) exit 0 ;;
    esac
done
