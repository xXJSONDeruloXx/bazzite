#!/bin/bash
# Setup x86 emulation on ARM64 using Box86 and Box64
set -eo pipefail

echo "Setting up x86 emulation for ARM64..."

# Create directory for Box86/Box64 repositories
mkdir -p /etc/yum.repos.d

# Add Box86/Box64 repository
cat > /etc/yum.repos.d/box86-box64.repo << 'EOF'
[box86-box64]
name=Box86/Box64 for ARM64
baseurl=https://ryanfortner.github.io/box64-debs/debian/
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOF

# Install Box86 and Box64 for x86 and x86_64 emulation
dnf5 install -y --skip-broken --skip-unavailable box86-linux box64-linux

# Install binfmt_misc setup
cat > /etc/binfmt.d/box86.conf << 'EOF'
:box86:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00:\xff\xff\xff\xff\xff\xff\xff\xfc\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/box86:CF
EOF

cat > /etc/binfmt.d/box64.conf << 'EOF'
:box64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xff\xff\xfc\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/box64:CF
EOF

# Create just command script for managing x86 emulation
mkdir -p /usr/share/ublue-os/just
cat > /usr/share/ublue-os/just/82-bazzite-x86emu.just << 'EOF'
vim: set ft=make :

# Box86/Box64 x86 emulation management

# Toggle x86 emulation (Box86/Box64)
toggle-x86-emulation:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    
    if [[ $(id -u) -eq 0 ]]; then
      echo "Please do not run this command as root"
      exit 1
    fi
    
    # Check if Box86/Box64 are enabled in the kernel
    BOX86_ENABLED=$(cat /proc/sys/fs/binfmt_misc/box86 2>/dev/null | grep enabled || echo "disabled")
    BOX64_ENABLED=$(cat /proc/sys/fs/binfmt_misc/box64 2>/dev/null | grep enabled || echo "disabled")
    
    if [[ "$BOX86_ENABLED" == *"enabled"* && "$BOX64_ENABLED" == *"enabled"* ]]; then
      echo "x86 emulation is currently ${green}enabled${n}"
      if confirm "Would you like to disable x86 emulation?"; then
        echo "Disabling x86 emulation..."
        sudo systemctl stop box86-binfmt.service || true
        sudo systemctl stop box64-binfmt.service || true
        sudo systemctl disable box86-binfmt.service || true
        sudo systemctl disable box64-binfmt.service || true
        echo "x86 emulation has been disabled. Reboot to apply changes."
      fi
    else
      echo "x86 emulation is currently ${red}disabled${n}"
      if confirm "Would you like to enable x86 emulation?"; then
        echo "Enabling x86 emulation..."
        sudo systemctl enable --now box86-binfmt.service || true
        sudo systemctl enable --now box64-binfmt.service || true
        echo "x86 emulation has been enabled."
      fi
    fi

# Install Wine x86 with box64/box86
install-wine-x86:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    
    if [[ $(id -u) -eq 0 ]]; then
      echo "Please do not run this command as root"
      exit 1
    fi
    
    # Check if Box86/Box64 are enabled
    BOX86_ENABLED=$(cat /proc/sys/fs/binfmt_misc/box86 2>/dev/null | grep enabled || echo "disabled")
    BOX64_ENABLED=$(cat /proc/sys/fs/binfmt_misc/box64 2>/dev/null | grep enabled || echo "disabled")
    
    if [[ "$BOX86_ENABLED" != *"enabled"* || "$BOX64_ENABLED" != *"enabled"* ]]; then
      echo "${red}Error:${n} x86 emulation is not enabled. Please run 'ujust toggle-x86-emulation' first."
      exit 1
    fi
    
    echo "Installing Wine for x86 emulation..."
    flatpak install -y --noninteractive flathub org.winehq.Wine
    
    echo "Wine has been installed. You can run x86 Windows applications using Box86/Box64."
    echo "For better performance with games, consider using the Bottles flatpak which has Box86/Box64 support."

# Install Bottles for Windows games
install-bottles:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    
    if [[ $(id -u) -eq 0 ]]; then
      echo "Please do not run this command as root"
      exit 1
    fi
    
    echo "Installing Bottles for Windows gaming..."
    flatpak install -y --noninteractive flathub com.usebottles.bottles
    
    echo "Bottles has been installed. You can manage Windows applications and games through it."
    echo "Make sure to enable Box86/Box64 in the Bottles preferences for x86 emulation."
EOF

# Create systemd services for binfmt_misc
cat > /etc/systemd/system/box86-binfmt.service << 'EOF'
[Unit]
Description=Box86 binfmt registration
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/update-binfmts --enable box86
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/box64-binfmt.service << 'EOF'
[Unit]
Description=Box64 binfmt registration
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/update-binfmts --enable box64
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Update the ujust script imports to include the x86 emulation features
echo "import \"/usr/share/ublue-os/just/82-bazzite-x86emu.just\"" >> /usr/share/ublue-os/justfile

# Set up optimal environment for Box86/Box64
cat > /etc/profile.d/box86_box64_env.sh << 'EOF'
# Environment variables for Box86/Box64
export BOX86_PATH=/usr/bin
export BOX64_PATH=/usr/bin
export BOX86_LD_LIBRARY_PATH=/usr/lib/arm-linux-gnueabihf:/usr/lib/i386-linux-gnu:/lib/i386-linux-gnu
export BOX64_LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu
EOF

# Enable the services (they will start on next boot)
systemctl enable box86-binfmt.service
systemctl enable box64-binfmt.service

echo "x86 emulation setup complete! Reboot to apply changes."
