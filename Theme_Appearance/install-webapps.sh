#!/bin/bash
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/applications/icons"

# ── Step 1: create directories ──
mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_DIR"

# ── Step 2: install scripts to ~/.local/bin ──

cat >"$BIN_DIR/niri-launch-webapp" <<'SCRIPT'
#!/bin/bash
browser=$(xdg-settings get default-web-browser)
case $browser in
google-chrome*|brave*|microsoft-edge*|opera*|vivaldi*|helium*) ;;
*) browser="chromium.desktop" ;;
esac
exec setsid -- $(sed -n 's/^Exec=\([^ ]*\).*/\1/p' \
  {~/.local,~/.nix-profile,/usr}/share/applications/$browser 2>/dev/null | head -1) \
  --app="$1" "${@:2}"
SCRIPT

cat >"$BIN_DIR/niri-launch-or-focus" <<'SCRIPT'
#!/bin/bash
if (($# == 0)); then
  echo "Usage: niri-launch-or-focus [window-pattern] [launch-command]" >&2; exit 1
fi
WINDOW_PATTERN="$1"
LAUNCH_COMMAND="${2:-niri msg action spawn -- $WINDOW_PATTERN}"
WINDOW_ID=$(niri msg windows | awk -v p="$WINDOW_PATTERN" '
  /^Window ID [0-9]+/ { id = $3; gsub(/:/,"",id) }
  $1=="App" && tolower($0)~tolower(p) { print id; exit }
  $1=="Title:" {
    title=$0; gsub(/^Title: "|"$/,"",title)
    if(tolower(title)~tolower(p)) { print id; exit }
  }')
if [[ -n $WINDOW_ID ]]; then niri msg action focus-window "$WINDOW_ID"
else eval exec setsid $LAUNCH_COMMAND; fi
SCRIPT

cat >"$BIN_DIR/niri-launch-or-focus-webapp" <<'SCRIPT'
#!/bin/bash
if (($# == 0)); then
  echo "Usage: niri-launch-or-focus-webapp [window-pattern] [url-and-flags...]" >&2
  exit 1
fi
WINDOW_PATTERN="$1"; shift
exec niri-launch-or-focus "$WINDOW_PATTERN" "niri-launch-webapp $@"
SCRIPT

cat >"$BIN_DIR/niri-webapp-handler-hey" <<'SCRIPT'
#!/bin/bash
url="$1"; web_url="https://app.hey.com"
if [[ $url =~ ^mailto: ]]; then
  email=$(echo "$url" | sed 's/mailto://')
  web_url="https://app.hey.com/messages/new?to=$email"
fi
exec niri-launch-webapp "$web_url"
SCRIPT

cat >"$BIN_DIR/niri-webapp-handler-zoom" <<'SCRIPT'
#!/bin/bash
url="$1"; web_url="https://app.zoom.us/wc/home"
if [[ $url =~ ^zoom(mtg|us):// ]]; then
  confno=$(echo "$url" | sed -n 's/.*[?&]confno=\([^&]*\).*/\1/p')
  if [[ -n $confno ]]; then
    pwd=$(echo "$url" | sed -n 's/.*[?&]pwd=\([^&]*\).*/\1/p')
    if [[ -n $pwd ]]; then web_url="https://app.zoom.us/wc/join/$confno?pwd=$pwd"
    else web_url="https://app.zoom.us/wc/join/$confno"; fi
  fi
fi
exec niri-launch-webapp "$web_url"
SCRIPT

cat >"$BIN_DIR/niri-webapp-remove" <<'SCRIPT'
#!/bin/bash
set -e

APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/applications/icons"

if ! pgrep -x dms &>/dev/null; then
  echo "Warning: dms not detected — skipping desktop database refresh." >&2
  NO_DMS=1
else
  NO_DMS=0
fi

list_webapps() {
  local i=0
  for f in "$APP_DIR"/*.desktop; do
    [[ -f $f ]] || continue
    grep -q '^Exec=.*\(niri-launch-webapp\|niri-webapp-handler\).*' "$f" 2>/dev/null || continue
    basename "$f" .desktop
  done
}

if (( $# > 0 )); then
  for APP_NAME in "$@"; do
    rm -f "$APP_DIR/$APP_NAME.desktop"
    rm -f "$ICON_DIR/$APP_NAME.png"
    echo "Removed $APP_NAME"
  done
  exit 0
fi

mapfile -t APPS < <(list_webapps)
if (( ${#APPS[@]} == 0 )); then
  echo "No webapps installed." >&2; exit 0
fi

echo "Installed webapps:"
for i in "${!APPS[@]}"; do
  printf "  %d) %s\n" "$((i+1))" "${APPS[$i]}"
done
echo ""
read -r -p "Enter numbers to remove (space-separated) or 0 to cancel: " -a SELECTED
for n in "${SELECTED[@]}"; do
  (( n == 0 )) && echo "Cancelled." && exit 0
  idx=$((n-1))
  [[ -n "${APPS[$idx]:-}" ]] || { echo "Invalid: $n" >&2; continue; }
  name="${APPS[$idx]}"
  rm -f "$APP_DIR/$name.desktop" "$ICON_DIR/$name.png"
  echo "Removed $name"
done

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$APP_DIR" 2>/dev/null || true
fi
if (( NO_DMS == 0 )); then
  dms restart 2>/dev/null || true
fi
SCRIPT

cat >"$BIN_DIR/niri-create-webapp" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/applications/icons"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$ICON_DIR"

if ! pgrep -x dms &>/dev/null; then
  echo "Warning: dms not detected — skipping desktop database refresh." >&2
  NO_DMS=1
else
  NO_DMS=0
fi

read -r -p "Name: " NAME
read -r -p "URL: " URL
read -r -p "Icon URL: " ICON_URL

ICON_FILE="$ICON_DIR/$NAME.png"

echo "Downloading icon..."
if ! curl -fsSL -o "$ICON_FILE" "$ICON_URL"; then
  echo "Failed to download icon from $ICON_URL" >&2
  exit 1
fi

cat >"$APP_DIR/$NAME.desktop" <<EOF
[Desktop Entry]
Version=1.0
Name=$NAME
Comment=$NAME
Exec=$BIN_DIR/niri-launch-webapp $URL
Terminal=false
Type=Application
Icon=$ICON_FILE
StartupNotify=true
EOF

chmod +x "$APP_DIR/$NAME.desktop"
echo "Created $APP_DIR/$NAME.desktop"

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$APP_DIR" 2>/dev/null || true
fi

if (( NO_DMS == 0 )); then
  dms restart 2>/dev/null || true
fi

echo "Done — $NAME installed."
SCRIPT

cat >"$BIN_DIR/niri-window-close-all" <<'SCRIPT'
#!/bin/bash
niri msg windows | awk '/^Window ID [0-9]+/{id=$3;gsub(/:/,"",id);print id}' |
  while read -r id; do niri msg action focus-window "$id" && niri msg action close-window; done
niri msg action focus-workspace 1
SCRIPT

chmod +x "$BIN_DIR/niri-launch-webapp" "$BIN_DIR/niri-launch-or-focus" \
        "$BIN_DIR/niri-launch-or-focus-webapp" \
        "$BIN_DIR/niri-webapp-handler-hey" "$BIN_DIR/niri-webapp-handler-zoom" \
        "$BIN_DIR/niri-webapp-remove" "$BIN_DIR/niri-create-webapp" \
        "$BIN_DIR/niri-window-close-all"

# ── Step 3: download icons ──

declare -A ICONS
ICONS=(
  [HEY-Niri]=https://dashboardicons.com/DALL-E_AI_Icon_HEY.png
  [Basecamp-Niri]=https://dashboardicons.com/DALL-E_AI_Icon_Basecamp.png
  [WhatsApp-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/whatsapp.png
  [Google\ Photos-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/google-photos.png
  [Google\ Contacts-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/google-contacts.png
  [Google\ Messages-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/google-messages.png
  [Google\ Maps-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/google-maps.png
  [ChatGPT-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/chatgpt.png
  [YouTube-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/youtube.png
  [GitHub-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/github.png
  [X-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/x.png
  [Figma-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/figma.png
  [Discord-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/discord.png
  [Zoom-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/zoom.png
  [Fizzy-Niri]=https://dashboardicons.com/DALL-E_AI_Icon_Fizzy.png
  [YouTube\ Music-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/youtube-music.png
  [Gmail-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/gmail.png
  [Google\ Drive-Niri]=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/google-drive.png
)

echo "Downloading icons..."
for name in "${!ICONS[@]}"; do
  dest="$ICON_DIR/$name.png"
  if [[ ! -f $dest ]]; then
    curl -fsSL -o "$dest" "${ICONS[$name]}" && echo "  $name" || echo "  $name (failed)"
  fi
done

# Fallback: use Google favicons for anything missing
for name in "${!ICONS[@]}"; do
  dest="$ICON_DIR/$name.png"
  if [[ ! -s $dest ]]; then
    case $name in
      HEY-Niri)          url="https://app.hey.com" ;;
      Basecamp-Niri)     url="https://launchpad.37signals.com" ;;
      WhatsApp-Niri)     url="https://web.whatsapp.com" ;;
      Google\ Photos-Niri) url="https://photos.google.com" ;;
      Google\ Contacts-Niri) url="https://contacts.google.com" ;;
      Google\ Messages-Niri) url="https://messages.google.com" ;;
      Google\ Maps-Niri) url="https://maps.google.com" ;;
      ChatGPT-Niri)      url="https://chatgpt.com" ;;
      YouTube-Niri)      url="https://youtube.com" ;;
      GitHub-Niri)       url="https://github.com" ;;
      X-Niri)            url="https://x.com" ;;
      Figma-Niri)        url="https://figma.com" ;;
      Discord-Niri)      url="https://discord.com" ;;
      Zoom-Niri)         url="https://zoom.us" ;;
      Fizzy-Niri)        url="https://app.fizzy.do" ;;
      YouTube\ Music-Niri) url="https://music.youtube.com" ;;
      Gmail-Niri)        url="https://mail.google.com" ;;
      Google\ Drive-Niri) url="https://drive.google.com" ;;
    esac
    favicon="https://www.google.com/s2/favicons?domain=$url&sz=128"
    curl -fsSL -o "$dest" "$favicon" 2>/dev/null && echo "  $name (favicon)"
  fi
done

# ── Step 4: create .desktop files ──

install_webapp() {
  local name="$1" url="$2" icon="$3" custom_exec="$4" mime_types="$5"
  local exec_cmd

  if [[ -n $custom_exec ]]; then
    exec_cmd=""
    for word in $custom_exec; do
      if [[ -x $BIN_DIR/$word ]]; then exec_cmd+="$BIN_DIR/$word "
      else exec_cmd+="$word "; fi
    done
    exec_cmd="${exec_cmd% }"
  else
    exec_cmd="$BIN_DIR/niri-launch-webapp $url"
  fi

  cat >"$APP_DIR/$name.desktop" <<EOF
[Desktop Entry]
Version=1.0
Name=$name
Comment=$name
Exec=$exec_cmd
Terminal=false
Type=Application
Icon=$ICON_DIR/$icon
StartupNotify=true
EOF
  if [[ -n $mime_types ]]; then
    echo "MimeType=$mime_types" >>"$APP_DIR/$name.desktop"
  fi
  chmod +x "$APP_DIR/$name.desktop"
  echo "  $name"
}

echo "Creating desktop files..."
install_webapp "HEY-Niri"             https://app.hey.com                        "HEY-Niri.png"             "niri-webapp-handler-hey %u" "x-scheme-handler/mailto"
install_webapp "Basecamp-Niri"        https://launchpad.37signals.com            "Basecamp-Niri.png"        "" ""
install_webapp "WhatsApp-Niri"        https://web.whatsapp.com/                  "WhatsApp-Niri.png"        "" ""
install_webapp "Google Photos-Niri"   https://photos.google.com/                 "Google Photos-Niri.png"   "" ""
install_webapp "Google Contacts-Niri" https://contacts.google.com/               "Google Contacts-Niri.png" "" ""
install_webapp "Google Messages-Niri" https://messages.google.com/web/conversations "Google Messages-Niri.png" "" ""
install_webapp "Google Maps-Niri"     https://maps.google.com                    "Google Maps-Niri.png"     "" ""
install_webapp "ChatGPT-Niri"         https://chatgpt.com/                       "ChatGPT-Niri.png"         "" ""
install_webapp "YouTube-Niri"         https://youtube.com/                       "YouTube-Niri.png"         "" ""
install_webapp "GitHub-Niri"          https://github.com/                        "GitHub-Niri.png"          "" ""
install_webapp "X-Niri"               https://x.com/                             "X-Niri.png"               "" ""
install_webapp "Figma-Niri"           https://figma.com/                         "Figma-Niri.png"           "" ""
install_webapp "Discord-Niri"         https://discord.com/channels/@me           "Discord-Niri.png"         "" ""
install_webapp "Zoom-Niri"            https://app.zoom.us/wc/home                "Zoom-Niri.png"            "niri-webapp-handler-zoom %u" "x-scheme-handler/zoommtg;x-scheme-handler/zoomus"
install_webapp "Fizzy-Niri"           https://app.fizzy.do/                      "Fizzy-Niri.png"           "" ""
install_webapp "YouTube Music-Niri"   https://music.youtube.com                  "YouTube Music-Niri.png"   "" ""
install_webapp "Gmail-Niri"           https://mail.google.com                    "Gmail-Niri.png"           "" ""
install_webapp "Google Drive-Niri"    https://drive.google.com                   "Google Drive-Niri.png"    "" ""

# ── Step 5: add ~/.local/bin to PATH ──

if ! grep -qs '\.local/bin' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  echo "Added ~/.local/bin to PATH in ~/.bashrc"
fi

export PATH="$HOME/.local/bin:$PATH"

# ── Step 6: update desktop database ──

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$APP_DIR" 2>/dev/null || true
fi

# Restart dms so it picks up the new desktop files
if pgrep -x dms &>/dev/null; then
  dms restart 2>/dev/null || true
fi

# ── done ──
echo ""
echo "All done — 18 webapps installed and ready."
echo "PATH updated for this session. Open your app launcher (Mod+Space) to see them."
echo ""
echo "💡 Use 'niri-create-webapp' to interactively add more webapps."
