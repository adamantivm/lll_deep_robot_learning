# lll_deep_robot_learning

Our team playground for robot learning: SO-101 arms, [LeRobot](https://github.com/huggingface/lerobot),
MuJoCo simulation, and training policies on our own GPUs.

## Getting started

Requirements (host): **Linux**, Docker, VS Code with the *Dev Containers* extension.
For GPU training: an NVIDIA driver plus the
[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
(check with `docker info | grep -i runtimes`: it should list `nvidia`).

1. Clone the repo and open it in VS Code.
2. Run **Dev Containers: Reopen in Container**. The first build takes a while: it downloads PyTorch.
3. In the container terminal:

   ```bash
   python scripts/check_env.py            # GPU, rendering, serial ports, cameras
   python scripts/check_env.py --viewer   # also pops up a MuJoCo window for 5 s
   ```

Without VS Code: `npx @devcontainers/cli up --workspace-folder .` then
`npx @devcontainers/cli exec --workspace-folder . bash`.

## What the container gives you

| Thing | How |
|---|---|
| Python 3.12 + LeRobot + MuJoCo + PyTorch | `uv` env at `~/.venv`, already on `PATH`. Add deps with `uv add <pkg>` (commit `pyproject.toml` + `uv.lock`). |
| NVIDIA GPU | `hostRequirements.gpu: optional`: used when present, the container still starts without one. |
| SO-101 arm (USB serial) | Host `/dev` is mounted with access to `ttyACM*`/`ttyUSB*`, so plugging and unplugging works without a rebuild. Stable names live in `/dev/serial/by-id/`. |
| Cameras, gamepads, raw USB | `/dev/video*`, `/dev/input/*`, `/dev/bus/usb/*` |
| GUI windows (MuJoCo viewer, rerun) | X11 socket + `DISPLAY` forwarded (works on Wayland through XWayland). |
| Claude Code | Installed in the image. Your host `~/.claude/` and `~/.claude.json` are mounted, so you keep the same login, settings, plugins, memory and session history. The repo is mounted at the **same path as on your host**, so host and container share the same Claude project. |
| Caches | uv and Hugging Face caches (datasets, models) live in Docker volumes and survive rebuilds. |

### Notes and gotchas

- **Serial permissions**: the container user is in `dialout`/`video`/`plugdev` with Ubuntu/Debian GIDs (20/44/46).
  On other host distros, check `ls -l /dev/ttyACM0` if you get "permission denied".
- **Headless rendering**: use `MUJOCO_GL=egl` (GPU) or `MUJOCO_GL=osmesa` (CPU) for offscreen rendering / video recording.
- **GUI doesn't open?** On the host: `xhost +SI:localuser:$USER` (the container runs `initialize.sh` to do this for you).
- **macOS / Windows hosts**: not supported as-is (no USB or GPU passthrough with Docker Desktop). Use a Linux box for hardware and training.
- **Small GPUs** (e.g. 4 GB laptop cards): fine for MuJoCo and small policies (ACT, diffusion with small batches).
  Isaac Sim/Lab needs a much bigger card.

## Layout

```
.devcontainer/   container definition (Dockerfile, devcontainer.json, host/container setup scripts)
playground/<you> personal scratch space: commit freely, no review
shared/          code that graduated from playground and that several of us use (via PR)
notes/           learning notes, links, experiment write-ups
scripts/         repo-level utilities (check_env.py)
outputs/, data/  git-ignored: datasets, checkpoints, videos (share them via HF Hub / W&B)
```
