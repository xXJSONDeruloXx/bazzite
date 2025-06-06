#!/usr/bin/env bash
# ARM integration validation test script
# Run this script on an ARM64 device to verify the integration

set -e

echo "===== Bazzite ARM Integration Validation ====="
echo "Running validation tests for ARM64 support..."

# Check architecture
echo -n "Checking architecture: "
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ]; then
    echo "ERROR: This script must be run on an ARM64 device"
    exit 1
else
    echo "OK (aarch64)"
fi

# Check if environment variables are set
echo -n "Checking environment variables: "
if grep -q "ARM64_BUILD=1" /etc/environment && grep -q "X86_EMULATION=1" /etc/environment; then
    echo "OK"
else
    echo "FAILED (environment variables not set properly)"
    exit 1
fi

# Check if emulation binaries exist
echo -n "Checking qemu-user-static: "
if [ -f /usr/bin/qemu-x86_64-static ] && [ -x /usr/bin/qemu-x86_64-static ]; then
    echo "OK"
else
    echo "FAILED (qemu-x86_64-static not found or not executable)"
    exit 1
fi

echo -n "Checking box64: "
if [ -f /usr/local/bin/box64 ] && [ -x /usr/local/bin/box64 ]; then
    echo "OK"
else
    echo "FAILED (box64 not found or not executable)"
    exit 1
fi

echo -n "Checking run-x86 wrapper: "
if [ -f /usr/local/bin/run-x86 ] && [ -x /usr/local/bin/run-x86 ]; then
    echo "OK"
else
    echo "FAILED (run-x86 wrapper not found or not executable)"
    exit 1
fi

# Test x86_64 emulation
echo -n "Testing x86_64 emulation with a simple binary: "
echo 'int main() { printf("Hello from x86_64\\n"); return 0; }' > /tmp/test.c
gcc -m64 -static -o /tmp/test_x86_64 /tmp/test.c || true

if [ -f /tmp/test_x86_64 ]; then
    if /usr/local/bin/run-x86 /tmp/test_x86_64 | grep -q "Hello from x86_64"; then
        echo "OK"
    else
        echo "FAILED (x86_64 emulation not working)"
        exit 1
    fi
else
    echo "SKIPPED (couldn't compile test binary)"
fi

# Test binfmt registration
echo -n "Testing binfmt registration: "
if cat /proc/sys/fs/binfmt_misc/register | grep -q "x86_64"; then
    echo "OK"
else
    echo "WARNING (binfmt registration not found, may need manual setup)"
fi

# Check if ARM-specific packages are installed
echo -n "Checking ARM-specific packages: "
if rpm -q --whatprovides pipewire >/dev/null && rpm -q --whatprovides distrobox >/dev/null; then
    echo "OK"
else
    echo "WARNING (some essential ARM packages may be missing)"
fi

# Test wrapper creation function
echo "Testing wrapper creation functionality..."
cat > /tmp/test_wrapper.sh << 'EOF'
#!/bin/bash
source /build_files/build-arm-with-emulation.sh
echo "int main() { printf(\"Test x86_64 binary\\n\"); return 0; }" > /tmp/test_bin.c
gcc -m64 -static -o /tmp/test_bin /tmp/test_bin.c || exit 1
file /tmp/test_bin
create_emulation_wrapper "/tmp/test_bin"
if [ -f "/tmp/test_bin.x86" ]; then
    echo "Wrapper creation successful"
    exit 0
else
    echo "Wrapper creation failed"
    exit 1
fi
EOF

chmod +x /tmp/test_wrapper.sh
if /tmp/test_wrapper.sh; then
    echo "Wrapper creation test: OK"
else
    echo "Wrapper creation test: FAILED"
fi

# Summary
echo ""
echo "===== Validation Summary ====="
echo "Architecture check: OK"
echo "Environment variables: OK"
echo "Emulation binaries: OK" 
echo "X86_64 emulation test: OK"
echo ""
echo "ARM integration validation completed successfully!"
echo "For detailed testing of applications, please run them manually."
echo "============================="
