# ODSC SO-101 ACT demo on the team env

Runs the ODSC workshop Space [`pepijn223/odsc-lerobot-mujoco`](https://huggingface.co/spaces/pepijn223/odsc-lerobot-mujoco)
(pinned at `7d4d1d59`) on the devcontainer env (MuJoCo 4.0.1, LeRobot 0.7.0) instead of the Space's
own pinned env (MuJoCo 3.3.1, LeRobot 0.6.2). The Space is a pick-and-place ("kitting") task for an
SO-101 arm in MuJoCo, with a scripted expert and a pretrained ACT policy.

## Use it

```bash
playground/julian/odsc-latest-deps/setup.sh     # once: downloads the Space (~200 MB) to outputs/, applies the patch
playground/julian/odsc-latest-deps/run.sh --mode expert --output rollouts/expert.mp4
playground/julian/odsc-latest-deps/run.sh --mode act    --output rollouts/act.mp4
playground/julian/odsc-latest-deps/run.sh latest_deps_sweep.py team act 1000 10   # 10-seed sweep → rollouts/sweep_team.jsonl
```

Other `rollout.py` flags: `--seed`, `--object`, `--layout A..E`, `--device cuda`. Output paths are relative to
`outputs/odsc-lerobot-mujoco/`. `run.sh` renders on the NVIDIA GPU when the driver is present.

## Files

- `rollout-latest-deps.patch`: the only code change (described below), plus a new `latest_deps_sweep.py`.
- `setup.sh`: downloads the Space at the pinned commit (if missing) and applies the patch. Safe to re-run, and it
  fails loudly if the patch doesn't fit (e.g. a different Space revision).
- `run.sh`: runs a Space script with `uv run` on the team env.

Dependencies: the Space needs `scipy`, `imageio` and `imageio-ffmpeg`, which are now in the repo's `pyproject.toml`
(versions tested: 1.18.1, 2.38.2, 0.8.1).

## What broke on the latest deps, and the fix

Expert mode works unchanged on MuJoCo 4. Loading the ACT checkpoint fails on LeRobot 0.7:

1. `PreTrainedConfig.from_pretrained` raises `DecodingError`: `use_relative_actions`, `relative_*` and
   `action_feature_names` "are not valid for ACTConfig".
2. Building the preprocessor raises `RelativeActionsProcessorStep.__init__() got an unexpected keyword argument 'mode'`.

The checkpoint was saved by a LeRobot dev build (`7521ab48`) with relative-action fields that 0.7 removed. They have
no effect for this checkpoint (`use_relative_actions: false`, steps `enabled: false`), and the weights load with
`strict=True`, so the network is unchanged.

The patch adds `_compat_checkpoint_dir()` to `rollout.py`. It writes cleaned copies of `config.json` and the processor
JSONs to a temp dir (unknown keys dropped), symlinks the unchanged weights, and loads from there.
- It **refuses** to drop a field whose feature is active.
- Checkpoint files aren't edited; the Space's SHA-256 check still runs.
- On the pinned env it does nothing.

## Results: team env vs pinned env (2026-11-16, RTX 3050 Ti laptop, policy on CPU)

| bottle / layout C | Pinned (MuJoCo 3.3.1, LeRobot 0.6.2) | Team (MuJoCo 4.0.1, LeRobot 0.7.0) |
|---|---|---|
| Expert, 10 seeds | 10/10 | 10/10, same step counts per seed; final object position differs 0.7–7.3 mm |
| ACT, 30 seeds | 23/30 (77%) | 22/30 (73%), the same within noise (Fisher p = 1.0) |
| ms per control step, expert (no video) | 74.6 | **3.8** |
| ms per control step, ACT (no video) | 64.7 | **13.1** |
| Seed 1000 with video, expert / ACT | 386 steps, 33 s / 385 steps, 40 s | 386 steps, 3.4 s / 398 steps, 8.8 s |

MuJoCo 4 physics is ~20× faster on this scene. On the team env, rendering and the policy now take most of the time.

Re-tested 2026-11-17 after the switch to PyTorch cu130 (torch 2.14.1+cu130): ACT 22/30 with the same failing seeds
as on cu126, 13.0 ms per step; expert unchanged. ACT with `--device cuda` also succeeds and is ~2× faster than CPU.

## Gotchas

- **ACT rollouts are not reproducible with NVIDIA EGL, on either env.** Rendering the same scene twice changes ~0.02%
  of pixels by ±1, and over a ~400-step contact-rich rollout that can flip success. The same seed can succeed in
  one run and fail in the next. Compare **success rates over many seeds**, not single runs. The expert doesn't use
  images and is deterministic.
- After reset, objects settle slightly differently under MuJoCo 4 (bottle within 0.3 mm, a spare screwdriver a
  few degrees). ACT doesn't seem to mind.
- To compare against the original env, the Space's own `.venv` can still be built from its `requirements.txt`
  (`GIT_LFS_SKIP_SMUDGE=1 uv pip install --python .venv/bin/python --torch-backend=cpu -r requirements.txt`);
  the patched `rollout.py` works there too.
