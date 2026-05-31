#!/bin/bash

NIRI_CONFIG="$HOME/.config/niri"
SKILL_DIR="$HOME/.local/share/omaniri/default/niri"

# 1. Ensure app override dir exists
mkdir -p "$NIRI_CONFIG/apps"

# 2. Create clean browser rules (no opacity)
cat > "$NIRI_CONFIG/apps/browser.kdl" << 'EOF'
// Browser types
// https://niri-wm.github.io/niri/Configuration:-Window-Rules.html

window-rule {
    match app-id="(?i)((google-)?chrom(e|ium)|brave-browser|microsoft-edge|vivaldi-stable|helium)"
    open-floating false
}

// Hide the screen-sharing notification bar
window-rule {
    match title=".*is sharing.*"
    open-floating true
    open-focused false
}
EOF

# 3. Create clean terminal rules (no opacity)
cat > "$NIRI_CONFIG/apps/terminals.kdl" << 'EOF'
EOF

# 4. Create local apps.kdl that references our clean files
cat > "$NIRI_CONFIG/apps.kdl" << 'EOF'
// App-specific window rules (local clean copies, no opacity)

include "~/.config/niri/apps/browser.kdl"
include "~/.local/share/omaniri/default/niri/apps/localsend.kdl"
include "~/.local/share/omaniri/default/niri/apps/moonlight.kdl"
include "~/.local/share/omaniri/default/niri/apps/pip.kdl"
include "~/.local/share/omaniri/default/niri/apps/qemu.kdl"
include "~/.local/share/omaniri/default/niri/apps/system.kdl"
include "~/.config/niri/apps/terminals.kdl"
include "~/.local/share/omaniri/default/niri/apps/webcam-overlay.kdl"
EOF

# 5. Point config.kdl to local apps.kdl instead of default
if grep -q 'include "~/.local/share/omaniri/default/niri/apps.kdl"' "$NIRI_CONFIG/config.kdl"; then
    sed -i 's|include "~/.local/share/omaniri/default/niri/apps.kdl"|include "~/.config/niri/apps.kdl"|' "$NIRI_CONFIG/config.kdl"
fi

# 6. Ensure Nautilus doesn't float
WINDOWRULES="$NIRI_CONFIG/windowrules.kdl"
if ! grep -q "org.gnome.Nautilus" "$WINDOWRULES"; then
    cat >> "$WINDOWRULES" << 'EOF'

// Keep Nautilus windows tiled and filling their column
window-rule {
    match app-id="org.gnome.Nautilus"
    open-floating false
    default-column-width { proportion 0.5; }
    default-window-height { proportion 1.0; }
}

// Override the default system.kdl rule that floats Nautilus file dialogs
window-rule {
    match app-id="org.gnome.Nautilus"
    match title="^(Open.*Files?|Open [Ff]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to (open|save).*|[Cc]hoose.*)"
    open-floating false
    default-column-width { proportion 0.5; }
    default-window-height { proportion 1.0; }
}
EOF
fi

# 7. Remove waybar opacity from looknfeel.kdl
LOOKNFEEL="$NIRI_CONFIG/looknfeel.kdl"
if grep -q "opacity 0.99" "$LOOKNFEEL"; then
    awk '
    /layer-rule/ { layered=1 }
    layered && /opacity 0.99/ { skip=1; next }
    layered && /}/ { if (skip) { skip=0; layered=0; next } }
    { print }
    ' "$LOOKNFEEL" > "$LOOKNFEEL.tmp" && mv "$LOOKNFEEL.tmp" "$LOOKNFEEL"
fi

# 8. Reload niri
niri msg action load-config-file

echo "Transparency removed. Niri config reloaded."
