#!/bin/bash
# Container Setup Script for GoTrack
# This script sets up the container environment with all necessary fixes
# Run this script INSIDE the Docker container after starting it

set -e

echo "========================================================================"
echo "GoTrack Container Setup"
echo "========================================================================"

# Determine the host user's home directory (mounted from host)
# In the container, /home should be mounted from the host
HOST_USER_HOME="${HOST_USER_HOME:-$HOME}"

# Step 1: Setup cache symlink for DINOv2 weights
echo ""
echo "Step 1/3: Setting up DINOv2 cache..."
mkdir -p ~/.cache/torch/hub

# Remove existing symlink if present
if [ -L ~/.cache/torch/hub/checkpoints ]; then
    echo "  Removing existing symlink..."
    rm ~/.cache/torch/hub/checkpoints
fi

# Find the cache directory on the mounted /home volume
CACHE_SOURCE=""
if [ -d "${HOST_USER_HOME}/.cache/torch/hub/checkpoints" ]; then
    CACHE_SOURCE="${HOST_USER_HOME}/.cache/torch/hub/checkpoints"
elif [ -n "$SUDO_USER" ] && [ -d "/home/$SUDO_USER/.cache/torch/hub/checkpoints" ]; then
    CACHE_SOURCE="/home/$SUDO_USER/.cache/torch/hub/checkpoints"
else
    # Try to find any valid cache directory under /home
    for homedir in /home/*; do
        if [ -d "$homedir/.cache/torch/hub/checkpoints" ]; then
            CACHE_SOURCE="$homedir/.cache/torch/hub/checkpoints"
            break
        fi
    done
fi

if [ -n "$CACHE_SOURCE" ]; then
    ln -sf "$CACHE_SOURCE" ~/.cache/torch/hub/checkpoints
    echo "  ✓ Symlink created: ~/.cache/torch/hub/checkpoints -> $CACHE_SOURCE"

    # Verify weights file exists
    if [ -f ~/.cache/torch/hub/checkpoints/dinov2_vits14_reg4_pretrain.pth ]; then
        SIZE=$(stat -c%s ~/.cache/torch/hub/checkpoints/dinov2_vits14_reg4_pretrain.pth)
        SIZE_MB=$((SIZE / 1024 / 1024))
        echo "  ✓ DINOv2 weights accessible! Size: ${SIZE_MB} MB"
    else
        echo "  ✗ WARNING: DINOv2 weights not found!"
        echo "  Please download to: $CACHE_SOURCE/dinov2_vits14_reg4_pretrain.pth"
    fi
else
    echo "  ✗ ERROR: Could not find cache directory under /home"
    echo "  Please ensure /home is mounted and contains .cache/torch/hub/checkpoints/"
    exit 1
fi

# Step 2: Install OSMesa for software rendering
echo ""
echo "Step 2/3: Installing OSMesa libraries..."
if dpkg -l | grep -q libosmesa6-dev; then
    echo "  ✓ OSMesa already installed"
else
    echo "  Installing libosmesa6-dev..."
    echo "  NOTE: Add 'with-proxy' before apt-get if you need proxy access"
    apt-get update -qq
    apt-get install -y libosmesa6-dev
    echo "  ✓ OSMesa installed successfully"
fi

# Step 3: Upgrade PyOpenGL to support OSMesa
echo ""
echo "Step 3/4: Upgrading PyOpenGL..."
pip install --upgrade --quiet PyOpenGL PyOpenGL_accelerate
echo "  ✓ PyOpenGL upgraded successfully"

# Step 4: Apply patches to external dependencies
echo ""
echo "Step 4/4: Applying patches to external dependencies..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/patches"
DINOV2_DIR="$SCRIPT_DIR/external/dinov2"

if [ -f "$PATCHES_DIR/dinov2_offline_loading.patch" ] && [ -d "$DINOV2_DIR" ]; then
    cd "$DINOV2_DIR"

    # Check if patch is already applied
    if git diff --quiet dinov2/hub/backbones.py 2>/dev/null; then
        echo "  Applying DINOv2 offline loading patch..."
        if git apply "$PATCHES_DIR/dinov2_offline_loading.patch" 2>/dev/null; then
            echo "  ✓ DINOv2 patch applied successfully"
        else
            echo "  ✗ Failed to apply DINOv2 patch"
            echo "  You can manually apply it with:"
            echo "    cd $DINOV2_DIR"
            echo "    git apply $PATCHES_DIR/dinov2_offline_loading.patch"
        fi
    else
        echo "  ✓ DINOv2 patch already applied (file has modifications)"
    fi

    cd "$SCRIPT_DIR"
else
    if [ ! -f "$PATCHES_DIR/dinov2_offline_loading.patch" ]; then
        echo "  ✗ WARNING: Patch file not found: $PATCHES_DIR/dinov2_offline_loading.patch"
    fi
    if [ ! -d "$DINOV2_DIR" ]; then
        echo "  ✗ WARNING: DINOv2 directory not found: $DINOV2_DIR"
    fi
    echo "  Skipping patch application"
fi

echo ""
echo "========================================================================"
echo "Setup Complete!"
echo "========================================================================"
echo ""
echo "You can now run GoTrack inference:"
echo "  python -m scripts.inference_gotrack mode=pose_refinement \\"
echo "    dataset_name=\$DATASET_NAME coarse_pose_method=\$COARSE_POSE_METHOD"
echo ""
