# To-do: pre-hardware sim exploration

Running checklist for [the plan](0-pre-hw-sim-exploration.md). Items are only checked off after Julian confirms.

## Julian's Insights

- On my Thinkpad X1 Extreme, it runs slower than real-time. Biggest limitation is the physics engine.
- If running purely on CPU, image rendering (especially for the scene display) is what takes the most time. It can be run on GPU and it speeds up significantly.

To run renderer on GPU, prepend  __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json

## Now

- [ ] **1. Run the pretrained SO-101 ACT policy locally** (ODSC Space `pepijn223/odsc-lerobot-mujoco`, pinned at commit `7d4d1d59`, in `outputs/odsc-lerobot-mujoco/`)
  - [x] Download the Space at the pinned commit and verify it
  - [x] Create its own venv (`.venv/`, Python 3.12, CPU torch, `requirements.txt`)
  - [x] Rollout with the scripted expert (`rollout.py --mode expert`): checks scene, physics and rendering
  - [x] Rollout with ACT (`rollout.py --mode act`): watch the video, read the metrics
  - [ ] Walk through `rollout.py` to understand it in more depth
  - [ ] Watch a rollout live in the MuJoCo viewer (`launch_passive` script in `playground/julian/`)
  - [ ] Run on the latest dependencies (devcontainer defaults: MuJoCo 4.x, LeRobot 0.7) and compare success with the pinned env
    - Notes for whoever picks this up:
      - The team env (`~/.venv`: MuJoCo 4.0.1, LeRobot 0.7.0, torch 2.14.1+cu126) imports `ACTPolicy`,
        `PreTrainedConfig` and `make_pre_post_processors` fine. It lacks `scipy`, `imageio` and `imageio-ffmpeg`,
        which `rollout.py` needs. Gradio is only needed for `app.py`.
      - Plan: from `outputs/odsc-lerobot-mujoco/`, with the Space's `.venv` deactivated, run
        `uv run --project ../.. --with scipy --with imageio --with imageio-ffmpeg python rollout.py ...`.
        This doesn't touch `pyproject.toml`.
      - Test one layer at a time: expert mode first (MuJoCo 4 only, deterministic, because actions come from IK and
        not from images), then ACT mode (LeRobot 0.7 loading a 0.6.2 checkpoint with `strict=True`).
      - Pinned baselines (bottle / C / seed 1000, NVIDIA EGL): expert 386 steps, `object_xyz` ≈ [0.16439, 0.24265, 0.05778];
        ACT 384 steps, success, 39 s.
      - If the Space's `.venv` needs reinstalling: `GIT_LFS_SKIP_SMUDGE=1 uv pip install --python .venv/bin/python
        --torch-backend=cpu -r requirements.txt`. Without the variable, git-lfs fails on a missing test image in the LeRobot repo.
  - [x] Run on GPU (CUDA torch and/or NVIDIA EGL rendering instead of Mesa) and compare speed and success

## Later

<!-- New ideas go here. -->

- [ ] Find out whether the physics timing can be improved: `mj_step` takes ~2-2.7 ms in the kitting scene, which is ~80% of a rollout on NVIDIA EGL (slower than real time by itself). Look at contact count, mesh vs primitive collisions, solver settings (`opt.iterations`, `opt.timestep`), and whether the 2.06 vs 2.65 ms gap between runs is the trajectory or run-to-run noise
