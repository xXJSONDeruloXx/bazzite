# vim: set ft=make :

# Switch between Steam and OpenGamepadUI as the gamescope session launcher  
setup-opengamepadui ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh

    # Check current session configuration via systemd mount status
    CURRENT_SESSION="Steam"
    if systemctl is-active --quiet usr-share-wayland\\x2dsessions.mount; then
        CURRENT_SESSION="OpenGamepadUI"  
    fi

    OPTION="{{ ACTION }}"
    if [ "$OPTION" == "help" ]; then
        echo "Usage: ujust setup-opengamepadui <option>"
        echo "  <option>: Specify the option to skip the interactive prompt"
        echo "  Use 'steam' to switch to Steam as the gamescope session launcher"
        echo "  Use 'opengamepadui' to switch to OpenGamepadUI as the gamescope session launcher"  
        echo "  Use 'install' to install OpenGamepadUI"
        echo "  Use 'status' to check current gamescope session launcher"
        exit 0
    elif [ "$OPTION" == "status" ]; then
        echo "Current gamescope session launcher: ${bold}${green}$CURRENT_SESSION${normal}"
        exit 0
    elif [ "$OPTION" == "" ]; then
        echo ""
        echo "${bold}Bazzite OpenGamepadUI Setup${normal}"
        echo ""
        echo "${bold}Current gamescope session launcher:${normal} ${green}$CURRENT_SESSION${normal}"
        echo ""
        echo "This utility allows you to switch between Steam and OpenGamepadUI"
        echo "as your primary gamepad-driven interface in gamescope session mode."
        echo ""
        echo "What would you like to do?"
        echo ""
        OPTION=$(ugum choose \\
            "Switch to Steam session" \\
            "Switch to OpenGamepadUI session" \\
            "Install OpenGamepadUI" \\
            "Exit without changes")
    fi
    
    case "$OPTION" in
        "Switch to Steam session"|steam)
            if [[ "$CURRENT_SESSION" == "Steam" ]]; then
                echo "Steam is already configured as the gamescope session launcher."
                exit 0
            fi
            
            echo "Switching to Steam as the gamescope session launcher..."
            
            # Disable the OpenGamepadUI session overlay
            sudo systemctl disable --now usr-share-wayland\\x2dsessions.mount 2>/dev/null || true
            
            # Use steamos-session-select for consistency
            if command -v steamos-session-select >/dev/null 2>&1; then
                steamos-session-select gamescope
            else
                echo "${red}${bold}Error:${normal} steamos-session-select not found."
                exit 1
            fi
            
            echo "${bold}${green}Successfully switched to Steam!${normal}"
            echo "Changes will take effect on next session start."
            ;;
            
        "Switch to OpenGamepadUI session"|opengamepadui)
            if [[ "$CURRENT_SESSION" == "OpenGamepadUI" ]]; then
                echo "OpenGamepadUI is already configured as the gamescope session launcher."
                exit 0
            fi

            # Check if OpenGamepadUI is installed
            if ! command -v opengamepadui >/dev/null 2>&1; then
                echo "${red}${bold}Error:${normal} OpenGamepadUI is not installed."
                echo "Please install OpenGamepadUI first by selecting the install option."
                exit 1
            fi

            echo "Switching to OpenGamepadUI as the gamescope session launcher..."

            # Ensure the overlay directories exist
            sudo mkdir -p /var/opengamepadui_session/wayland-sessions /var/opengamepadui_session/wayland-sessions.work
            
            # Copy the official gamescope-session-opengamepadui desktop file to the overlay
            if ! sudo cp /usr/share/wayland-sessions/gamescope-session-opengamepadui.desktop /var/opengamepadui_session/wayland-sessions/ 2>/dev/null; then
                                    echo "${red}${bold}Error:${normal} Failed to download or install OpenGamepadUI systemd extension."
                exit 1
            fi            # Enable the overlay mount
            if ! sudo systemctl enable --now usr-share-wayland\\x2dsessions.mount; then
                echo "${red}${bold}Error:${normal} Failed to enable OpenGamepadUI session overlay."
                echo "Please check systemd logs: sudo journalctl -u usr-share-wayland\\\\x2dsessions.mount"
                exit 1
            fi

            # Switch to the OpenGamepadUI session
            if command -v steamos-session-select >/dev/null 2>&1; then
                if ! steamos-session-select opengamepadui; then
                    echo "${red}${bold}Error:${normal} Failed to switch session. This may require manual session switching."
                    echo "You can try logging out and selecting OpenGamepadUI from the login screen."
                fi
            else
                echo "${red}${bold}Error:${normal} steamos-session-select not found."
                exit 1
            fi

            echo "${bold}${green}Successfully switched to OpenGamepadUI!${normal}"
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

                    echo "${bold}${green}OpenGamepadUI installation completed!${normal}"
                    echo "You can now switch to OpenGamepadUI using this script."
                else
                    echo "${red}${bold}Error:${normal} Could not find OpenGamepadUI systemd extension in releases."
                    exit 1
                fi
            fi

            echo "${bold}${green}Installation completed successfully!${normal}"
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

    {
        echo "[Desktop Entry]"
        echo "Name=Return to OpenGamepadUI"
        echo "Comment=Switch back to OpenGamepadUI session"
        echo "Exec=/usr/bin/return-to-opengamepadui"
        echo "Icon=applications-games"
        echo "Terminal=false"
        echo "Type=Application"
        echo "Categories=Game"
        echo "StartupNotify=true"
    } > "$DESKTOP_FILE"

    chmod +x "$DESKTOP_FILE"
    echo "${bold}${green}Desktop shortcut created successfully!${normal}"
    echo "You can now use this shortcut to return to OpenGamepadUI from desktop mode."
