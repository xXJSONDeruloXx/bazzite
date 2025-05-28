#!/bin/bash
# ARM64 build script for Bazzite on Apple Silicon hardware

# Modified error handling: 
# - Removed "-e" to prevent immediate exit on command failure
# - We handle errors manually with || true where needed
set -oux pipefail

# Always build for ARM64 architecture
export BUILDAH_PLATFORM=linux/arm64

### Install packages

# Enable RPM Fusion repositories for additional packages
dnf5 install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Update repositories to ensure we have the latest package information
dnf5 update -y --refresh

# Install essential packages for Apple Silicon hardware 
# Using --skip-broken and --skip-unavailable to handle package availability issues
# Note: asahi-audio, apple-firmware-m1, and asahi-scripts are already included in the base image
dnf5 install -y --skip-broken --skip-unavailable \
  tmux \
  vim \
  htop \
  git \
  powertop \
  power-profiles-daemon \
  thermald \
  firefox \
  distrobox \
  podman \
  dconf-editor \
  gnome-tweaks \
  gnome-extensions-app \
  NetworkManager-wifi \
  NetworkManager-bluetooth

# Note: asahi-audio is already included in the Fedora Asahi Remix base image
# Note: apple-firmware-m1 is already included in the Fedora Asahi Remix base image
# Note: asahi-scripts is already included in the Fedora Asahi Remix base image

# Enable Bazzite COPRs
dnf5 -y copr enable ublue-os/bling || true
dnf5 -y install --skip-broken --skip-unavailable ublue-os-bling || true
dnf5 -y copr enable ublue-os/staging || true
dnf5 -y install --skip-broken --skip-unavailable ublue-update || true

# Enable gaming-related packages (where available for ARM64)
dnf5 -y install --skip-broken --skip-unavailable mangohud gamescope

# Add Flatpak repository and install basic apps
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
flatpak remote-add --if-not-exists fedora oci+https://registry.fedoraproject.org || true

# Install essential Flatpaks
flatpak install -y --noninteractive flathub com.github.tchx84.Flatseal || true
flatpak install -y --noninteractive flathub com.mattjakeman.ExtensionManager || true
flatpak install -y --noninteractive flathub org.mozilla.firefox || true

# Enable system services
systemctl enable podman.socket || true
systemctl enable power-profiles-daemon || true
systemctl enable thermald || true

# Setup apple-specific configurations
# These settings help optimize power and performance on Apple Silicon
echo "Setting up Apple Silicon specific configurations..."

# Enable power-saving features
mkdir -p /etc/systemd/system/power-profiles-daemon.service.d || true
cat > /etc/systemd/system/power-profiles-daemon.service.d/override.conf << EOF
[Service]
ExecStartPre=/usr/bin/sleep 2
EOF

# Create image info
mkdir -p /usr/share/ublue-os
cat > /usr/share/ublue-os/image-info.json << EOF
{
  "image-name": "${IMAGE_NAME:-bazzite-arm}",
  "image-flavor": "arm64-asahi",
  "image-vendor": "${IMAGE_VENDOR:-ublue-os}",
  "base-image-name": "${BASE_IMAGE_NAME:-silverblue}",
  "fedora-version": "${FEDORA_VERSION:-42}",
  "arch": "aarch64",
  "description": "Bazzite for Apple Silicon - Built on Fedora Asahi Remix"
}
EOF

# Cleanup
dnf5 -y copr disable ublue-os/staging || true
