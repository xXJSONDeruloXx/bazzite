# vim: set ft=make :

# Install ClairObscurFix for Expedition 33
patch-expedition33:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    
    # Set up temporary directory
    TMP_DIR=$(mktemp -d)
    
    # Get latest release information from Codeberg API
    echo "Fetching latest ClairObscurFix release information..."
    if ! command -v curl &>/dev/null; then
        echo "${red}Error: curl is required but not installed.${normal}"
        echo "Please install curl and try again."
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    LATEST_RELEASE=$(curl -s "https://codeberg.org/api/v1/repos/Lyall/ClairObscurFix/releases?limit=1" | grep -o '"tag_name":"[^"]*' | head -1 | cut -d'"' -f4)
    
    if [ -z "$LATEST_RELEASE" ]; then
        echo "${red}Error: Could not determine the latest release version.${normal}"
        echo "Falling back to a known version (0.0.12)..."
        LATEST_RELEASE="0.0.12"
    fi
    
    # Remove the 'v' prefix if present
    LATEST_VERSION=${LATEST_RELEASE#v}
    
    # Download the ClairObscurFix zip file
    echo "Downloading ClairObscurFix version ${LATEST_VERSION}..."
    DOWNLOAD_URL="https://codeberg.org/Lyall/ClairObscurFix/releases/download/${LATEST_RELEASE}/ClairObscurFix_${LATEST_VERSION}.zip"
    
    # Download with progress indicator
    if ! wget -O "$TMP_DIR/ClairObscurFix.zip" "$DOWNLOAD_URL"; then
        echo "${red}Error: Failed to download ClairObscurFix.${normal}"
        echo "Check your internet connection and try again."
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # Try to find Expedition 33 installation folder
    # Default Steam location
    STEAM_DIR="$HOME/.local/share/Steam"
    GAME_DIR=""
    
    # Search for the game in default Steam library location
    echo "Searching for Expedition 33 installation..."
    DEFAULT_LOCATION="$STEAM_DIR/steamapps/common/Expedition 33"
    if [ -d "$DEFAULT_LOCATION" ]; then
        GAME_DIR="$DEFAULT_LOCATION"
    else
        # Look in Steam library folders
        if [ -f "$STEAM_DIR/steamapps/libraryfolders.vdf" ]; then
            LIBRARY_FILE="$STEAM_DIR/steamapps/libraryfolders.vdf"
            # Extract library paths from libraryfolders.vdf
            LIBRARIES=($(grep '"path"' "$LIBRARY_FILE" | sed -E 's/.*"path".*"(.*)".*/\1/g' | sed 's/\\\\//g'))
            for LIBRARY in "${LIBRARIES[@]}"; do
                POSSIBLE_LOCATION="$LIBRARY/steamapps/common/Expedition 33"
                if [ -d "$POSSIBLE_LOCATION" ]; then
                    GAME_DIR="$POSSIBLE_LOCATION"
                    break
                fi
            done
        fi
    fi
    
    # If game directory wasn't found automatically, ask the user
    if [ -z "$GAME_DIR" ]; then
        echo "Could not automatically find Expedition 33 installation directory."
        echo "Please enter the full path to your Expedition 33 installation:"
        read -r GAME_DIR
        
        # Verify the path exists
        if [ ! -d "$GAME_DIR" ]; then
            echo "${red}Error: The specified directory does not exist.${normal}"
            echo "Fix not installed. Please make sure Expedition 33 is installed and try again."
            rm -rf "$TMP_DIR"
            exit 1
        fi
    fi
    
    # Verify this is the correct game directory
    if [ ! -d "$GAME_DIR/Sandfall" ]; then
        echo "${red}Error: The directory does not appear to be a valid Expedition 33 installation.${normal}"
        echo "The directory should contain a 'Sandfall' folder."
        
        # Ask if user wants to proceed anyway
        echo "Do you want to proceed anyway?"
        OPTION=$(ugum choose "Yes" "No")
        if [ "$OPTION" == "No" ]; then
            echo "Fix not installed. Exiting."
            rm -rf "$TMP_DIR"
            exit 1
        fi
    fi
    
    # Create the correct mod installation directory if it doesn't exist
    MOD_DIR="$GAME_DIR/Sandfall/Binaries/Win64"
    if [ ! -d "$MOD_DIR" ]; then
        echo "Creating mod installation directory..."
        mkdir -p "$MOD_DIR"
    fi
    
    # Extract the zip file to the correct directory
    echo "Installing ClairObscurFix to $MOD_DIR..."
    unzip -o "$TMP_DIR/ClairObscurFix.zip" -d "$MOD_DIR"
    
    # Verify mod files were installed correctly
    if [ ! -f "$MOD_DIR/ClairObscurFix.asi" ] || [ ! -f "$MOD_DIR/ClairObscurFix.ini" ] || [ ! -f "$MOD_DIR/dsound.dll" ]; then
        echo "${red}Error: Some mod files failed to install correctly.${normal}"
        echo "Please check if the files are present in $MOD_DIR:"
        echo "- ClairObscurFix.asi"
        echo "- ClairObscurFix.ini"
        echo "- dsound.dll"
    else
        echo "${green}All mod files were installed correctly.${normal}"
    fi
    
    # Clean up
    rm -rf "$TMP_DIR"
    
    # Check for the Engine.ini directory and create it if it doesn't exist
    INI_DIR="$GAME_DIR/Sandfall/Saved/Config/WindowsNoEditor"
    INI_FILE="$INI_DIR/Engine.ini"
    
    if [ ! -d "$INI_DIR" ]; then
        echo "Creating configuration directory structure..."
        mkdir -p "$INI_DIR"
    fi
    
    # Create or backup Engine.ini
    if [ -f "$INI_FILE" ]; then
        if [ ! -f "${INI_FILE}.bak" ]; then
            cp "$INI_FILE" "${INI_FILE}.bak"
            echo "Created backup of original Engine.ini as ${INI_FILE}.bak"
        fi
    else
        # Create a basic Engine.ini if it doesn't exist
        echo "Engine.ini not found, creating a basic configuration file..."
        echo '[Core.System]' > "$INI_FILE"
        echo 'Paths=../../../Engine/Content' >> "$INI_FILE"
        echo 'Paths=%GAMEDIR%Content' >> "$INI_FILE"
        echo 'Paths=../../../Engine/Plugins/Runtime/AudioSynesthesia/Content' >> "$INI_FILE"
        echo 'Paths=../../../Engine/Plugins/Runtime/Bhvr/BhvrDataSaveGame/Content' >> "$INI_FILE"
        echo 'Paths=../../../Engine/Plugins/Runtime/Bhvr/BhvrLocalisation/Content' >> "$INI_FILE"
        echo 'Paths=../../../Engine/Plugins/Runtime/Bhvr/BhvrOptionMenu/Content' >> "$INI_FILE"
        echo '' >> "$INI_FILE"
        echo '[/Script/Engine.Engine]' >> "$INI_FILE"
        echo '; Settings added by ClairObscurFix' >> "$INI_FILE"
    fi
    
    # Success message
    echo ""
    echo "${green}${bold}ClairObscurFix has been successfully installed to:${normal}"
    echo "${bold}$MOD_DIR${normal}"
    echo ""
    echo "For Linux/Steam Deck, you need to add the following to your launch options in Steam:"
    echo "${bold}WINEDLLOVERRIDES=\"dsound=n,b\" %command%${normal}"
    echo ""
    echo "Would you like to automatically open the mod directory to check the installation?"
    OPTION=$(ugum choose "Yes" "No")
    if [ "$OPTION" == "Yes" ]; then
        xdg-open "$MOD_DIR"
    fi
    
    echo ""
    echo "Installation complete!"
