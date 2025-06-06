#!/bin/bash
# Script to handle missing akmods-extra image
# This will be executed during the build process

set -e

KERNEL_FLAVOR=$1
FEDORA_VERSION=$2
KERNEL_VERSION=$3
REGISTRY=${4:-"ghcr.io/ublue-os"}

# Try to pull the image from the main registry
if podman pull "$REGISTRY/akmods-extra:$KERNEL_FLAVOR-$FEDORA_VERSION-$KERNEL_VERSION" &>/dev/null; then
    echo "Successfully pulled akmods-extra image from $REGISTRY"
    exit 0
fi

echo "Failed to pull akmods-extra from $REGISTRY, trying alternative sources..."

# Try alternative registries
ALTERNATIVE_REGISTRIES=("quay.io/ublue-os" "docker.io/ublueosorg")
for alt_registry in "${ALTERNATIVE_REGISTRIES[@]}"; do
    if podman pull "$alt_registry/akmods-extra:$KERNEL_FLAVOR-$FEDORA_VERSION-$KERNEL_VERSION" &>/dev/null; then
        echo "Successfully pulled akmods-extra image from $alt_registry"
        # Tag it with the expected name
        podman tag "$alt_registry/akmods-extra:$KERNEL_FLAVOR-$FEDORA_VERSION-$KERNEL_VERSION" \
                  "$REGISTRY/akmods-extra:$KERNEL_FLAVOR-$FEDORA_VERSION-$KERNEL_VERSION"
        exit 0
    fi
done

echo "Warning: Could not find akmods-extra image in any registry. Building without it."
# Create an empty placeholder image
mkdir -p /tmp/empty-akmods
cat > /tmp/empty-akmods/Containerfile << EOF
FROM scratch
LABEL org.opencontainers.image.description="Empty placeholder for akmods-extra"
EOF

podman build -t "$REGISTRY/akmods-extra:$KERNEL_FLAVOR-$FEDORA_VERSION-$KERNEL_VERSION" /tmp/empty-akmods
rm -rf /tmp/empty-akmods

echo "Created empty placeholder image for akmods-extra"
exit 0
