# Scripts Collection

A collection of Arch Linux shell scripts organized by category. These scripts were accumulated from multiple projects (ArchVM, MyArch, Omarchy-Tools, DualBoot, freshArch, etc.) and organized into functional groups.

---

## Arch_Install

| File | Description |
|------|-------------|
| `arch_install.sh` | Main interactive Arch installer with dualboot/fullwipe modes, GRUB/Limine bootloaders, multiple DEs (GNOME/Plasma/Hyprland/Niri), ext4/btrfs with optional LUKS encryption, and a repair system utility. |
| `install_arch_archvm.sh` | VM-focused install with BTRFS on LUKS or ext4, GRUB bootloader, yay + Chrome, and post-install dotfiles selection (JaKooLit/Omarchy). |
| `install_arch_automated_luks_btrfs.sh` | Automated non-interactive installer with LUKS2 encryption, BTRFS subvolumes, and Limine bootloader for NVMe drives. |
| `install_arch_automated_omarchy_helpers.sh` | Omarchy helper library driving archinstall with pre-generated JSON configs, offline repo setup, and Omarchy DE installer in chroot. |
| `install_arch_basic.sh` | Simple interactive installer with prompt-based partitioning, systemd-boot, and selectable DE. |
| `install_arch_dialog_tui.sh` | Dialog-based TUI installer with mirror region selection, UEFI/BIOS, filesystem choice, and multiple bootloaders. |
| `install_arch_disk_detect.sh` | Installer with automatic Windows partition detection, ext4, Limine bootloader, and AUR package installation. |
| `install_arch_dualboot_limine_modular.sh` | Modular dualboot installer with Windows detection, LUKS2 + BTRFS + swapfile, Limine, Plymouth, Snapper, and ZRAM. |
| `install_arch_fresh_dualboot_wipe.sh` | Comprehensive 1798-line installer with dualboot/fullwipe, LUKS, BTRFS, Limine, Plymouth, ZRAM, offline repo, and Omarchy setup. |
| `install_arch_interactive.sh` | Lightweight interactive installer with menu-based filesystem, swap mode, profile, DE, network config, and GRUB/systemd-boot. |
| `install_arch_interactive_prompt.sh` | Minimal interactive installer with prompt-based partitioning and selectable DE/bootloader. |
| `install_arch_interactive_v2.sh` | Interactive installer with LUKS, BTRFS subvolumes, TPM2 auto-unlock via clevis, GRUB, and ZRAM. |
| `install_arch_meta_postinstall.sh` | Minimal post-install script that installs packages from a list, enables bluetooth, clones yay-bin, and runs AUR reinstall. |
| `install_arch_multi_mode.sh` | Multi-mode installer supporting reinstall (keep /home), dualboot with Windows, and empty-disk full setup with GNOME + NVIDIA + GRUB. |
| `install_arch_nvme_ext4_btrfs.sh` | Advanced installer for NVMe/VirtIO/MMC/SATA with ext4/BTRFS, optional LUKS, Windows dualboot detection, and Hyprland dotfiles. |
| `install_arch_omarchy_nix.sh` | Non-interactive installer using archinstall with LUKS2 + BTRFS + Limine, then deploys Omarchy DE from local or GitHub. |
| `install_arch_omarchy_retry.sh` | Interactive installer with retry logic for pacstrap, LUKS2 + BTRFS, Limine from source, and Omarchy DE from GitHub. |
| `install_arch_omarchy_test.sh` | Identical to `install_arch_omarchy_retry.sh`. |
| `install_arch_project_luks_limine.sh` | Interactive installer with Windows dualboot detection, LUKS2 + BTRFS subvolumes, and Limine with timezone auto-detection. |
| `install_arch_simple_windows_safe.sh` | Windows-safe installer that detects Windows, creates partitions in free space, LUKS + BTRFS + GRUB. |
| `install_arch_sub_advanced.sh` | Identical to `install_arch_nvme_ext4_btrfs.sh`. |
| `install_arch_sub_automated.sh` | Identical to `install_arch_automated_luks_btrfs.sh`. |
| `install_arch_sub_dualboot_limine.sh` | Identical to `install_arch_dualboot_limine_modular.sh`. |
| `install_arch_sub_logging.sh` | Identical to `install_arch_with_logging.sh`. |
| `install_arch_sub_ntp_disk.sh` | Identical to `install_arch_archvm.sh`. |
| `install_arch_sub_simple.sh` | Identical to `install_arch_simple_windows_safe.sh`. |
| `install_arch_uefi_separate_home.sh` | UEFI installer with separate EFI + root + /home partitions, GNOME, GRUB, and NVIDIA support. |
| `install_arch_uefi_wipe.sh` | UEFI installer that wipes disk, creates EFI + root, installs GNOME with GRUB and NVIDIA. |
| `install_arch_with_logging.sh` | Installer with logging, LUKS2 (argon2id), BTRFS subvolumes, Snapper, GRUB, and auto timezone via IP geolocation. |
| `install_arch_with_partitioning_wizard.sh` | Gum-based TUI installer with partitioning wizard (dualboot/wipe/manual), archinstall JSON configs, and Limine + Windows chainload. |
| `mount_arch_luks_subvolumes.sh` | Interactive script to select disk, unlock LUKS, mount BTRFS + EFI, chroot, and install Limine + yay. |
| `mount_arch_luks_subvolumes_root.sh` | Same as above but installs GRUB instead of Limine. |
| `mount_arch_luks_subvolumes_scripts.sh` | Identical to `mount_arch_luks_subvolumes.sh`. |
| `prepare_chroot_pacstrap.sh` | Creates `arch-chroot/` directory and bootstraps with base packages via pacstrap. |
| `prepare_chroot_pacstrap_root.sh` | Identical to `prepare_chroot_pacstrap.sh`. |
| `prepare_disk_for_install.sh` | Interactive partition creation tool with custom-sized EFI, root, swap, and home partitions. |
| `recover_install_fs_choice.sh` | Installer with separate recovery partition containing Arch ISO, GRUB recovery entry, and weekly auto-update timer. |
| `recover_install_iso_encryption.sh` | Installer with recovery partition, downloaded Arch ISO, GRUB recovery entry, and remote recovery script. |
| `reinstall_arch_full.sh` | Full reinstall with EFI + recovery + root partitioning, GNOME + GRUB, and weekly ISO updates. |
| `reinstall_os_keep_home.sh` | Reinstalls while preserving /home, formats EFI and root, with GNOME + GRUB. |

## Backup_Restore

| File | Description |
|------|-------------|
| `backup_config_and_packages.sh` | Creates a `.zip` backup of Hyprland/Waybar configs, Omarchy data, and exports official/AUR/Flatpak package lists with embedded restore script. |
| `backup_dotfiles_full_fresh.sh` | Creates timestamped `.tar.gz` of `~/.config`, `~/.local`, `~/bin`, `~/.bashrc` and exports comprehensive package lists (pacman, yay, flatpak, snap, pipx, npm, cargo). |
| `backup_dotfiles_rsync.sh` | Creates `.tar.gz` backup of `~/.config` and `~/.local/share` via rsync with exclude patterns, exports Pacman and AUR package lists. |
| `backup_dotfiles_scripts.sh` | Identical to `backup_dotfiles_rsync.sh`. |
| `restore_dotfiles_from_archive.sh` | Interactive restore from `.tar.gz`, extracts and restores via rsync, optionally reinstalls packages from saved lists. |
| `restore_dotfiles_fresh.sh` | Takes backup archive as argument, backs up existing configs with `.backup_*` suffix, restores and displays saved package list. |
| `restore_dotfiles_scripts.sh` | Identical to `restore_dotfiles_from_archive.sh`. |

## Disk_Utilities

| File | Description |
|------|-------------|
| `partition_disk_list_select.sh` | Menu-driven partition manager listing disks, showing layouts, with create/delete/wipe operations and unmount handling. |
| `partition_disk_preserve_windows.sh` | Identical to `partition_disk_util.sh`. |
| `partition_disk_safe_windows.sh` | Windows-safe partitioner that creates named Arch EFI/ROOT partitions in free space with Windows protection. |
| `partition_disk_util.sh` | Comprehensive partition manager with Windows detection, EFI+ROOT creation (with validation), and safe deletion. |
| `partition_disk_v2.sh` | Partitioner that protects Windows partitions, uses `parted print free`, creates LUKS2 BTRFS root with subvolumes for archinstall. |
| `partition_dualboot_focus.sh` | Full Arch install with Windows detection, dualboot/full-disk, LUKS2 BTRFS, GRUB, and system configuration. |
| `partition_dualboot_focus_sub.sh` | Identical to `partition_dualboot_focus.sh`. |
| `prepare_disk_with_calculator.sh` | Creates GPT partition table and interactively sizes/formats EFI, root, swap, home partitions with size calculator. |

## DualBoot

| File | Description |
|------|-------------|
| `add_grub_loopback_iso_entry.sh` | Adds a GRUB menuentry to boot an Arch ISO via loopback. |
| `install_arch_dualboot_dual_scr.sh` | Dual-boot installer with Limine, LUKS2 encryption on raw partition, Btrfs, Plymouth, Snapper, ZRAM. |
| `install_arch_dualboot_grub_alt.sh` | Dual-boot installer with GRUB, Windows detection, LUKS2, Btrfs. |
| `install_arch_dualboot_grub_complete.sh` | Complete interactive installer with GRUB, Windows detection, LUKS2, Btrfs, os-prober, NetworkManager. |
| `install_arch_dualboot_grub_safe.sh` | Safe installer auto-detecting Windows, largest free region, GRUB, LUKS2, Btrfs, os-prober. |
| `install_arch_dualboot_grub_sub.sh` | Identical to `install_arch_dualboot_grub_safe.sh`. |
| `install_arch_dualboot_gum_ui.sh` | Production-ready installer using `gum` TUI, dual-boot Limine, LUKS2, Btrfs, Snapper, Plymouth, ZRAM. |
| `install_arch_dualboot_limine_alt.sh` | Improved Limine installer with enhanced disk listing and Windows detection across all disks. |
| `install_arch_dualboot_limine_complete.sh` | Production-ready Limine installer with Windows-safe dual-boot, LUKS2, Btrfs, Snapper, Plymouth. |
| `install_arch_dualboot_limine_dual.sh` | Dual-boot Limine installer with Windows detection, LUKS2 on raw partition, Btrfs, Plymouth, Snapper. |
| `install_arch_dualboot_limine_dual_sub.sh` | Nearly identical to `install_arch_dualboot_limine_dual.sh`. |
| `install_arch_dualboot_limine_free_space.sh` | Limine installer for dual-boot in free space with LUKS2, Btrfs swapfile, Windows chainload entry. |
| `install_arch_dualboot_limine_full.sh` | Full-featured Limine installer with dual-boot, LUKS2, Btrfs swapfile with resume offset, Snapper, Plymouth, ZRAM, microcode. |
| `install_arch_dualboot_limine_full_sub.sh` | Nearly identical to `install_arch_dualboot_limine_full.sh`. |
| `install_arch_dualboot_limine_interactive.sh` | Interactive Limine installer with Windows detection, LUKS2, Btrfs, EFI boot entry management. |
| `install_arch_dualboot_limine_outofoptions.sh` | Limine installer with Windows-safe dual-boot, input validation, LUKS2, Btrfs, Snapper, Plymouth. |
| `install_arch_dualboot_limine_sub.sh` | Limine installer for dual-boot in free space with LUKS2, Btrfs swapfile, Windows chainload. |
| `install_arch_dualboot_limine_test.sh` | Test-oriented Limine installer building EFI-stub kernel images via objcopy + systemd-stub. |
| `install_arch_dualboot_limine_win_sub.sh` | Production-ready Limine installer with Windows detection, LUKS2, Btrfs, swapfile, Snapper, Plymouth, ZRAM, AUTO_* env vars. |
| `install_arch_dualboot_limine_windows.sh` | Identical to `install_arch_dualboot_limine_win_sub.sh`. |
| `install_arch_dualboot_limine_works.sh` | Working Limine installer with Windows-safe dual-boot, LUKS2, Btrfs, Snapper, Plymouth, ZRAM, modular main(). |
| `install_arch_dualboot_offline_ui.sh` | ML4W-style installer with gum/figlet UI, online (pacstrap) and offline (rsync) methods, Limine, Btrfs. |
| `install_arch_dualboot_outofoptions_sub.sh` | Limine installer with Windows-safe dual-boot, input validation, LUKS2, Btrfs, Snapper, Plymouth, ZRAM. |
| `install_arch_dualboot_partition_focus.sh` | GRUB installer focused on flexible partition sizing, Windows detection, LUKS2, Btrfs, Snapper, GPU/CPU packages. |
| `install_arch_dualboot_partition_sub.sh` | Nearly identical to `install_arch_dualboot_partition_focus.sh`. |

## Hardware_Setup

| File | Description |
|------|-------------|
| `install_cpu_power_profile.sh` | Menu to select CPU power profile (Performance/Balanced/Power Saver) and install/enable corresponding systemd service. |
| `install_gaming_deps.sh` | Installs gaming dependencies from a `list.txt` file using yay. |
| `mount_unmount_iphone.sh` | Mounts/unmounts iPhone via `ifuse` with dependency checking and troubleshooting. |
| `setup_fan_control.sh` | Enables ThinkPad fan control via `thinkpad_acpi` with interactive level selection. |
| `setup_keyboard_backlight.sh` | Installs, starts, stops keyboard backlight systemd service on supported laptops. |
| `setup_nvidia_drivers.sh` | Detects GPU, selects appropriate driver (open-dkms vs dkms), installs with Wayland config and early KMS. |

## ISO_Build

| File | Description |
|------|-------------|
| `Hyprland-ISO/arch_install.sh` | Interactive Arch installer and rescue kit for live ISO with online/offline, dualboot, multiple DEs, and system repair. |
| `Hyprland-ISO/build_iso_hyprland.sh` | Builds custom Arch live ISO with Hyprland, SDDM autologin, pre-configured dotfiles, and offline repo. |
| `build_arch_iso_custom_scripts.sh` | Minimal custom Arch ISO with git/nano, copies install.sh and archrescue.sh, auto-starts on boot. |
| `build_arch_iso_custom_sub.sh` | Identical to `build_arch_iso_custom_scripts.sh`. |
| `build_iso_custom_from_github.sh` | Builds Arch ISO that downloads installer scripts from GitHub URLs with autologin and auto-run service. |
| `build_iso_custom_from_github_sub.sh` | Identical to `build_iso_custom_from_github.sh`. |
| `build_iso_gnome_nvidia.sh` | Sets up GNOME Arch ISO with NVIDIA, dconf dark theme, GDM autologin, and partition installer. |
| `build_iso_hyprland.sh` | Builds Hyprland live ISO with SDDM autologin, offline packages, pre-configured dotfiles. |
| `build_iso_hyprland_nvidia.sh` | Builds Hyprland/Niri ISO with NVIDIA, SDDM autologin, AUR packages, and dotfiles. |
| `build_iso_hyprland_nvidia_sub.sh` | Identical to `build_iso_hyprland_nvidia.sh`. |
| `build_iso_hyprland_project.sh` | Builds Hyprland ISO with dotfiles, sysusers live user, TTY1 autologin, and Install.sh script. |
| `build_live_iso_gnome_installer.sh` | Builds GNOME ISO with NVIDIA, dark theme, GDM autologin, and GitHub-fetched install script. |
| `build_live_iso_gnome_sub.sh` | Identical to `build_live_iso_gnome_installer.sh`. |
| `build_omarchy_iso.sh` | Creates Arch ISO with offline Omarchy installer using local package caches and embedded project files. |
| `build_omarchy_iso_offline.sh` | Creates Arch ISO cloning omarchy repo, copying configs, using local package repository. |
| `build_omarchy_iso_offline_chat.sh` | Creates Omarchy ISO with offline support, copying host config via rsync, live user with Hyprland autostart. |
| `build_omarchy_iso_sub.sh` | Identical to `build_omarchy_iso.sh`. |
| `build_omarchy_iso_testing.sh` | Creates Omarchy testing ISO copying host's `.config` and `.local/share/omarchy` into the build. |
| `build_omarchy_iso_utility.sh` | Creates Omarchy ISO cloning repo, copying configs/bin/apps, using local package cache. |

## Misc_Utilities

| File | Description |
|------|-------------|
| `cava_waybar_audio_visualizer.sh` | Launches cava in pipe mode, converts audio data to colored blocks formatted as Waybar JSON. |
| `copy_config_to_iso_build.sh` | Copies user config dirs into Arch ISO build's airootfs. |
| `copy_config_to_iso_util.sh` | Identical to `copy_config_to_iso_build.sh`. |
| `install_gum_dualboot.sh` | Full gum-TUI Arch dual-boot installer with disk selection, Windows detection, LUKS2, Btrfs, Limine. |
| `setup_ventoy_recovery.sh` | Downloads Ventoy + Arch ISO, copies to recovery partition, adds GRUB chainload entry. |
| `test_limine_install.sh` | Interactive dual-boot installer testing Limine with LUKS, Btrfs, and EFI-stub kernel images. |

## Omarchy_Tools

| File | Description |
|------|-------------|
| `cleaner_remove_default_apps.sh` | Gum TUI to scan/remove unwanted Omarchy pre-installed packages and webapps, with Hyprland shortcut cleanup. |

## Package_Management

| File | Description |
|------|-------------|
| `cleanup_packages_keep_list.sh` | Removes all pacman packages except a hardcoded keep-list, empties `/home/user/`, optional reboot. |
| `cleanup_packages_mgmt.sh` | Identical to `cleanup_packages_keep_list.sh`. |
| `export_package_lists.sh` | Exports pacman explicitly installed packages and Flatpak apps/runtimes to text files. |
| `export_package_lists_mgmt.sh` | Identical to `export_package_lists.sh`. |
| `export_package_lists_myarch.sh` | Identical to `export_package_lists.sh`. |
| `install_aur_package_manual.sh` | Manually installs single AUR package by cloning from GitHub and running makepkg. |
| `install_aur_package_manual_omarchy.sh` | Identical to `install_aur_package_manual.sh`. |
| `install_aur_packages_batch.sh` | Installs AUR packages via yay first, falls back to manual clone + makepkg. |
| `reinstall_aur_from_list.sh` | Reinstalls all AUR packages from `pkglist-aur.txt` via yay. |
| `reinstall_aur_mgmt.sh` | Identical to `reinstall_aur_from_list.sh`. |
| `reinstall_aur_simple.sh` | Identical to `reinstall_aur_from_list.sh`. |
| `reinstall_pacman_from_list.sh` | Reinstalls all pacman packages from `pacman_explicit_packages.txt` and enables bluetooth. |
| `reinstall_pacman_mgmt.sh` | Identical to `reinstall_pacman_from_list.sh`. |
| `reinstall_packages_from_file.sh` | Reinstalls all pacman packages from `packages.x86_64` and enables bluetooth. |
| `update_system_pacman_yay.sh` | Updates system with pacman + yay, temporarily commenting out omarchy repo. |

## Rescue_Repair

| File | Description |
|------|-------------|
| `omarchy_doctor.sh` | Most feature-rich rescue with 14-option menu: Wi-Fi, mount, rescue shell, full update, kernel/NVIDIA reinstall, initramfs, bootloader repair, fsck, password reset, logs, root shell, unmount/reboot. |
| `repair_pc_interactive.sh` | Minimal repair: mounts LUKS BTRFS, reinstalls kernel/limine via chroot, configures Limine, unmounts/reboots. |
| `repair_pc_scripts.sh` | Identical to `repair_pc_interactive.sh`. |
| `repair_pc_sub.sh` | Identical to `repair_pc_interactive.sh`. |
| `repair_system_encrypted.sh` | Menu-driven repair: mounts encrypted BTRFS, reinstalls kernel/drivers via chroot, configures Limine. |
| `repair_system_omarchy.sh` | Full-featured repair with CLI args (--auto-detect, --partition, --bootloader), auto LUKS detection, 10+ menu options. |
| `repair_system_sub.sh` | Identical to `repair_system_encrypted.sh`. |
| `rescue_arch_dualboot.sh` | Simplified ISO-ready dual-boot rescue with BTRFS + LUKS2, root/user chroot, pacman keyring fix, NVIDIA fallback. |
| `rescue_arch_interactive.sh` | Interactive menu rescue: Wi-Fi, LUKS unlock, BTRFS mount, chroot rescue shell, unmount/reboot. |
| `rescue_arch_iso.sh` | Identical to `rescue_arch_interactive.sh`. |
| `rescue_arch_iso_v2.sh` | Advanced rescue with strict mode, BTRFS subvolume mount, virtual FS binding, Limine EFI stub rebuild. |
| `rescue_arch_menu_driven.sh` | Identical to `rescue_arch_iso_v2.sh`. |
| `rescue_arch_scripts.sh` | Enhanced rescue with EFI mounting, root/user chroot, NVIDIA auto-detection, pacman keyring refresh. |

## System_Config

| File | Description |
|------|-------------|
| `add_user_to_groups.sh` | Creates system groups (docker, libvirt, vboxusers) and adds user to them. |
| `disable_boot_services.sh` | Disables docker and systemd-binfmt from starting at boot. |
| `disk_partition_utility.sh` | Interactive partition manager with create/delete/wipe and safe Btrfs/swap unmount. |
| `enable_nopasswd_sudo.sh` | Adds user to wheel and creates sudoers drop-in for passwordless sudo. |
| `enable_passwordless_sudo.sh` | Creates sudoers drop-in granting user full passwordless sudo. |
| `enable_sudo_pacman.sh` | Adds sudoers rule for passwordless pacman only with syntax validation. |
| `enable_sudo_scripts.sh` | Creates sudoers drop-in for passwordless pacman only. |
| `enable_sudo_util.sh` | Creates sudoers drop-in granting user full passwordless sudo. |
| `fix_mount_permissions.sh` | Adds user to storage group and creates Polkit rule for passwordless mounting. |
| `fix_nautilus_default_file_manager.sh` | Sets Nautilus as default file manager (removes inode/directory from kitty-open). |
| `fix_nautilus_mime_scripts.sh` | Same as above — sets Nautilus as default file manager. |
| `fix_nautilus_mime_util.sh` | Same as above — sets Nautilus as default file manager. |
| `fix_udisks2_mount_permissions.sh` | Creates Polkit rule for passwordless udisks2 actions for wheel group. |
| `fix_udisks2_scripts.sh` | Identical to `fix_udisks2_mount_permissions.sh`. |
| `fix_udisks2_util.sh` | Identical to `fix_udisks2_mount_permissions.sh`. |
| `fix_wifi_dhcp.sh` | Creates systemd-networkd config for wlan0 with DHCP. |
| `git_sync_repo.sh` | Interactive git pull/push for ArchVM repo with change detection. |
| `git_sync_util.sh` | Identical to `git_sync_repo.sh`. |
| `improve_brightness_and_fonts.sh` | Sets brightness via xrandr and enables font hinting/sub-pixel rendering. |
| `install_fonts_scripts.sh` | Installs Nerd Fonts symbols and Font Awesome via pacman. |
| `install_nautilus_custom_scripts.sh` | Installs "Create File" and "Open Terminal Here" Nautilus right-click scripts. |
| `install_nautilus_scripts_util.sh` | Same as above — installs Nautilus right-click scripts. |
| `install_nautilus_scripts_v2.sh` | Same as above — installs Nautilus right-click scripts. |
| `install_nerd_fonts.sh` | Installs Hack, Cascadia Code, Fira Code, JetBrains Mono Nerd Fonts + symbols, rebuilds cache. |
| `install_walker_shutdown_service.sh` | Installs and enables walker-shutdown systemd service. |
| `set_default_editor.sh` | Lets user pick default editor, sets it for all text/code MIME types, syncs EDITOR/VISUAL env vars. |
| `set_fan_control.sh` | Enables ThinkPad fan control via thinkpad_acpi with interactive level menu. |
| `set_gtk_theme.sh` | Copies Omarchy GTK theme CSS to gtk-4.0 config and restarts Nautilus. |
| `setup_iphone_mount.sh` | Installs iPhone mounting packages, adds user to fuse group, creates mountpoint. |
| `setup_limine.sh` | Writes Limine bootloader config for encrypted Btrfs root and installs with EFI entry. |
| `setup_limine_auto.sh` | Auto-detects EFI mount/root/kernel/initramfs, writes limine.cfg, installs Limine, creates EFI entry. |
| `setup_networkmanager_iwd_switch.sh` | Installs NM, stops iwd/systemd-networkd, enables NM, configures Waybar for nm-applet. |
| `setup_nvidia.sh` | Detects GPU, installs drivers, enables early KMS, adds NVIDIA env vars to Hyprland config. |
| `setup_recovery_iso.sh` | Builds custom Arch live ISO with Hyprland/Niri, SDDM, NVIDIA, AUR packages, dotfiles. |
| `setup_wifi_scripts.sh` | Unblocks WiFi via rfkill and connects to specific SSID via iwctl. |
| `switch_to_networkmanager_scripts.sh` | Stops iwd/systemd-resolved, installs/enables NetworkManager, writes static resolv.conf. |
| `test_script.sh` | Interactive installer with disk selection, Windows preservation, LUKS, Btrfs, Limine. |
| `toggle_sddm_autologin.sh` | Enables/disables SDDM autologin by toggling PAM config (requires root). |

## Theme_Appearance

| File | Description |
|------|-------------|
| `add_hyprland_transparency.sh` | Adds transparency to Hyprland/omarchy config by replacing rgb() with rgba() and setting opacity rules. |
| `disable_hyprland_effects.sh` | Toggles Hyprland blur and window opacity on/off for omarchy (accepts enable/disable argument). |
| `improve_fonts_arch.sh` | Automates Arch font guide: installs core fonts, enables presets, configures FreeType subpixel hinting. |
| `improve_fonts_better.sh` | Installs fonts from repos + AUR, creates freetype2.sh profile, writes fonts/local.conf, regenerates cache. |
| `improve_fonts_theme.sh` | Identical to `improve_fonts_better.sh`. |
| `install_fonts_from_local.sh` | Installs font files from local `fonts/` directory to `/usr/share/fonts/custom_fonts`. |
| `install_fonts_scripts.sh` | Identical to `install_fonts_from_local.sh`. |
| `install_fonts_theme.sh` | Identical to `install_fonts_from_local.sh`. |
| `install_fonts_via_pacman.sh` | Installs Nerd Fonts symbols and Font Awesome via pacman. |
| `install_nerd_fonts_scripts.sh` | Installs Hack, Cascadia Code, Fira Code, JetBrains Mono Nerd Fonts via pacman, rebuilds cache. |
| `matugen_wallpaper_watcher.sh` | Watches omarchy wallpaper symlink and triggers matugen on change. |
| `remove_hyprland_transparency.sh` | Removes transparency from omarchy config (rgba() -> rgb(), opacity to 1.0). |
| `remove_transparency_omarchy.sh` | Identical to `remove_hyprland_transparency.sh`. |
| `set_random_wallpaper.sh` | Picks random wallpaper from ~/Pictures/wallpapers, launches swaybg, updates hypr background symlink. |
| `set_random_wallpaper_hypr.sh` | Identical to `set_random_wallpaper.sh`. |
| `set_random_wallpaper_hyprland_config.sh` | Identical to `set_random_wallpaper.sh`. |
| `set_random_wallpaper_theme.sh` | Identical to `set_random_wallpaper.sh`. |
| `setup_matugen_color_auto.sh` | Full matugen automation: installs matugen-bin + inotify-tools, deploys wallpaper watcher for hypr background, systemd service. |
| `setup_matugen_scripts.sh` | Same as setup_matugen_color_auto but monitors omarchy wallpaper symlink instead. |
| `setup_matugen_theme.sh` | Identical to `setup_matugen_color_auto.sh`. |
| `watch_wallpaper_and_theme.sh` | Standalone watcher loop monitoring omarchy wallpaper symlink and triggering matugen. |

## Root

| File | Description |
|------|-------------|
| `organize_scripts.sh` | Master script that copies and renames scripts from various source projects (ArchVM, MyArch, DualBoot, Omarchy-Tools, etc.) into this organized directory structure. |
