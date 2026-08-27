#!/bin/bash

# ==============================================================================
#
# Omarchy Interactive Rescue Script
#
# Designed to be run from an Arch Linux live environment (archiso) to repair a
# broken Omarchy installation. It mounts the target system (auto-detecting
# LUKS and reading subvolumes/ESP from the target's own /etc/fstab), chroots
# into it, and performs repair operations.
#
# Omarchy notes that this script accounts for:
#   - Root may be LUKS-encrypted or plain btrfs (auto-detected).
#   - Bootloader is Limine; bootable images are Unified Kernel Images
#     (UKIs) built and deployed to /efi/EFI/Linux by `kernel-install`.
#   - Kernel in use: `linux` (plus `linux-headers`).
#
# ==============================================================================

# --- Utility Functions ---
C_BLUE="\e[34m"
C_GREEN="\e[32m"
C_RED="\e[31m"
C_YELLOW="\e[33m"
C_RESET="\e[0m"

info()    { echo -e "${C_BLUE}INFO:${C_RESET} $1"; }
success() { echo -e "${C_GREEN}SUCCESS:${C_RESET} $1"; }
error()   { echo -e "${C_RED}ERROR:${C_RESET} $1" >&2; }
warn()    { echo -e "${C_YELLOW}WARN:${C_RESET} $1"; }
press_enter_to_continue() { read -r -p "Press Enter to continue..."; }

# --- State shared across functions ---
ROOTDEV=""   # decrypted/plain device holding the btrfs root
MOUNTED_ESP=0

# --- Main Script Functions ---

show_main_menu() {
    clear
    echo "========================================"
    echo " Omarchy Rescue Script - Main Menu"
    echo "========================================"
    echo "1. Connect to Wi-Fi (Optional)"
    echo "2. Mount System Partitions"
    echo "3. Enter Rescue Shell (Chroot)"
    echo "4. Unmount and Reboot"
    echo "5. Exit"
    echo "----------------------------------------"
}

connect_wifi() {
    info "This will launch the interactive iwctl tool."
    echo "  Follow these steps inside iwctl:"
    echo "  1. Run: device list"
    echo "  2. Run: station <device_name> scan"
    echo "  3. Run: station <device_name> get-networks"
    echo "  4. Run: station <device_name> connect <SSID>"
    echo "  5. When connected, type 'exit' to return."
    echo
    iwctl
    success "Returned from iwctl. Check connection with 'ping archlinux.org'."
}

mount_system() {
    # Idempotent: unmount anything left from a previous run.
    if mountpoint -q /mnt; then
        warn "/mnt already mounted; unmounting first."
        umount -R /mnt 2>/dev/null || true
        cryptsetup close cryptroot 2>/dev/null || true
    fi

    info "Listing available block devices..."
    lsblk -d -o NAME,SIZE,MODEL
    echo
    read -r -p "Enter the disk containing your Omarchy installation (e.g., sda, nvme0n1): " disk_name
    local disk="/dev/${disk_name}"
    if [ ! -b "${disk}" ]; then
        error "Disk ${disk} not found."
        return 1
    fi

    info "Listing partitions on ${disk}..."
    lsblk "${disk}"
    echo

    local luks_partition_name
    read -r -p "LUKS-encrypted root partition (e.g., nvme0n1p6) - leave BLANK if unencrypted: " luks_partition_name

    if [ -n "${luks_partition_name}" ]; then
        local luks_partition="/dev/${luks_partition_name}"
        if ! cryptsetup isLuks "${luks_partition}" 2>/dev/null; then
            error "${luks_partition} is not a LUKS container."
            return 1
        fi
        info "Opening LUKS container at ${luks_partition}..."
        if ! cryptsetup open "${luks_partition}" cryptroot; then
            error "Failed to open LUKS container."
            return 1
        fi
        ROOTDEV="/dev/mapper/cryptroot"
        success "LUKS container opened."
    else
        read -r -p "Plain btrfs root partition (e.g., nvme0n1p6): " root_partition_name
        ROOTDEV="/dev/${root_partition_name}"
        if [ ! -b "${ROOTDEV}" ]; then
            error "Partition ${ROOTDEV} not found."
            return 1
        fi
    fi

    info "Mounting BTRFS root subvolume (@) to /mnt..."
    if ! mount -o subvol=@ "${ROOTDEV}" /mnt; then
        error "Failed to mount root subvolume."
        return 1
    fi
    success "Root mounted at /mnt."

    if [ ! -f /mnt/etc/fstab ]; then
        error "No /mnt/etc/fstab found - is this really the root subvolume?"
        return 1
    fi

    info "Mounting additional subvolumes and the EFI system partition from target fstab..."
    # Parse the target's own fstab so we match its exact layout.
    while read -r spec mp fstype opts dump pass; do
        # Skip comments, blanks, and the already-mounted root.
        [[ "${spec}" == \#* ]] && continue
        [[ -z "${mp}" || "${mp}" == "/" ]] && continue

        if [[ "${fstype}" == "btrfs" ]]; then
            mkdir -p "/mnt${mp}"
            if mount -o "${opts}" "${ROOTDEV}" "/mnt${mp}"; then
                info "  mounted ${mp}"
            else
                warn "  failed to mount ${mp} (continuing)"
            fi
        elif [[ "${mp}" == "/efi" || "${fstype}" == "vfat" ]]; then
            mkdir -p /mnt/efi
            if mount "${spec}" /mnt/efi; then
                info "  mounted /efi (ESP)"
                MOUNTED_ESP=1
            else
                error "  FAILED to mount EFI system partition at /efi."
                error "  Boot images cannot be deployed without it!"
            fi
        fi
    done < /mnt/etc/fstab

    if [ "${MOUNTED_ESP}" -ne 1 ]; then
        error "EFI system partition was NOT mounted. Kernel/UKI deployment will fail."
        error "Please check the target's fstab and re-run mount."
        return 1
    fi

    # Bind-mount live tooling the chroot will need.
    mount --bind /dev  /mnt/dev  2>/dev/null || true
    mount --bind /proc /mnt/proc 2>/dev/null || true
    mount --bind /sys  /mnt/sys  2>/dev/null || true

    success "System partitions mounted under /mnt (including /efi)."
}

enter_rescue_shell() {
    if ! mountpoint -q /mnt; then
        error "System partitions are not mounted. Please run option 2 first."
        return 1
    fi
    if [ "${MOUNTED_ESP}" -ne 1 ]; then
        error "EFI partition is not mounted. Cannot safely repair boot. Re-run option 2."
        return 1
    fi

    info "Creating inner rescue menu script..."
    local inner_script="/mnt/inner_rescue.sh"
    cat << 'EOF' > "${inner_script}"
#!/bin/bash

C_BLUE="\e[34m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_RESET="\e[0m"
info()    { echo -e "\n${C_BLUE}INFO:${C_RESET} $1"; }
success() { echo -e "${C_GREEN}SUCCESS:${C_RESET} $1\n"; }
error()   { echo -e "${C_RED}ERROR:${C_RESET} $1" >&2; }
warn()    { echo -e "${C_YELLOW}WARN:${C_RESET} $1"; }

redeploy_ukis() {
    info "Redeploying Unified Kernel Images via kernel-install..."
    local count=0
    for d in /usr/lib/modules/*/; do
        local kver
        kver="$(basename "$d")"
        local vmlinuz="$d/vmlinuz"
        if [ -f "$vmlinuz" ]; then
            info "  building + deploying UKI for ${kver}"
            if kernel-install add "$kver" "$vmlinuz"; then
                success "  deployed UKI for ${kver}"
                count=$((count+1))
            else
                error "  failed to deploy UKI for ${kver}"
            fi
        fi
    done
    if [ "$count" -gt 0 ]; then
        success "Redeployed ${count} UKI(s) into /efi/EFI/Linux."
    else
        error "No kernel images found in /usr/lib/modules. Install kernels first."
    fi
    echo "Current UKIs in /efi/EFI/Linux:"
    ls -la /efi/EFI/Linux 2>/dev/null || warn "  /efi/EFI/Linux not present"
}

reinstall_kernels() {
    info "Reinstalling kernel packages (triggers UKI redeploy via pacman hook)..."
    if pacman -S linux linux-headers; then
        success "Kernel packages reinstalled."
    else
        error "Kernel package reinstall failed."
    fi
}

install_nvidia() {
    info "Installing NVIDIA drivers..."
    if pacman -S nvidia nvidia-utils; then
        success "NVIDIA driver installation complete."
        info "Remember to redeploy UKIs (option 1) so the new modules are included."
    else
        error "NVIDIA driver installation failed."
    fi
}

show_inner_menu() {
    echo "========================================"
    echo " Rescue Shell Menu (root, inside chroot)"
    echo "========================================"
    echo "1. Redeploy boot UKIs (kernel-install)"
    echo "2. Reinstall kernel packages"
    echo "3. Install NVIDIA drivers"
    echo "4. Drop to interactive root shell"
    echo "5. Exit Rescue Shell"
    echo "----------------------------------------"
}

while true; do
    show_inner_menu
    read -p "Enter your choice [1-5]: " choice
    case $choice in
        1) redeploy_ukis ;;
        2) reinstall_kernels ;;
        3) install_nvidia ;;
        4)
            info "Dropping to root shell. Type 'exit' when done."
            bash
            ;;
        5) info "Exiting rescue shell."; break ;;
        *) error "Invalid choice." ;;
    esac
done
EOF

    chmod +x "${inner_script}"

    info "Entering rescue shell (root). You will see a new menu."
    sleep 2
    arch-chroot /mnt /bin/bash "/inner_rescue.sh"

    rm -f "${inner_script}"
    success "Returned from rescue shell."
}

unmount_and_reboot() {
    info "Unmounting all partitions and closing LUKS container..."
    umount -R /mnt 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true
    MOUNTED_ESP=0
    success "Cleanup complete. Rebooting in 3 seconds..."
    sleep 3
    reboot
}

# --- Main Loop ---
while true; do
    show_main_menu
    read -r -p "Enter your choice [1-5]: " choice
    case $choice in
        1) connect_wifi; press_enter_to_continue ;;
        2) mount_system; press_enter_to_continue ;;
        3) enter_rescue_shell; press_enter_to_continue ;;
        4)
            read -r -p "Are you sure you want to unmount and reboot? (y/n): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                unmount_and_reboot
            else
                info "Reboot cancelled."
                press_enter_to_continue
            fi
            ;;
        5) info "Exiting script."; exit 0 ;;
        *) error "Invalid choice."; press_enter_to_continue ;;
    esac
done
