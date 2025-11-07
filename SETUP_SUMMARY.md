# GoTrack Offline Setup - Summary of Fixes

This document summarizes all fixes applied to run GoTrack in an offline Docker container environment without internet access.

## Problems Addressed

1. **DINOv2 Model Download Failure**: Network error when downloading pretrained DINOv2 weights
2. **OpenGL/EGL Initialization Failure**: Container lacks proper GPU/EGL access for hardware rendering
3. **Cache Path Mismatch**: Container runs as root but weights cached in user directory

## Solutions Implemented

### 1. DINOv2 Offline Loading Fix

**File Modified**: `gotrack/external/dinov2/dinov2/hub/backbones.py`

**Changes**:
- Added `import os` at line 6
- Modified `_make_dinov2_model()` function (lines 56-75) to check for cached weights before downloading
- Loads from `~/.cache/torch/hub/checkpoints/` if file exists
- Only attempts network download if cache miss

**Key Code Section**:
```python
if pretrained:
    model_full_name = _make_dinov2_model_name(arch_name, patch_size, num_register_tokens)

    # Check for cached weights first to avoid network calls
    cache_dir = os.path.join(torch.hub.get_dir(), "checkpoints")
    cached_file = os.path.join(cache_dir, f"{model_full_name}_pretrain.pth")

    if os.path.exists(cached_file):
        # Load from cache
        state_dict = torch.load(cached_file, map_location="cpu")
    else:
        # Download if not cached
        url = _DINOV2_BASE_URL + f"/{model_base_name}/{model_full_name}_pretrain.pth"
        state_dict = torch.hub.load_state_dict_from_url(url, map_location="cpu")

    model.load_state_dict(state_dict, strict=True)
```

### 2. OSMesa Software Rendering Fix

**Files Modified**:
- `gotrack/utils/renderer.py` (line 20-21)
- `gotrack/scripts/inference_gotrack.py` (lines 7-9)

**Changes**:
- Changed renderer from EGL (hardware) to OSMesa (software rendering)
- Set `PYOPENGL_PLATFORM="osmesa"` environment variable **before** any imports
- This avoids `GLError: err=12289` (EGL_NOT_INITIALIZED) in containers without GPU access

**renderer.py**:
```python
os.environ["DISPLAY"] = ":1"
# Use OSMesa for software rendering (works in containers without GPU access)
os.environ["PYOPENGL_PLATFORM"] = "osmesa"
```

**inference_gotrack.py** (critical - must be before imports):
```python
# Set OpenGL platform to OSMesa before any imports
# This must be done before PyOpenGL/pyrender is imported
import os
os.environ["PYOPENGL_PLATFORM"] = "osmesa"
```

### 3. Container Dependencies

**Packages Installed**:
- `libosmesa6-dev` (OSMesa library for software OpenGL)
- Upgraded `PyOpenGL` and `PyOpenGL_accelerate` (for OSMesa support)

**Installation Commands**:
```bash
apt-get update
apt-get install -y libosmesa6-dev
pip install --upgrade PyOpenGL PyOpenGL_accelerate
```

**Note**: Add `with-proxy` before commands if you need proxy access.

## Setup Scripts

### Quick Setup (Recommended)

**Script**: `container_setup.sh`

Run this script **inside the Docker container** after starting it:

```bash
# Inside container, from gotrack/gotrack directory
bash ./container_setup.sh
```

This script:
1. Auto-detects and creates symlink from `~/.cache/torch/hub/checkpoints` to host cache
2. Installs OSMesa libraries
3. Upgrades PyOpenGL packages
4. **Automatically applies patches** to external dependencies
5. Verifies DINOv2 weights are accessible

### Manual Setup Steps

If you prefer manual setup:

```bash
# 1. Setup cache symlink
mkdir -p ~/.cache/torch/hub
ln -sf /home/<username>/.cache/torch/hub/checkpoints ~/.cache/torch/hub/checkpoints

# 2. Install OSMesa (add 'with-proxy' before apt-get if you need proxy access)
apt-get update
apt-get install -y libosmesa6-dev

# 3. Upgrade PyOpenGL
pip install --upgrade PyOpenGL PyOpenGL_accelerate
```

## Downloading DINOv2 Weights

If weights are not yet downloaded (add `with-proxy` before wget if you need proxy access):

```bash
# On host machine (or inside container with proxy)
wget -O ~/.cache/torch/hub/checkpoints/dinov2_vits14_reg4_pretrain.pth \
  https://dl.fbaipublicfiles.com/dinov2/dinov2_vits14/dinov2_vits14_reg4_pretrain.pth
```

Expected file:
- **Path**: `~/.cache/torch/hub/checkpoints/dinov2_vits14_reg4_pretrain.pth`
- **Size**: ~85 MB

## Running GoTrack Inference

After setup, run inference normally:

```bash
cd <gotrack_repo>/gotrack

# Set environment variables
export DATASET_NAME=lmo
export COARSE_POSE_METHOD=foundpose

# Run inference
python -m scripts.inference_gotrack \
  mode=pose_refinement \
  dataset_name=$DATASET_NAME \
  coarse_pose_method=$COARSE_POSE_METHOD
```

## Files Modified

| File | Purpose | Lines Changed |
|------|---------|---------------|
| `gotrack/external/dinov2/dinov2/hub/backbones.py` | Offline DINOv2 loading | 6, 56-75 |
| `gotrack/utils/renderer.py` | OSMesa rendering | 20-21 |
| `gotrack/scripts/inference_gotrack.py` | Early OSMesa setup | 7-9 |
| `container_setup.sh` | Automated setup | New file |
| `setup_cache.sh` | Cache symlink only | Replaced by container_setup.sh |

## Troubleshooting

### "URLError: Temporary failure in name resolution"
- DINOv2 weights not in cache
- Run: `ls -lh ~/.cache/torch/hub/checkpoints/dinov2_vits14_reg4_pretrain.pth`
- Download weights using command above

### "GLError: err=12289"
- OSMesa not installed or PyOpenGL too old
- Run: `bash ./container_setup.sh` (from gotrack/gotrack directory)

### "ImportError: cannot import name 'OSMesaCreateContextAttribs'"
- PyOpenGL version incompatible
- Run: `pip install --upgrade PyOpenGL PyOpenGL_accelerate`

### Weights file not found in container
- Cache symlink not created
- The `container_setup.sh` script will auto-detect and create the symlink
- Or manually: `ln -sf /home/<username>/.cache/torch/hub/checkpoints ~/.cache/torch/hub/checkpoints`

## Technical Details

### Why OSMesa?

EGL requires proper GPU driver access and DRI support, which is often unavailable in Docker containers. OSMesa provides CPU-based software rendering that:
- Works without GPU drivers
- Runs in isolated containers
- Produces identical rendering results
- Trades performance for compatibility (slower but works everywhere)

### Why Check Cache First?

PyTorch's `torch.hub.load_state_dict_from_url()` attempts to download from the internet even when the file exists in cache, which fails in offline environments. By explicitly checking the filesystem first, we avoid network calls entirely.

### Why Set Environment Variable Early?

PyOpenGL determines which platform to use (EGL, GLX, OSMesa) at import time based on the `PYOPENGL_PLATFORM` environment variable. Setting it in `renderer.py` is too late because other modules may have already imported PyOpenGL. Setting it at the very top of the main script ensures it's configured before any imports.

## Summary

All fixes are minimal, non-invasive changes that:
- ✅ Enable offline operation without internet access
- ✅ Work in Docker containers without GPU driver access
- ✅ Maintain full functionality (OSMesa provides correct rendering)
- ✅ Require one-time setup per container instance
- ✅ Are automated via `container_setup.sh` script

The fixes allow GoTrack to run successfully in restricted environments typical of production containers.
