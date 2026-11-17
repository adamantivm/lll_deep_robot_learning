#!/usr/bin/env bash
# Run a script of the patched ODSC Space with the team env. Paths are relative to the Space folder.
#
#   run.sh --mode act --output rollouts/act.mp4          # rollout.py (default script)
#   run.sh latest_deps_sweep.py team act 1000 10         # any other script in the Space
#
# Set ODSC_DIR to use a Space folder other than outputs/odsc-lerobot-mujoco.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
ODSC_DIR="${ODSC_DIR:-$REPO_ROOT/outputs/odsc-lerobot-mujoco}"
[[ -f "$ODSC_DIR/rollout.py" ]] || { echo "No Space in $ODSC_DIR: run $HERE/setup.sh first" >&2; exit 1; }
unset VIRTUAL_ENV

# Render on the NVIDIA GPU when available (much faster than Mesa). render_backend.py would
# otherwise pick Mesa, because it only sets this variable when it is unset. The Dockerfile creates
# the vendor file in every container, so also require a GPU (nvidia-smi is only injected with one).
NVIDIA_EGL=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
if [[ -z "${__EGL_VENDOR_LIBRARY_FILENAMES:-}" && -f "$NVIDIA_EGL" ]] && nvidia-smi -L >/dev/null 2>&1; then
    export __EGL_VENDOR_LIBRARY_FILENAMES="$NVIDIA_EGL"
fi

SCRIPT=rollout.py
if [[ "${1:-}" == *.py ]]; then SCRIPT="$1"; shift; fi
cd "$ODSC_DIR"
exec uv run --project "$REPO_ROOT" python "$SCRIPT" "$@"
