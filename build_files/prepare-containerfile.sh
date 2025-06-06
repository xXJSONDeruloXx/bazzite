#!/bin/bash
# Helper script to modify the Containerfile before build
# This ensures the build won't fail if certain images are missing

set -e

CONTAINERFILE_PATH=$1
KERNEL_FLAVOR=$2
FEDORA_VERSION=$3
KERNEL_VERSION=$4
REGISTRY=${5:-"ghcr.io/ublue-os"}

echo "Checking for required images and updating Containerfile..."

# Check for akmods image
AKMODS_IMAGE="${REGISTRY}/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION}"
AKMODS_AVAILABLE=false

if skopeo inspect "docker://${AKMODS_IMAGE}" &>/dev/null; then
    echo "✅ akmods image found: ${AKMODS_IMAGE}"
    AKMODS_AVAILABLE=true
else
    echo "⚠️ akmods image not found: ${AKMODS_IMAGE}"
fi

# Check for akmods-extra image
AKMODS_EXTRA_IMAGE="${REGISTRY}/akmods-extra:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION}"
AKMODS_EXTRA_AVAILABLE=false

if skopeo inspect "docker://${AKMODS_EXTRA_IMAGE}" &>/dev/null; then
    echo "✅ akmods-extra image found: ${AKMODS_EXTRA_IMAGE}"
    AKMODS_EXTRA_AVAILABLE=true
else
    echo "⚠️ akmods-extra image not found: ${AKMODS_EXTRA_IMAGE}"
fi

# Create a temporary copy of the Containerfile
TEMP_CONTAINERFILE="${CONTAINERFILE_PATH}.tmp"
cp "${CONTAINERFILE_PATH}" "${TEMP_CONTAINERFILE}"

# Update the akmods FROM lines based on availability
if [ "${AKMODS_AVAILABLE}" = "true" ]; then
    sed -i "s|FROM ghcr.io/ublue-os/akmods:.*AS akmods-amd64|FROM ${AKMODS_IMAGE} AS akmods-amd64|g" "${TEMP_CONTAINERFILE}"
else
    sed -i "s|FROM ghcr.io/ublue-os/akmods:.*AS akmods-amd64|FROM scratch AS akmods-amd64|g" "${TEMP_CONTAINERFILE}"
    echo "⚠️ Using empty akmods image (scratch)"
fi

if [ "${AKMODS_EXTRA_AVAILABLE}" = "true" ]; then
    sed -i "s|FROM ghcr.io/ublue-os/akmods-extra:.*AS akmods-extra-amd64|FROM ${AKMODS_EXTRA_IMAGE} AS akmods-extra-amd64|g" "${TEMP_CONTAINERFILE}"
else
    sed -i "s|FROM ghcr.io/ublue-os/akmods-extra:.*AS akmods-extra-amd64|FROM scratch AS akmods-extra-amd64|g" "${TEMP_CONTAINERFILE}"
    echo "⚠️ Using empty akmods-extra image (scratch)"
fi

# Replace the original Containerfile with our modified version
mv "${TEMP_CONTAINERFILE}" "${CONTAINERFILE_PATH}"

echo "Containerfile updated successfully"
exit 0
