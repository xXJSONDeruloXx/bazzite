#!/bin/bash
# This script validates the availability of base images for ARM builds
# It should be run before starting the ARM build process

set -eo pipefail

REGISTRY=${1:-"ghcr.io/ublue-os"}
BASE_IMAGE_NAME=${2:-"kinoite"}
BASE_IMAGE_FLAVOR=${3:-"main"}
FEDORA_VERSION=${4:-"42"}

echo "Validating ARM base images..."

# Try multiple registries for the base image
BASE_REGISTRIES=(
    "${REGISTRY}"
    "quay.io/ublue-os"
    "docker.io/ublueosorg"
)

BASE_IMAGE_FOUND=false
for reg in "${BASE_REGISTRIES[@]}"; do
    BASE_IMAGE="${reg}/${BASE_IMAGE_NAME}-${BASE_IMAGE_FLAVOR}:${FEDORA_VERSION}"
    echo "Checking base image: ${BASE_IMAGE}"
    
    if skopeo inspect "docker://${BASE_IMAGE}" &>/dev/null; then
        echo "✅ Base image found: ${BASE_IMAGE}"
        BASE_IMAGE_FOUND=true
        
        # Extract the architecture information
        IMAGE_INFO=$(skopeo inspect "docker://${BASE_IMAGE}")
        ARCHES=$(echo "${IMAGE_INFO}" | jq -r '.Architecture // ""')
        
        if [ -z "${ARCHES}" ] || ! echo "${ARCHES}" | grep -q "arm64"; then
            echo "⚠️ Warning: Base image may not support ARM64 architecture."
            echo "Architecture info: ${ARCHES}"
            # Continue with other registries if arm64 not supported
            continue
        fi
        
        # Check image version label
        VERSION=$(echo "${IMAGE_INFO}" | jq -r '.Labels["org.opencontainers.image.version"] // ""')
        if [ -z "${VERSION}" ] || [ "${VERSION}" = "null" ]; then
            echo "⚠️ Warning: Base image is missing version label."
            echo "Using Fedora version ${FEDORA_VERSION} as fallback."
        fi
        
        # Found a suitable image, break the loop
        break
    else
        echo "❌ Base image not found at ${reg}"
    fi
done

if [ "${BASE_IMAGE_FOUND}" = "false" ]; then
    echo "❌ ERROR: No suitable base image found for ARM builds!"
    echo "Tried registries: ${BASE_REGISTRIES[*]}"
    exit 1
fi

echo "✅ Base image validation complete."
exit 0
