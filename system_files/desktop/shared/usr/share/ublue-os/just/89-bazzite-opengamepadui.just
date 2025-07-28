# vim: set ft=make :

# Switch between Steam and OpenGamepadUI as the gamescope session launcher
setup-opengamepadui ACTION="prompt":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    OPTION={{ ACTION }}
    
    # Check current session configuration via systemd mount status
    CURRENT_SESSION="Steam"
    if systemctl is-active --quiet usr-share-wayland-sessions-opengamepadui.mount; then
        CURRENT_SESSION="OpenGamepadUI"
    fi
    
    if [ "$OPTION" == "help" ]; then
        echo "Usage: ujust setup-opengamepadui <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'steam' to switch to Steam as the gamescope session launcher"
        echo "  Use 'opengamepadui' to switch to OpenGamepadUI as the gamescope session launcher"  
        echo "  Use 'install' to install OpenGamepadUI"
        echo "  Use 'status' to check current gamescope session launcher"
        echo "  Use 'exit' to exit without making changes"
        exit 0
    elif [ "$OPTION" == "status" ]; then
        echo "Current gamescope session launcher: ${b}${green}$CURRENT_SESSION${n}"
        exit 0
    elif [ "$OPTION" == "" ]; then
        echo "${b}Bazzite OpenGamepadUI Setup${n}"
        echo "Current gamescope session launcher: ${b}${green}$CURRENT_SESSION${n}"
        echo ""
        echo "This utility allows you to switch between Steam and OpenGamepadUI"
        echo "as your primary gamepad-driven interface in gamescope session mode."
        echo ""
        echo "What would you like to do?"
        OPTION=$(ugum choose \
            "Switch to Steam" \
            "Switch to OpenGamepadUI" \
            "Install OpenGamepadUI" \
            "Exit without changes")
    fi
    
    case "$OPTION" in
        "Switch to Steam" | "steam")
            if [[ "$CURRENT_SESSION" == "Steam" ]]; then
                echo "Steam is already configured as the gamescope session launcher."
                exit 0
            fi
            
            echo "Switching to Steam as the gamescope session launcher..."
            
            # Disable the OpenGamepadUI session overlay
            sudo systemctl disable --now usr-share-wayland-sessions-opengamepadui.mount 2>/dev/null || true
            
            # Use steamos-session-select for consistency
            if command -v steamos-session-select >/dev/null 2>&1; then
                steamos-session-select gamescope
            else
                echo "${red}${b}Error:${n} steamos-session-select not found."
                exit 1
            fi
            
            echo "${b}${green}Successfully switched to Steam!${n}"
            echo "Changes will take effect on next session start."
            ;;
            
        "Switch to OpenGamepadUI" | "opengamepadui")
            if [[ "$CURRENT_SESSION" == "OpenGamepadUI" ]]; then
                echo "OpenGamepadUI is already configured as the gamescope session launcher."
                exit 0
            fi
            
            # Check if OpenGamepadUI is installed
            if ! command -v opengamepadui >/dev/null 2>&1; then
                echo "${red}${b}Error:${n} OpenGamepadUI is not installed."
                echo "Please install OpenGamepadUI first by selecting the install option."
                exit 1
            fi
            
            echo "Switching to OpenGamepadUI as the gamescope session launcher..."
            
            # Ensure the overlay directories exist
            sudo mkdir -p /var/opengamepadui_session/wayland-sessions /var/opengamepadui_session/wayland-sessions.work
            
            # Use the official gamescope-session-opengamepadui desktop file
            # Create the OpenGamepadUI session file in the overlay based on the official session
            sudo bash -c 'cat > /var/opengamepadui_session/wayland-sessions/gamescope-session-opengamepadui.desktop << "EOF"
[Desktop Entry]
Exec=/usr/bin/gamescope-session-plus opengamepadui
TryExec=/usr/bin/gamescope-session-plus
DesktopNames=OpenGamepadUI
Name=OpenGamepadUI (Gamescope Session)
Comment=OpenGamepadUI running in a Gamescope session for gamepad-driven gaming
EOF'
            
            # Enable the overlay mount
            sudo systemctl enable --now usr-share-wayland-sessions-opengamepadui.mount
            
            # Switch to the OpenGamepadUI session
            if command -v steamos-session-select >/dev/null 2>&1; then
                steamos-session-select opengamepadui
            else
                echo "${red}${b}Error:${n} steamos-session-select not found."
                exit 1
            fi
            
            echo "${b}${green}Successfully switched to OpenGamepadUI!${n}"
            echo "Changes will take effect on next session start."
            ;;
            
        "Install OpenGamepadUI" | "install")
            echo "Installing OpenGamepadUI..."
            
            # Check if we're on Steam Deck for the special installer
            if /usr/libexec/hwsupport/valve-hardware; then
                echo "Detected Steam Deck hardware. Using Steam Deck installation method..."
                
                # Download and run the official Steam Deck installer
                TEMP_DIR=$(mktemp -d)
                cd "$TEMP_DIR"
                curl -L https://raw.githubusercontent.com/ShadowBlip/OpenGamepadUI/main/docs/install/deck_install_script.sh -o deck_install_script.sh
                chmod +x deck_install_script.sh
                ./deck_install_script.sh
                cd - >/dev/null
                rm -rf "$TEMP_DIR"
                
            else
                echo "Installing OpenGamepadUI using systemd extension method..."
                echo "This is suitable for immutable systems like Bazzite."
                
                # Create extension directory
                mkdir -p ~/.var/lib/extensions
                sudo ln -sf $HOME/.var/lib/extensions /var/lib/extensions 2>/dev/null || true
                
                # Download the latest OpenGamepadUI systemd extension
                LATEST_URL=$(curl -s https://api.github.com/repos/ShadowBlip/OpenGamepadUI/releases/latest | jq -r '.assets[] | select(.name | endswith(".raw")) | .browser_download_url')
                
                if [[ -n "$LATEST_URL" ]]; then
                    echo "Downloading OpenGamepadUI systemd extension..."
                    curl -L "$LATEST_URL" -o ~/.var/lib/extensions/opengamepadui.raw
                    
                    # Install systemd-sysext-updater service
                    mkdir -p ~/.config/systemd/user ~/.local/bin
                    curl -L https://raw.githubusercontent.com/ShadowBlip/OpenGamepadUI/main/rootfs/usr/lib/systemd/user/systemd-sysext-updater.service -o ~/.config/systemd/user/systemd-sysext-updater.service
                    curl -L https://raw.githubusercontent.com/ShadowBlip/OpenGamepadUI/main/rootfs/usr/share/opengamepadui/scripts/update_systemd_ext.sh -o ~/.local/bin/update_systemd_ext.sh
                    chmod +x ~/.local/bin/update_systemd_ext.sh
                    ~/.local/bin/update_systemd_ext.sh
                    systemctl --user enable systemd-sysext-updater
                    systemctl --user start systemd-sysext-updater
                    
                    # Enable systemd-sysext
                    sudo systemctl enable systemd-sysext
                    sudo systemctl start systemd-sysext
                    
                    # Force refresh if needed
                    sudo systemd-sysext refresh --force
                    
                    echo "${b}${green}OpenGamepadUI installation completed!${n}"
                    echo "You can now switch to OpenGamepadUI using this script."
                else
                    echo "${red}${b}Error:${n} Could not find OpenGamepadUI systemd extension in releases."
                    exit 1
                fi
            fi
            
            echo "${b}${green}Installation completed successfully!${n}"
            echo "You can now switch to OpenGamepadUI session."
            ;;
            
        "Exit without changes" | "exit")
            echo "No changes made."
            ;;
            
        *)
            echo "Invalid option. Please run 'ujust setup-opengamepadui help' for usage information."
            exit 1
            ;;
    esac

# Create desktop shortcut to return to OpenGamepadUI from desktop mode
create-opengamepadui-shortcut:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    
    DESKTOP_FILE="$HOME/Desktop/Return-to-OpenGamepadUI.desktop"
    
    if [[ -f "$DESKTOP_FILE" ]]; then
        echo "OpenGamepadUI desktop shortcut already exists."
        exit 0
    fi
    
    echo "Creating desktop shortcut to return to OpenGamepadUI..."
    
    cat > "$DESKTOP_FILE" << 'EOF'
[Desktop Entry]
Name=Return to OpenGamepadUI
Comment=Switch back to OpenGamepadUI session
Exec=/usr/bin/return-to-opengamepadui
Icon=applications-games
Terminal=false
Type=Application
Categories=Game;
StartupNotify=true
EOF
    
    chmod +x "$DESKTOP_FILE"
    echo "${b}${green}Desktop shortcut created successfully!${n}"
    echo "You can now use this shortcut to return to OpenGamepadUI from desktop mode."
