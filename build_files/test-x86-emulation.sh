#!/bin/bash
# Test x86 emulation functionality
set -e

echo "Testing x86 emulation on ARM64..."

# Check if box86/box64 are installed
if ! command -v box86 &> /dev/null; then
    echo "Error: box86 not found. Please ensure x86 emulation is installed properly."
    exit 1
fi

if ! command -v box64 &> /dev/null; then
    echo "Error: box64 not found. Please ensure x86 emulation is installed properly."
    exit 1
fi

# Check if binfmt is configured
if [ ! -f /proc/sys/fs/binfmt_misc/box86 ] || [ ! -f /proc/sys/fs/binfmt_misc/box64 ]; then
    echo "Error: binfmt configuration not found. Please run 'ujust toggle-x86-emulation' first."
    exit 1
fi

# Create a simple x86 test program
cat > /tmp/hello_x86.c << 'EOL'
#include <stdio.h>
int main() {
    printf("Hello from x86 emulation on ARM64!\n");
    return 0;
}
EOL

# Try to download a precompiled x86_64 binary
echo "Downloading a small x86_64 test binary..."
if command -v curl &> /dev/null; then
    curl -L -o /tmp/hello_x86_64 https://github.com/ptitSeb/box64/raw/main/tests/hello
elif command -v wget &> /dev/null; then
    wget -O /tmp/hello_x86_64 https://github.com/ptitSeb/box64/raw/main/tests/hello
else
    echo "Warning: Neither curl nor wget found. Skipping binary download test."
fi

# Make it executable
if [ -f /tmp/hello_x86_64 ]; then
    chmod +x /tmp/hello_x86_64
fi

echo "Testing Box64..."
if [ -f /tmp/hello_x86_64 ]; then
    if box64 /tmp/hello_x86_64; then
        echo "Box64 test: SUCCESS!"
    else
        echo "Box64 test: FAILED!"
        echo "The emulation may not be configured correctly."
    fi
else
    echo "Box64 test: SKIPPED (no test binary)"
fi

echo "Box86/Box64 version information:"
box86 --version
box64 --version

echo ""
echo "If the tests were successful, x86 emulation is working on your system."
echo "You can now use 'ujust install-wine-x86' or 'ujust install-bottles' to set up Windows application support."
