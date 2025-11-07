#!/bin/bash
# Script to apply patches to external dependencies
# Run this script from the gotrack/gotrack directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/patches"

echo "========================================"
echo "Applying External Dependency Patches"
echo "========================================"

# Apply DINOv2 offline loading patch
echo ""
echo "Applying DINOv2 offline loading patch..."
if [ -f "$PATCHES_DIR/dinov2_offline_loading.patch" ]; then
    cd "$SCRIPT_DIR/external/dinov2"

    # Check if patch is already applied
    if git diff --quiet dinov2/hub/backbones.py; then
        echo "  Applying patch..."
        git apply "$PATCHES_DIR/dinov2_offline_loading.patch"
        echo "  ✓ Patch applied successfully"
    else
        echo "  ✓ Patch already applied (file has modifications)"
    fi

    cd "$SCRIPT_DIR"
else
    echo "  ✗ Patch file not found: $PATCHES_DIR/dinov2_offline_loading.patch"
    exit 1
fi

echo ""
echo "========================================"
echo "All patches applied successfully!"
echo "========================================"
