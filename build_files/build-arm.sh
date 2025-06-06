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

# First, remove conflicting tuned-ppd package to allow power-profiles-daemon installation
dnf5 remove -y tuned-ppd || true

# Install packages with priority options to prefer regular Fedora packages over Asahi's when possible
dnf5 install -y --setopt=priority=100 --repo=fedora,updates --skip-broken --skip-unavailable \
  tmux \
  vim \
  htop \
  git \
  powertop \
  power-profiles-daemon \
  firefox \
  distrobox \
  podman \
  dconf-editor \
  gnome-tweaks \
  gnome-extensions-app \
  NetworkManager-wifi \
  NetworkManager-bluetooth \
  just \
  jq \
  qemu-user-static \
  binfmt-support \
  cabextract

# Check if thermald is available and install it
dnf5 list thermald &>/dev/null && dnf5 install -y thermald || echo "thermald package not available, skipping"

# Note: asahi-audio is already included in the Fedora Asahi Remix base image
# Note: apple-firmware-m1 is already included in the Fedora Asahi Remix base image
# Note: asahi-scripts is already included in the Fedora Asahi Remix base image

# Enable Bazzite COPRs
echo "Attempting to enable ublue-os/bling COPR repository..."
if dnf5 -y copr enable ublue-os/bling; then
    echo "Successfully enabled ublue-os/bling"
    dnf5 -y install --skip-broken --skip-unavailable ublue-os-bling || echo "ublue-os-bling package not available for ARM64"
else
    echo "Failed to enable ublue-os/bling COPR repository for ARM64"
    # Create a placeholder for ublue-os-bling to prevent dependencies from failing
    mkdir -p /usr/share/ublue-os/bling
    touch /usr/share/ublue-os/bling/README.md
    echo "This is a placeholder for ublue-os-bling which is not available for ARM64" > /usr/share/ublue-os/bling/README.md
fi

echo "Attempting to enable ublue-os/staging COPR repository..."
if dnf5 -y copr enable ublue-os/staging; then
    echo "Successfully enabled ublue-os/staging"
    dnf5 -y install --skip-broken --skip-unavailable ublue-update || echo "ublue-update package not available for ARM64"
else
    echo "Failed to enable ublue-os/staging COPR repository for ARM64"
    # Create a placeholder for ublue-update
    mkdir -p /usr/bin
    cat > /usr/bin/ublue-update << 'EOF'
#!/bin/bash
echo "ublue-update is not available for ARM64, this is a placeholder script"
echo "Running system update instead"
rpm-ostree update
EOF
    chmod +x /usr/bin/ublue-update
fi

# Enable gaming-related packages (where available for ARM64)
dnf5 -y install --skip-broken --skip-unavailable mangohud gamescope

# Add Flatpak repository and install basic apps
# Configure Flatpak to work properly in container builds
mkdir -p /var/roothome || true
echo "kernel.unprivileged_userns_clone=1" > /etc/sysctl.d/flatpak.conf

# Add Flatpak remotes
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
flatpak remote-add --if-not-exists fedora oci+https://registry.fedoraproject.org || true

# Install essential Flatpaks
# Using --system to ensure system-wide installation
# Adding environment variables to help with sandbox issues
export FLATPAK_SYSTEM_DIR=/var/lib/flatpak
export FLATPAK_SYSTEM_HELPER_ON_SESSION=1

# Install Flatpaks with error handling
echo "Installing Flatseal..."
flatpak install -y --noninteractive --system flathub com.github.tchx84.Flatseal || echo "Failed to install Flatseal, will be installed on first boot"

echo "Installing Extension Manager..."
flatpak install -y --noninteractive --system flathub com.mattjakeman.ExtensionManager || echo "Failed to install Extension Manager, will be installed on first boot"

echo "Installing Firefox..."
flatpak install -y --noninteractive --system flathub org.mozilla.firefox || echo "Failed to install Firefox, will be installed on first boot"

# Create script to install Flatpaks on first boot
mkdir -p /usr/lib/bazzite/scripts
cat > /usr/lib/bazzite/scripts/install-flatpaks.sh << 'EOF'
#!/bin/bash
# Install essential Flatpaks on first boot if they failed during build
echo "Checking and installing essential Flatpaks..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y --noninteractive flathub com.github.tchx84.Flatseal
flatpak install -y --noninteractive flathub com.mattjakeman.ExtensionManager
flatpak install -y --noninteractive flathub org.mozilla.firefox
EOF
chmod +x /usr/lib/bazzite/scripts/install-flatpaks.sh

# Create a systemd service to run the script on first boot
mkdir -p /etc/systemd/system
cat > /etc/systemd/system/bazzite-first-boot-flatpaks.service << 'EOF'
[Unit]
Description=Install essential Flatpaks on first boot
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/bazzite/flatpaks-installed

[Service]
Type=oneshot
ExecStart=/usr/lib/bazzite/scripts/install-flatpaks.sh
ExecStartPost=/usr/bin/mkdir -p /var/lib/bazzite
ExecStartPost=/usr/bin/touch /var/lib/bazzite/flatpaks-installed

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl enable bazzite-first-boot-flatpaks.service || true

# Enable system services with error handling
echo "Enabling system services..."
systemctl enable podman.socket || echo "Failed to enable podman.socket"

# Check if power-profiles-daemon service exists before enabling
if systemctl list-unit-files | grep -q power-profiles-daemon.service; then
  systemctl enable power-profiles-daemon || echo "Failed to enable power-profiles-daemon"
else
  echo "power-profiles-daemon service not found, skipping enablement"
fi

# Check if thermald service exists before enabling
if systemctl list-unit-files | grep -q thermald.service; then
  systemctl enable thermald || echo "Failed to enable thermald"
else
  echo "thermald service not found, skipping enablement"
fi

# Set up the ujust system
echo "Setting up the ujust system for ARM64..."

# Create necessary directories
mkdir -p /usr/lib/ujust
mkdir -p /usr/share/ublue-os/just

# Create the ujust.sh script
cat > /usr/lib/ujust/ujust.sh << 'EOF'
#!/bin/bash
# ujust.sh - Basic shell utilities for Bazzite just scripts

# Colors for terminal output
export red='\033[0;31m'
export green='\033[0;32m'
export blue='\033[0;34m'
export cyan='\033[0;36m'
export yellow='\033[0;33m'
export bold='\033[1m'
export normal='\033[0m'

# Simple function for displaying colorful status messages
status() {
    echo -e "${bold}${blue}:: ${normal}${bold}$1${normal}"
}

# Error message display
error() {
    echo -e "${bold}${red}Error: ${normal}${bold}$1${normal}" >&2
}

# Warning message display
warning() {
    echo -e "${bold}${yellow}Warning: ${normal}${bold}$1${normal}"
}

# Success message display
success() {
    echo -e "${bold}${green}Success: ${normal}${bold}$1${normal}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to prompt for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        local prompt_text="[Y/n]"
    else
        local prompt_text="[y/N]"
    fi
    
    echo -e -n "${bold}${blue}:: ${normal}${bold}$prompt $prompt_text ${normal}"
    read -r response
    
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This command must be run as root."
        return 1
    fi
    return 0
}
EOF

chmod +x /usr/lib/ujust/ujust.sh

# Create the ujust command wrapper
cat > /usr/bin/ujust << 'EOF'
#!/bin/bash
# ujust - User-friendly wrapper for the just command

# Set the just directory path
JUST_DIR="/usr/share/ublue-os"

# Change to the just directory
cd "$JUST_DIR" || { echo "Error: Cannot access $JUST_DIR"; exit 1; }

# If no arguments, list available recipes
if [ $# -eq 0 ]; then
    echo "Available commands:"
    just --list
    exit 0
fi

# Forward all arguments to just
exec just "$@"
EOF

chmod +x /usr/bin/ujust

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
  "description": "Bazzite for Apple Silicon - Built on Fedora Asahi Remix with x86 emulation support"
}
EOF

# Cleanup
dnf5 -y copr disable ublue-os/staging || true
