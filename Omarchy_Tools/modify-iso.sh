#!/usr/bin/env bash
set -euo pipefail

SELF="$(basename "$0")"
TEMP_FILES=()

cleanup() {
  if [[ -n "${EXTRACT_DIR:-}" && -d "$EXTRACT_DIR" ]]; then
    sudo chmod -R u+w "$EXTRACT_DIR" 2>/dev/null; sudo rm -rf "$EXTRACT_DIR" 2>/dev/null
  fi
  if [[ -n "${SFS_WORK:-}" && -d "$SFS_WORK" ]]; then
    sudo chmod -R u+w "$SFS_WORK" 2>/dev/null; sudo rm -rf "$SFS_WORK" 2>/dev/null
  fi
  for f in "${TEMP_FILES[@]}"; do sudo rm -f "$f" 2>/dev/null; done
}
trap cleanup EXIT

usage() {
  cat <<EOF
Usage: $SELF [options]

Interactive menu (no args):
  $SELF

Quick mode (all flags):
  $SELF -i <iso> -c <configurator> -a <.automated_script.sh> [-o <output.iso>] [-w <work_dir>]

Options:
  -i   Path to Omarchy ISO
  -c   Path to configurator script
  -a   Path to .automated_script.sh
  -o   Output ISO path (default: <iso_dir>/omarchy-modified.iso)
  -w   Working directory (default: <iso_dir>/iso_work)
  -h   Show this help

Environment:
  SKIP_CONFIRM=1   Skip the "Proceed?" prompt for headless use

Example:
  # Interactive
  $SELF

  # Quick
  SKIP_CONFIRM=1 $SELF -i omarchy-3.8.2.iso -c configurator -a .automated_script.sh

Details:
  Modifies an Omarchy ISO by replacing /root/configurator and
  /root/.automated_script.sh inside airootfs.sfs while preserving
  all boot configuration (Syslinux BIOS + EFI).

  Needs about 10 GB free in the working directory.  The script
  runs entirely as your user but uses sudo during cleanup to
  remove read-only files extracted from the ISO.
EOF
  exit 0
}

info()  { gum style --foreground 4 "• $1"; }
ok()    { gum style --foreground 2 "✓ $1"; }
err()   { gum style --foreground 1 "✗ $1"; }
warn()  { gum style --foreground 3 "⚠ $1"; }
header() {
  gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 60 --margin "1 0" \
    "Omarchy ISO Modifier"
}

require_cmds() {
  local missing=()
  for cmd in xorriso mksquashfs unsquashfs sha512sum gum; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if ((${#missing[@]})); then
    err "Missing: ${missing[*]}"; echo "Install: sudo pacman -S xorriso squashfs-tools gum"; exit 1
  fi
}

pick_file() {
  local prompt="$1" file
  file=$(gum file --height 20 "$HOME" 2>/dev/null || gum input --prompt "$prompt: ")
  while [[ ! -f "$file" ]]; do
    err "File not found: $file"
    file=$(gum input --prompt "$prompt: ")
  done
  realpath "$file"
}

run_with_spinner() {
  local title="$1"; shift
  gum spin --spinner points --title "$title" -- "$@"
}

interactive_menu() {
  clear; header
  info "Select the Omarchy ISO file:"
  ISO_FILE=$(pick_file "ISO path")
  ok "$(basename "$ISO_FILE")"

  echo; info "Select the configurator script:"
  SCRIPT1=$(pick_file "configurator path")
  ok "$(basename "$SCRIPT1") ($(numfmt --to=iec "$(stat -c%s "$SCRIPT1")"))"

  echo; info "Select .automated_script.sh:"
  SCRIPT2=$(pick_file ".automated_script.sh path")
  ok "$(basename "$SCRIPT2") ($(numfmt --to=iec "$(stat -c%s "$SCRIPT2")"))"

  local default_out default_work
  default_out="$(dirname "$ISO_FILE")/omarchy-modified.iso"
  default_work="$(dirname "$ISO_FILE")/iso_work"
  echo; OUTPUT_ISO=$(gum input --value "$default_out" --prompt "Output ISO: ")
  WORK_DIR=$(gum input --value "$default_work" --prompt "Work dir: ")
}

extract_efi_image() {
  local iso="$1" outdir="$2"
  local info efi_start efi_count

  info=$(xorriso -indev "$iso" -report_el_torito 2>/dev/null)
  efi_start=$(echo "$info" | grep "EFI boot image" | awk '{print $5}' | tr -d ',' | head -1)
  efi_count=$(echo "$info" | grep "EFI boot image" | awk '{print $6}' | head -1)

  if [[ -n "$efi_start" && -n "$efi_count" ]]; then
    mkdir -p "$outdir/EFI/archiso"
    dd if="$iso" bs=2048 skip="$efi_start" count="$efi_count" \
      of="$outdir/EFI/archiso/efiboot.img" 2>/dev/null
    [[ -f "$outdir/EFI/archiso/efiboot.img" && "$(stat -c%s "$outdir/EFI/archiso/efiboot.img")" -gt 0 ]]
  fi
}

modify_iso() {
  header
  info "Step 1/5: Extracting ISO ..."
  EXTRACT_DIR=$(mktemp -d --tmpdir="$WORK_DIR" iso_extract.XXX)
  run_with_spinner "Extracting ISO..." xorriso -osirrox on -indev "$ISO_FILE" -extract / "$EXTRACT_DIR"
  ok "ISO extracted"

  info "Step 2/5: Unsquashing airootfs.sfs ..."
  SFS_FILE="$EXTRACT_DIR/arch/x86_64/airootfs.sfs"
  SFS_WORK=$(mktemp -d --tmpdir="$WORK_DIR" sfs_work.XXX)
  run_with_spinner "Unsquashing..." unsquashfs -f -d "$SFS_WORK" "$SFS_FILE"
  ok "airootfs.sfs unsquashed"

  info "Step 3/5: Replacing scripts ..."
  cp "$SCRIPT1" "$SFS_WORK/root/configurator"
  cp "$SCRIPT2" "$SFS_WORK/root/.automated_script.sh"
  chmod 755 "$SFS_WORK/root/configurator" "$SFS_WORK/root/.automated_script.sh"
  ok "configurator ($(numfmt --to=iec "$(stat -c%s "$SFS_WORK/root/configurator")"))"
  ok ".automated_script.sh ($(numfmt --to=iec "$(stat -c%s "$SFS_WORK/root/.automated_script.sh")"))"

  info "Step 4/5: Rebuilding airootfs.sfs ..."
  chmod u+w "$EXTRACT_DIR/arch/x86_64/"
  rm -f "$SFS_FILE"
  run_with_spinner "Compressing (xz, this takes a while)..." \
    mksquashfs "$SFS_WORK" "$SFS_FILE" -comp xz -Xbcj x86 -b 1M -noappend
  run_with_spinner "Checksum..." sh -c "sha512sum \"$SFS_FILE\" > \"$EXTRACT_DIR/arch/x86_64/airootfs.sha512\""
  ok "SFS rebuilt ($(numfmt --to=iec "$(stat -c%s "$SFS_FILE")"))"

  info "Step 5/5: Building ISO ..."
  local isohdpfx="$EXTRACT_DIR/boot/syslinux/isohdpfx.bin"
  local volid
  volid=$(xorriso -indev "$ISO_FILE" -pvd_info 2>/dev/null |
    grep "^Volume Id" | head -1 | cut -d: -f2 | xargs)
  if [[ -z "$volid" ]]; then volid="OMARCHY_$(date +%Y%m)"; fi

  local xorriso_args=(
    xorriso -as mkisofs
    -iso-level 3 -full-iso9660-filenames
    -volid "$volid"
  )

  if [[ -f "$EXTRACT_DIR/boot/syslinux/isolinux.bin" ]]; then
    xorriso_args+=(
      -eltorito-boot boot/syslinux/isolinux.bin
      -eltorito-catalog boot/syslinux/boot.cat
      -no-emul-boot -boot-load-size 4 -boot-info-table
    )
  fi

  if [[ -f "$isohdpfx" ]]; then
    xorriso_args+=(-isohybrid-mbr "$isohdpfx")
  fi

  if extract_efi_image "$ISO_FILE" "$EXTRACT_DIR"; then
    local efi="$EXTRACT_DIR/EFI/archiso/efiboot.img"
    xorriso_args+=(
      -eltorito-alt-boot -e EFI/archiso/efiboot.img -no-emul-boot
      -isohybrid-gpt-basdat
      -append_partition 2 0xef "$efi"
    )
  else
    warn "Could not extract EFI boot image; BIOS-only boot"
  fi

  xorriso_args+=(
    -partition_cyl_align off -partition_offset 16
    -output "$OUTPUT_ISO" "$EXTRACT_DIR"
  )

  run_with_spinner "Writing ISO..." "${xorriso_args[@]}"
  ok "ISO written: $OUTPUT_ISO ($(numfmt --to=iec "$(stat -c%s "$OUTPUT_ISO")"))"
  chmod 644 "$OUTPUT_ISO" 2>/dev/null || true
}

main() {
  require_cmds

  ISO_FILE=""; SCRIPT1=""; SCRIPT2=""; OUTPUT_ISO=""; WORK_DIR=""

  while getopts "i:c:a:o:w:h" opt; do
    case "$opt" in
      i) ISO_FILE=$(realpath "$OPTARG") ;;
      c) SCRIPT1=$(realpath "$OPTARG") ;;
      a) SCRIPT2=$(realpath "$OPTARG") ;;
      o) OUTPUT_ISO=$(realpath "$OPTARG") ;;
      w) WORK_DIR=$(realpath "$OPTARG") ;;
      h|*) usage ;;
    esac
  done

  if [[ -z "$ISO_FILE" ]]; then
    interactive_menu
  else
    [[ -z "$SCRIPT1" || -z "$SCRIPT2" ]] && { err "With -i you need -c and -a too"; usage; }
    OUTPUT_ISO="${OUTPUT_ISO:-$(dirname "$ISO_FILE")/omarchy-modified.iso}"
    WORK_DIR="${WORK_DIR:-$(dirname "$ISO_FILE")/iso_work}"
  fi

  for f in "$ISO_FILE" "$SCRIPT1" "$SCRIPT2"; do
    [[ ! -f "$f" ]] && { err "Not found: $f"; exit 1; }
  done

  clear
  header
  echo
  gum style --bold "Summary:"; echo
  info "ISO:    $(basename "$ISO_FILE")"
  info "Output: $OUTPUT_ISO"
  echo
  if [[ -z "${SKIP_CONFIRM:-}" ]]; then
    gum confirm "Proceed?" --affirmative "Go!" --negative "Cancel" || exit 0
  fi

  mkdir -p "$WORK_DIR"
  modify_iso

  clear
  header
  ok "All done!"
  info "Output: $OUTPUT_ISO ($(numfmt --to=iec "$(stat -c%s "$OUTPUT_ISO")"))"
  info "Work dir: $WORK_DIR (safe to delete)"
}

main "$@"
