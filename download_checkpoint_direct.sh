#!/bin/bash
# Download the GoTrack checkpoint file directly

set -e

echo "Backing up the LFS pointer file..."
cp gotrack_checkpoint.pt gotrack_checkpoint.pt.lfs_pointer

echo "Downloading checkpoint directly from GitHub LFS..."
# The SHA256 hash from the LFS pointer
SHA256="f7d127abe2b8e37b1322a19115343286a6560700c6e02fc6080b4e2426a01086"
URL="https://media.githubusercontent.com/media/facebookresearch/gotrack/main/gotrack_checkpoint.pt"

wget -O gotrack_checkpoint.pt "$URL" || {
    echo "Direct download failed. Trying alternative URL..."
    # Try GitHub LFS CDN URL
    ALT_URL="https://github.com/facebookresearch/gotrack/raw/main/gotrack_checkpoint.pt"
    with-proxy wget -O gotrack_checkpoint.pt "$ALT_URL"
}

echo "Verifying checkpoint file..."
ACTUAL_SIZE=$(stat -c%s gotrack_checkpoint.pt)
EXPECTED_SIZE=1608850339

if [ "$ACTUAL_SIZE" -eq "$EXPECTED_SIZE" ]; then
    echo "✓ Checkpoint downloaded successfully! Size: $ACTUAL_SIZE bytes (1.5 GB)"
    file gotrack_checkpoint.pt
else
    echo "✗ File size mismatch. Expected: $EXPECTED_SIZE, Got: $ACTUAL_SIZE"
    echo "The download may have failed. Please check."
    exit 1
fi
