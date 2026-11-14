#!/usr/bin/env bash
# Runs inside the container once, after it is created.
set -euo pipefail

# Named volumes are created root-owned the first time.
sudo chown -R "$(id -u):$(id -g)" "$HOME/.cache/uv" "$HOME/.cache/huggingface"

git lfs install --skip-repo >/dev/null

echo "==> Installing Python environment (first run downloads PyTorch, takes a few minutes)"
uv sync

echo
echo "Done. Verify everything with:  python scripts/check_env.py"
