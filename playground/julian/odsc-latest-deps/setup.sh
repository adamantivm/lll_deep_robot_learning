#!/usr/bin/env bash
# Download the ODSC LeRobot+MuJoCo Space at its pinned commit and patch it for the team env
# (MuJoCo 4 / LeRobot 0.7). Safe to re-run.
#
#   playground/julian/odsc-latest-deps/setup.sh [target_dir]
#
# target_dir defaults to outputs/odsc-lerobot-mujoco (git-ignored: the Space ships a 200 MB checkpoint).
set -euo pipefail

SPACE=pepijn223/odsc-lerobot-mujoco
REVISION=7d4d1d598927c6f3287243e1d58d9ea3df0f424e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
TARGET="${1:-$REPO_ROOT/outputs/odsc-lerobot-mujoco}"
PATCH="$HERE/rollout-latest-deps.patch"
unset VIRTUAL_ENV  # use the team env, not a venv that happens to be active

if [[ -f "$TARGET/rollout.py" ]]; then
    echo "Space already present in $TARGET"
else
    echo "Downloading $SPACE@${REVISION:0:8} into $TARGET ..."
    uv run --project "$REPO_ROOT" hf download "$SPACE" --repo-type space \
        --revision "$REVISION" --local-dir "$TARGET"
fi

# rollout.py verifies the checkpoint's SHA-256 (from manifest.json) every time it loads it.
if patch -d "$TARGET" -p1 -R --dry-run --silent --force < "$PATCH" > /dev/null 2>&1; then
    echo "Patch already applied"
elif patch -d "$TARGET" -p1 --dry-run --silent --forward < "$PATCH" > /dev/null 2>&1; then
    cp "$TARGET/rollout.py" "$TARGET/rollout.py.orig"
    patch -d "$TARGET" -p1 --forward < "$PATCH"
    echo "Patch applied (original kept as rollout.py.orig)"
else
    echo "ERROR: patch does not apply to $TARGET/rollout.py. Is it a different Space revision?" >&2
    exit 1
fi

echo "Done. Try: $HERE/run.sh --mode expert --output rollouts/expert.mp4"
