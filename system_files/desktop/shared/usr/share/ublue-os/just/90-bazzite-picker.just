# vim: set ft=make :

# Interactive picker for ujust recipes
pick:
    #!/usr/bin/bash

    source /usr/lib/ujust/ujust.sh

    PICKER_DIR="/usr/share/ublue-os/go/picker"
    # Function to check if a command exists
    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }

    # Ensure Go is installed
    if ! command_exists go; then
        echo "Go is not installed. Installing Go..."
        if command_exists brew; then
            brew install go
        elif command_exists dnf; then
            sudo dnf install -y golang
        else
            echo "Unable to install Go. Please install it manually and try again."
            exit 1
        fi
    fi

    # Change to the picker directory
    cd "$PICKER_DIR" || exit 1

    # Run the Go program
    if [ -f "$PICKER_DIR/picker" ] && [ "$PICKER_DIR/picker" -nt "$PICKER_DIR/picker.go" ]; then
        # Use the compiled binary if it exists and is newer than the source
        "$PICKER_DIR/picker"
    else
        # Compile and run
        echo "Compiling picker tool..."
        go build -o picker || {
            echo "Failed to compile. Running directly with 'go run'..."
            go run picker.go
        }
    fi
