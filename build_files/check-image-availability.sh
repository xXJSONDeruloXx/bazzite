#!/bin/bash
# Enhanced image availability checker for ARM builds
# This script checks multiple registries for required images and handles fallbacks

set -eo pipefail

IMAGE_NAME=$1
TAG=$2
PRIMARY_REGISTRY=${3:-"ghcr.io/ublue-os"}

echo "Checking availability for ${IMAGE_NAME}:${TAG}..."

# List of registries to check in order of preference
REGISTRIES=(
    "${PRIMARY_REGISTRY}"
    "quay.io/ublue-os"
    "docker.io/ublueosorg"
)

# Check each registry
for registry in "${REGISTRIES[@]}"; do
    IMAGE_URI="${registry}/${IMAGE_NAME}:${TAG}"
    echo "Trying ${IMAGE_URI}..."
    
    if skopeo inspect "docker://${IMAGE_URI}" &>/dev/null; then
        echo "✅ Found image at ${IMAGE_URI}"
        echo "${IMAGE_URI}" # Output the successful image URI
        exit 0
    else
        echo "❌ Not found at ${registry}"
    fi
done

# If we get here, no image was found
echo "⚠️ Warning: Image ${IMAGE_NAME}:${TAG} not found in any registry."
echo "Will need to handle this in the build process."
exit 1
