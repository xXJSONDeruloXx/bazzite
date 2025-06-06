#!/usr/bin/env bash
# ARM build script with x86 emulation fallback support
# This script attempts to install ARM packages first, then falls back to x86 with emulation

set -eou pipefail

# Source the common build functions
if [ -f /tmp/build-functions.sh ]; then
    source /tmp/build-functions.sh
fi

# Platform detection
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "This script is intended for ARM64 builds only"
    exit 1
fi

echo "Starting ARM build with x86 emulation fallback support..."

# Set up package installation strategy
install_package_with_fallback() {
    local package_name="$1"
    local description="${2:-$package_name}"
    
    echo "Installing $description..."
    
    # Try ARM native first
    if dnf install -y "$package_name" 2>/dev/null; then
        echo "✓ Installed $package_name (ARM native)"
        return 0
    fi
    
    # Try noarch packages
    if dnf install -y --forcearch=noarch "$package_name" 2>/dev/null; then
        echo "✓ Installed $package_name (noarch)"
        return 0
    fi
    
    # Fall back to x86_64 with emulation warning
    echo "⚠ ARM version not available for $package_name, attempting x86_64 with emulation..."
    if dnf install -y --forcearch=x86_64 "$package_name" 2>/dev/null; then
        echo "✓ Installed $package_name (x86_64 with emulation)"
        
        # Create emulation wrapper if it's a binary package
        create_emulation_wrapper "$package_name"
        return 0
    fi
    
    echo "✗ Failed to install $package_name on any architecture"
    return 1
}

create_emulation_wrapper() {
    local package_name="$1"
    
    # Get list of binaries installed by the package
    local binaries
    binaries=$(dnf repoquery --list "$package_name" 2>/dev/null | grep -E '^/(usr/)?bin/' | grep -v '/$' || true)
    
    for binary in $binaries; do
        if [ -f "$binary" ] && [ -x "$binary" ]; then
            # Check if it's an x86_64 binary
            if file "$binary" | grep -q "x86-64"; then
                # Create wrapper
                local wrapper_path="${binary}.x86"
                mv "$binary" "$wrapper_path"
                
                cat > "$binary" << WRAPPER_EOF
#!/bin/bash
# Auto-generated emulation wrapper for x86_64 binary
exec /usr/local/bin/run-x86 "$wrapper_path" "\$@"
WRAPPER_EOF
                chmod +x "$binary"
                echo "Created emulation wrapper for $binary"
            fi
        fi
    done
}

# Set up repositories
echo "Setting up repositories..."

# Add Fedora repositories
dnf config-manager --set-enabled fedora updates

# Add RPM Fusion for ARM if available
if ! dnf install -y --forcearch=noarch rpmfusion-free-release rpmfusion-nonfree-release 2>/dev/null; then
    echo "RPM Fusion not available for ARM, using x86_64 version"
    dnf install -y --forcearch=x86_64 rpmfusion-free-release rpmfusion-nonfree-release || true
fi

# Core system packages
echo "Installing core system packages..."
install_package_with_fallback "git" "Git version control"
install_package_with_fallback "curl" "cURL"
install_package_with_fallback "wget" "wget"
install_package_with_fallback "unzip" "unzip"
install_package_with_fallback "tar" "tar"

# Development tools
echo "Installing development tools..."
install_package_with_fallback "gcc" "GCC compiler"
install_package_with_fallback "make" "Make build tool"
install_package_with_fallback "cmake" "CMake"
install_package_with_fallback "python3-pip" "Python pip"

# Gaming-specific packages
echo "Installing gaming packages..."

# Steam (x86_64 only, requires emulation)
if ! install_package_with_fallback "steam"; then
    echo "Steam installation failed, creating placeholder"
    mkdir -p /usr/lib/steam
    echo "Steam requires manual installation on ARM64" > /usr/lib/steam/README
fi

# Wine (try ARM64 version first)
install_package_with_fallback "wine" "Wine compatibility layer"

# Lutris
install_package_with_fallback "lutris" "Lutris gaming platform"

# GameMode
install_package_with_fallback "gamemode" "GameMode performance optimization"

# Gaming libraries
install_package_with_fallback "mesa-dri-drivers" "Mesa DRI drivers"
install_package_with_fallback "vulkan-loader" "Vulkan loader"
install_package_with_fallback "vulkan-tools" "Vulkan tools"

# Audio support
echo "Installing audio support..."
install_package_with_fallback "pipewire" "PipeWire audio system"
install_package_with_fallback "pipewire-alsa" "PipeWire ALSA support"
install_package_with_fallback "pipewire-pulseaudio" "PipeWire PulseAudio support"
install_package_with_fallback "pipewire-jack-audio-connection-kit" "PipeWire JACK support"

# Desktop environment enhancements
echo "Installing desktop enhancements..."
install_package_with_fallback "firefox" "Firefox browser"
install_package_with_fallback "thunderbird" "Thunderbird email client"
install_package_with_fallback "libreoffice" "LibreOffice office suite"

# Multimedia codecs
echo "Installing multimedia codecs..."
install_package_with_fallback "ffmpeg" "FFmpeg multimedia framework"
install_package_with_fallback "gstreamer1-plugins-bad-free" "GStreamer plugins"
install_package_with_fallback "gstreamer1-plugins-good" "GStreamer plugins"
install_package_with_fallback "gstreamer1-plugins-ugly-free" "GStreamer plugins"

# Container and virtualization support
echo "Installing container support..."
install_package_with_fallback "podman" "Podman container engine"
install_package_with_fallback "distrobox" "Distrobox container utility"

# Gaming controllers and input devices
echo "Installing input device support..."
install_package_with_fallback "xpadneo" "Xbox controller support" || true
install_package_with_fallback "steam-devices" "Steam controller support" || true

# Hardware acceleration (ARM-specific)
echo "Installing ARM-specific hardware acceleration..."
install_package_with_fallback "mesa-dri-drivers" "Mesa drivers"

# Apple Silicon specific packages (if available)
if grep -qi "asahi" /etc/os-release 2>/dev/null; then
    echo "Detected Asahi Linux, installing Apple Silicon specific packages..."
    install_package_with_fallback "asahi-audio" "Asahi audio support"
    install_package_with_fallback "asahi-gpu-driver" "Asahi GPU driver" || true
fi

# Bazzite-specific configurations
echo "Applying Bazzite configurations..."

# Create bazzite user configurations
mkdir -p /etc/skel/.config
mkdir -p /etc/skel/.local/share

# Gaming environment setup
cat > /etc/skel/.profile << 'PROFILE_EOF'
# Bazzite ARM gaming environment setup
export BAZZITE_ARCH=arm64
export BOX64_DYNAREC_BIGBLOCK=1
export BOX64_DYNAREC_STRONGMEM=1
export BOX64_DYNAREC_FASTNAN=1
export BOX64_DYNAREC_FASTROUND=1
export BOX64_WINE=1

# Add emulation wrapper to PATH
export PATH="/usr/local/bin:$PATH"

# Steam environment for ARM
export STEAM_RUNTIME=1
export STEAM_RUNTIME_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu
PROFILE_EOF

# Create desktop files for emulated applications
mkdir -p /usr/share/applications

# Steam desktop file with emulation
cat > /usr/share/applications/steam-emulated.desktop << 'STEAM_DESKTOP_EOF'
[Desktop Entry]
Name=Steam (Emulated)
Comment=Application for managing and playing games on Steam (x86_64 emulation)
Exec=steam %U
Icon=steam
Terminal=false
NoDisplay=false
Type=Application
Categories=Network;FileTransfer;Game;
MimeType=x-scheme-handler/steam;
PrefersNonDefaultGPU=true
X-KDE-RunOnDiscreteGpu=true
STEAM_DESKTOP_EOF

# Update desktop database
update-desktop-database /usr/share/applications/ || true

# Set up systemd services for gaming
echo "Setting up systemd services..."

# GameMode service
systemctl enable gamemode || true

# Create Bazzite welcome script
cat > /usr/bin/bazzite-welcome << 'WELCOME_EOF'
#!/bin/bash
echo "Welcome to Bazzite ARM64!"
echo "This image includes x86_64 emulation support for gaming compatibility."
echo "Some applications may run slower due to emulation overhead."
echo ""
echo "Gaming tips for ARM64:"
echo "- Native ARM64 games will perform best"
echo "- x86_64 games run through emulation (box64/qemu)"
echo "- Use 'distrobox' for x86_64 application containers"
echo ""
echo "For support, visit: https://github.com/ublue-os/bazzite"
WELCOME_EOF
chmod +x /usr/bin/bazzite-welcome

# Set up first-boot services
mkdir -p /etc/systemd/system
cat > /etc/systemd/system/bazzite-firstboot.service << 'FIRSTBOOT_EOF'
[Unit]
Description=Bazzite First Boot Setup
After=graphical-session.target
ConditionPathExists=!/var/lib/bazzite-firstboot-done

[Service]
Type=oneshot
ExecStart=/usr/bin/bazzite-welcome
ExecStartPost=/usr/bin/touch /var/lib/bazzite-firstboot-done
RemainAfterExit=true

[Install]
WantedBy=graphical-session.target
FIRSTBOOT_EOF

systemctl enable bazzite-firstboot.service || true

# Final cleanup
echo "Performing final cleanup..."
dnf clean all
rm -rf /tmp/* || true
rm -rf /var/cache/dnf/* || true

echo "ARM build with emulation support completed successfully!"
echo "Summary of emulation setup:"
echo "- qemu-user-static: For basic x86_64 binary execution"
echo "- box64: For enhanced x86_64 application compatibility" 
echo "- Automatic wrappers created for x86_64 binaries"
echo "- Gaming environment configured with emulation support"
