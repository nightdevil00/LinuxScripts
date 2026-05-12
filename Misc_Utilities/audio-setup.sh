#!/usr/bin/env bash
set -euo pipefail

PACMAN_PACKAGES=(
  alsa-card-profiles alsa-lib alsa-topology-conf alsa-ucm-conf alsa-utils
  ffmpeg ffmpegthumbnailer flac
  gst-libav gst-plugin-gtk gst-plugin-pipewire gst-plugins-bad-libs
  gst-plugins-base gst-plugins-base-libs gst-plugins-good gstreamer
  kcodecs lame libfdk-aac libpipewire libpulse libsndfile libsoxr
  libvorbis libwireplumber lv2 opus
  pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse
  portaudio
  sof-firmware sound-theme-freedesktop twolame webrtc-audio-processing-1
  wireplumber
)

echo "==> Installing audio packages..."
sudo pacman -S --needed "${PACMAN_PACKAGES[@]}"

WIREPLUMBER_DIR="$HOME/.config/wireplumber/wireplumber.conf.d"
WIREPLUMBER_CONF="$WIREPLUMBER_DIR/bluetooth-a2dp-autoconnect.conf"

echo "==> Creating WirePlumber config directory..."
mkdir -p "$WIREPLUMBER_DIR"

echo "==> Writing bluetooth A2DP auto-connect config..."
cat > "$WIREPLUMBER_CONF" <<'CONF'
monitor.bluez.rules = [
  {
    matches = [
      {
        device.name = "~bluez_card.*"
      }
    ]
    actions = {
      update-props = {
        bluez5.auto-connect = [ a2dp_sink a2dp_source ]
      }
    }
  }
]
CONF

echo "==> Enabling and starting PipeWire services..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber

echo "==> Done! Audio setup complete."
