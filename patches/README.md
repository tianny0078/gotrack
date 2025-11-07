# Patches Directory

This directory contains patches for external dependencies (submodules) that need modifications but cannot be forked or modified directly.

## Available Patches

### `dinov2_offline_loading.patch`

**Purpose**: Enables offline loading of DINOv2 pretrained weights without network access.

**Applies to**: `external/dinov2` submodule

**Changes**:
- Adds cache checking before attempting to download pretrained weights
- Loads weights from `~/.cache/torch/hub/checkpoints/` if available
- Only attempts network download on cache miss

**How to apply**:

```bash
# From gotrack/gotrack directory
cd external/dinov2
git apply ../../patches/dinov2_offline_loading.patch
```

**How to revert**:

```bash
# From external/dinov2 directory
git checkout -- dinov2/hub/backbones.py
```

## Why Patches Instead of Forking?

Patches allow us to:
1. Track minimal changes to external dependencies
2. Avoid maintaining full forks of third-party code
3. Make it easy to update to newer versions of dependencies
4. Keep changes visible and reviewable in our repo

## Updating Patches

If you need to update a patch:

1. Make changes to the files in the external dependency
2. Generate a new patch file:
   ```bash
   cd external/dinov2
   git diff > ../../patches/dinov2_offline_loading.patch
   ```
3. Commit the updated patch file to the repo

## Applying All Patches

The `container_setup.sh` script can be extended to automatically apply patches during setup if needed.
