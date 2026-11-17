#!/usr/bin/env bash
# Runs inside the container once, after it is created.
set -euo pipefail

# The Dockerfile pre-creates these so new volumes are vscode-owned; this fixes up
# volumes that were created root-owned before that change (or by an older image).
sudo chown -R "$(id -u):$(id -g)" "$HOME/.cache/uv" "$HOME/.cache/huggingface" "$HOME/.config/gh"

git lfs install --skip-repo >/dev/null

echo "==> Installing Python environment (first run downloads PyTorch, takes a few minutes)"
uv sync

echo
echo "Done. Verify everything with:  python scripts/check_env.py"
