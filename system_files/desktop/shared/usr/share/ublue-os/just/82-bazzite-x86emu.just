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

# Install Steam with Box86/Box64 support
install-steam-x86:
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
    
    echo "Installing Steam with Box86/Box64 support..."
    flatpak install -y --noninteractive flathub com.valvesoftware.Steam
    
    echo "Steam has been installed. Not all games will work, but many x86 games can run via Box86/Box64."
    echo "For better performance, consider using Proton GE with native ARM-compiled Proton libraries."

# Install Lutris with Box86/Box64 support
install-lutris-x86:
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
    
    echo "Installing Lutris with Box86/Box64 support..."
    flatpak install -y --noninteractive flathub net.lutris.Lutris
    
    echo "Lutris has been installed. You can manage many games through it with Box86/Box64 support."
    echo "Some games may require additional configuration to work properly with x86 emulation."
