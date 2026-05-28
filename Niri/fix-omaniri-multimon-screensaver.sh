#!/bin/bash
set -euo pipefail

# ======================================================================
# fix-omaniri-multimon-screensaver.sh
#
# Fixes the Omaniri screensaver for multi-monitor Niri layouts.
# Detects all connected monitors, adds Niri window rules,
# installs swayidle, and rewrites the screensaver script.
# Idempotent — safe to run multiple times.
# ======================================================================

NIRI_CONF="$HOME/.config/niri/config.kdl"
SCREENSAVER_BIN="$HOME/.local/share/omaniri/bin/omaniri-screensaver"

# ── helpers ──────────────────────────────────────────────────────────

die() { echo "Error: $*" >&2; exit 1; }

ensure_deps() {
  local missing=()
  command -v jq >/dev/null 2>&1 || missing+=("jq")
  command -v niri >/dev/null 2>&1 || missing+=("niri")
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Required tools not found: ${missing[*]}. Install them first."
  fi
}

# ── 1. Detect monitors ──────────────────────────────────────────────

detect_monitors() {
  niri msg -j outputs 2>/dev/null | jq -r 'keys[]' 2>/dev/null || die \
    "Failed to detect monitors. Is Niri running?"
}

# ── 2. Install swayidle (idempotent) ────────────────────────────────

install_swayidle() {
  if command -v swayidle >/dev/null 2>&1; then
    echo "[ok] swayidle already installed"
    return
  fi
  echo "[..] Installing swayidle..."
  sudo pacman -S --noconfirm swayidle
  echo "[ok] swayidle installed"
}

# ── 3. Add window rules to niri config (idempotent) ─────────────────

# We wrap generated rules in a sentinel comment so we can detect them.
SENTINEL_OPEN="# --- omaniri-screensaver multi-monitor rules ---"
SENTINEL_CLOSE="# --- end omaniri-screensaver rules ---"

generate_rule_block() {
  local monitors=("$@")
  echo "$SENTINEL_OPEN"
  for mon in "${monitors[@]}"; do
    cat <<-RULES
		window-rule {
		    match app-id="^org.omaniri.screensaver$" title="^screensaver-${mon}$"
		    open-floating true
		    open-fullscreen true
		    open-on-output "${mon}"
		}
		RULES
  done
  echo "$SENTINEL_CLOSE"
}

add_window_rules() {
  local monitors=("$@")

  if grep -qF "$SENTINEL_OPEN" "$NIRI_CONF" 2>/dev/null; then
    echo "[ok] Niri window rules already present in $NIRI_CONF"
    # Still verify the rules match current monitors — could warn if out of sync
    return
  fi

  echo "[..] Adding window rules for ${#monitors[@]} monitor(s) to $NIRI_CONF..."
  {
    echo ""
    generate_rule_block "${monitors[@]}"
  } >> "$NIRI_CONF"
  echo "[ok] Window rules appended"
}

# ── 4. Write the screensaver script ─────────────────────────────────

write_screensaver() {
  local monitors=("$@")
  local target_dir
  target_dir="$(dirname "$SCREENSAVER_BIN")"
  mkdir -p "$target_dir"

  echo "[..] Writing $SCREENSAVER_BIN..."

  cat > "$SCREENSAVER_BIN" <<-'SCRIPT'
	#!/bin/bash
	# omaniri:summary=Run the omaniri screensaver on ALL connected monitors under Niri.

	exit_screensaver() {
	  pkill -x tte 2>/dev/null
	  pkill -f org.omaniri.screensaver 2>/dev/null
	  pkill -f "swayidle -w timeout 1" 2>/dev/null
	  exit 0
	}

	trap exit_screensaver SIGINT SIGTERM SIGHUP SIGQUIT

	monitors=$(niri msg -j outputs | jq -r 'keys[]')

	for mon in $monitors; do
	  niri msg action spawn -- alacritty --class "org.omaniri.screensaver" --title "screensaver-$mon" -e bash -c "
	    printf '\033]11;rgb:00/00/00\007'
	    sleep 0.4
	    while true; do
	      tte -i ~/.config/omaniri/branding/screensaver.txt \
	        --frame-rate 60 --canvas-width \$(tput cols) --canvas-height \$(tput lines) \
	        --reuse-canvas --anchor-canvas c --anchor-text c --random-effect --no-eol --no-restore-cursor
	    done
	  " &
	done

	swayidle -w \
	  timeout 1 'echo "idle"' \
	  resume 'pkill -f org.omaniri.screensaver'
	SCRIPT

  chmod +x "$SCREENSAVER_BIN"
  echo "[ok] $SCREENSAVER_BIN written and executable"
}

# ── 5. Main ─────────────────────────────────────────────────────────

main() {
  ensure_deps

  echo "==> Detecting monitors..."
  mapfile -t monitors < <(detect_monitors)
  if [[ ${#monitors[@]} -eq 0 ]]; then
    die "No monitors detected."
  fi
  echo "    Found: ${monitors[*]}"

  echo ""
  echo "==> Installing swayidle..."
  install_swayidle

  echo ""
  echo "==> Adding Niri window rules..."
  add_window_rules "${monitors[@]}"

  echo ""
  echo "==> Writing screensaver script..."
  write_screensaver "${monitors[@]}"

  echo ""
  echo "================================================================"
  echo "Done! The multi-monitor screensaver fix has been applied."
  echo ""
  echo "What's next:"
  echo "  1. Reload Niri config:  niri msg action reload-init-file"
  echo "  2. Test the screensaver: omaniri-screensaver"
  echo "================================================================"
}

main "$@"
