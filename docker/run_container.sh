podman rm -f go
DIR=$(pwd)/../

# Create temporary directory for NVIDIA libraries if it doesn't exist
NVIDIA_LIB_DIR="/tmp/nvidia_libs"
if [ ! -d "$NVIDIA_LIB_DIR" ]; then
    mkdir -p "$NVIDIA_LIB_DIR"
    # Copy only NVIDIA-specific libraries from host
    cp -L /usr/lib64/libcuda*.so* "$NVIDIA_LIB_DIR/" 2>/dev/null || true
    cp -L /usr/lib64/libnvidia*.so* "$NVIDIA_LIB_DIR/" 2>/dev/null || true
    cp -L /usr/lib64/libcudadebugger*.so* "$NVIDIA_LIB_DIR/" 2>/dev/null || true
fi

# Only run xhost if it's available
if command -v xhost &> /dev/null; then
    xhost +
fi

podman run \
  --device /dev/nvidia0:/dev/nvidia0 \
  --device /dev/nvidiactl:/dev/nvidiactl \
  --device /dev/nvidia-modeset:/dev/nvidia-modeset \
  --device /dev/nvidia-uvm:/dev/nvidia-uvm \
  --device /dev/nvidia-uvm-tools:/dev/nvidia-uvm-tools \
  --env NVIDIA_DISABLE_REQUIRE=1 \
  --env NVIDIA_VISIBLE_DEVICES=all \
  --env NVIDIA_DRIVER_CAPABILITIES=compute,utility \
  --env LD_LIBRARY_PATH=/nvidia_libs:/usr/local/cuda/lib64:$LD_LIBRARY_PATH \
  -v "$NVIDIA_LIB_DIR:/nvidia_libs:ro" \
  -it --network=host --name go \
  --cap-add=SYS_PTRACE --cap-add=SYS_ADMIN \
  --security-opt seccomp=unconfined \
  --security-opt label=disable \
  --privileged \
  -v $DIR:$DIR -v /home:/home -v /mnt:/mnt \
  -v /tmp/.X11-unix:/tmp/.X11-unix -v /tmp:/tmp \
  --ipc=host -e DISPLAY=${DISPLAY} -e GIT_INDEX_FILE \
  harbor.thefacebook.com/agios/dexman/test:0.2 \
  bash -c "ln -sf /nvidia_libs/libcuda.so.1 /usr/local/cuda/lib64/libcuda.so.1 && ln -sf /nvidia_libs/libcuda.so.1 /usr/local/cuda/lib64/libcuda.so && cd $DIR && bash"
