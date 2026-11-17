# Robot learning dev environment: LeRobot + MuJoCo + PyTorch (CUDA via host driver).
# The NVIDIA driver/libs are injected at runtime by the NVIDIA Container Toolkit,
# PyTorch wheels bring their own CUDA runtime, so a plain Ubuntu base is enough.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        # build tooling for the odd source-only wheel (evdev, etc.)
        build-essential cmake pkg-config \
        # OpenGL / EGL / GLFW for MuJoCo (EGL = headless GPU rendering, GLFW = viewer window, OSMesa = CPU fallback)
        libgl1 libegl1 libgles2 libglvnd0 libglfw3 libosmesa6 libgl1-mesa-dri mesa-utils \
        libxrandr2 libxinerama1 libxcursor1 libxi6 libxkbcommon-x11-0 x11-xserver-utils x11-utils \
        # video encode/decode for LeRobot datasets
        ffmpeg \
        # hardware inspection: USB, serial, cameras
        usbutils v4l-utils libusb-1.0-0 udev \
        # misc
        git-lfs htop tmux less jq \
    && rm -rf /var/lib/apt/lists/*

# Make GLVND find the NVIDIA EGL implementation injected by the container toolkit.
RUN mkdir -p /usr/share/glvnd/egl_vendor.d && \
    printf '{"file_format_version":"1.0.0","ICD":{"library_path":"libEGL_nvidia.so.0"}}\n' \
      > /usr/share/glvnd/egl_vendor.d/10_nvidia.json

# Serial adapters (SO-101 Feetech bus board -> /dev/ttyACM*), cameras (/dev/video*), USB.
# GIDs match Ubuntu/Debian hosts (dialout=20, video=44, plugdev=46).
RUN usermod -aG dialout,video,plugdev vscode

# uv for Python + dependency management
COPY --from=ghcr.io/astral-sh/uv:0.8.22 /uv /uvx /usr/local/bin/

# Mount points for the cache volumes in devcontainer.json. Docker copies the image directory's
# ownership onto a new empty named volume, so pre-creating these as vscode keeps them writable.
# (Without this, the volumes come up root-owned and `uv sync` fails with "Permission denied".)
RUN mkdir -p /home/vscode/.cache/uv /home/vscode/.cache/huggingface /home/vscode/.config/gh \
    && chown -R vscode:vscode /home/vscode/.cache /home/vscode/.config

USER vscode
ENV UV_PYTHON=3.12 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/home/vscode/.venv
RUN uv python install 3.12

# Claude Code (native installer -> ~/.local/bin/claude). Settings/auth come from host mounts.
RUN curl -fsSL https://claude.ai/install.sh | bash

ENV PATH=/home/vscode/.venv/bin:/home/vscode/.local/bin:$PATH \
    VIRTUAL_ENV=/home/vscode/.venv

USER root
