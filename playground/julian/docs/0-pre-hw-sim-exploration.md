# Learning roadmap: ACT imitation learning on SO-101, sim first

## Context
Julian is waiting for SO-101 hardware (**follower arm only, no leader arm**) and has 2-4 weeks.
The goal is ACT pick and place working in sim, measured by success rate. He's more interested in
building use cases out of standard pieces than in ML internals or custom tooling, so we use the
LeRobot CLIs (`lerobot-eval`, `lerobot-train`, `lerobot-record`), LeRobotDataset and existing
MuJoCo models, environments and datasets. We write our own code only when no standard piece exists.

Environment: lerobot>=0.7, mujoco>=3.3 and gymnasium are already in `pyproject.toml`. GPU: RTX
3050 Ti, 4 GB, so keep the batch at about 8, use 1-2 cameras and modest image sizes. All work
goes in `playground/julian/`, all outputs go in `outputs/` (git-ignored), and new dependencies
are added with `uv add`.

## Week 1: see the loop, learn just enough MuJoCo
1. **Pretrained ACT on SO-101 in MuJoCo** (½ day). Use the Hugging Face ODSC workshop Space
   [`pepijn223/odsc-lerobot-mujoco`](https://huggingface.co/spaces/pepijn223/odsc-lerobot-mujoco)
   (Pepijn Kooijmans, Oct 2026). It bundles a pretrained ACT checkpoint
   ([`pepijn223/odsc-so101-act`](https://huggingface.co/pepijn223/odsc-so101-act)) with its
   pre/post-processors, a MuJoCo pick-into-tray scene built on the Menagerie SO-101 (the model we use
   in step 2), and `rollout.py`. Reported results: ACT 35/50, scripted expert 48/50.
   - **Why this instead of ALOHA:** it uses our robot, and `rollout.py` writes the inference loop out
     by hand (`from_pretrained` + `make_pre_post_processors` → per step: observation → preprocess →
     `select_action` → postprocess → `mj_step`). That is the loop `lerobot-eval` hides. It also ships a
     LeRobot v3 dataset ([`pepijn223/odsc-so101-pick-place`](https://huggingface.co/datasets/pepijn223/odsc-so101-pick-place))
     and the full training recipe (`train.sh`, `training-command.txt`), which are templates for week 2.
   - **How:** follow its PREREQUISITES.md "Local option" in `outputs/odsc-lerobot-mujoco/` with its own
     `.venv` and CPU torch. It pins `mujoco==3.3.1`, a LeRobot git commit and torch 2.11, so keeping it
     separate leaves the shared env (MuJoCo 4.0.1, LeRobot 0.7) alone. Run `rollout.py` directly for an
     ACT rollout video. Its Gradio app (`app.py`) is useful for browsing seeds and objects. Then browse
     the dataset to learn the LeRobotDataset layout (two 384×384 cameras, six joint positions, absolute
     joint-target actions at 20 Hz).
   - **Optional follow-up:** try `rollout.py` in the shared env. It only uses basic MuJoCo calls, so it
     will probably run, but physics can differ slightly between versions (the README notes outcomes
     change even between EGL backends), so compare success against the pinned env.
   - **Caveat:** the checkpoint is tied to this scene and joint calibration. It is not a policy for the
     real arm.
   - **Fallback, ALOHA sim** (`lerobot/act_aloha_sim_transfer_cube_human` via `lerobot[aloha]` +
     `lerobot-eval`). This is the canonical ACT benchmark, but the arms aren't the SO-101. The old
     downgrade problem has changed: `dm-control` 1.0.52 (Nov 2026) supports `mujoco>=4.0.1`, and the
     remaining cap is `gym-aloha` 0.1.5's own `mujoco<3.9.0`. You can likely bypass it with
     `[tool.uv] override-dependencies = ["mujoco>=4.0.1", "dm-control>=1.0.52"]`. This is untested, so try
     it in a scratch copy before touching the shared `pyproject.toml`.
2. **MuJoCo essentials on the real SO-101 model** (1-2 days). Use the standard SO-101 MJCF (TheRobotStudio
   SO-ARM100 repo or MuJoCo Menagerie). Work in a notebook: `MjModel`/`MjData`, `mj_step`, position
   actuators (these behave like the Feetech servos), adding a cube and table, cameras, offscreen render
   with `MUJOCO_GL=egl`, and the interactive viewer (see `check_display()` in
   `scripts/check_env.py` for the exit-segfault workaround).

## Week 2: SO-101 sim pick and place with existing pieces
3. **Find a community SO-101 MuJoCo env plus dataset in LeRobot format** on the Hub (several exist, e.g.
   `szk1ck/so101-pickplace-sim-mujoco`). Choose one that ships its env code, an Apache license and v3.0
   datasets. Check that its MuJoCo version matches ours, then replay a few episodes and evaluate its
   checkpoint.
4. **Train ACT yourself** with `lerobot-train --policy.type=act` on that dataset, using 4 GB settings.
   Evaluate the success rate.

## Weeks 3-4: make it your own use case
5. **Change the task** (different object, placement target or camera layout) and collect new demos.
   Use human teleop in sim (Quest 2, phone or others; see Teleoperation below) and record with
   LeRobot tooling. Keep a scripted expert, if the env has one, as a baseline.
6. **Run ablations**: number of demos, chunk size, temporal ensembling, camera count. Write up what
   mattered.

## Teleoperation (follower only; Meta Quest 2 and other devices available)
ACT needs demonstrations, and the quality of those demos sets the ceiling on how well the policy
can do. Julian has several devices to try, including a **Meta Quest 2**. Plan:
- **Use sim as the testbed for teleop devices** (weeks 3-4, step 5). Every non-leader device works
  the same way: device pose → end-effector target → IK → SO-101 joint targets. That chain is the
  same in sim and on the real arm, so a device that gives good demos in sim carries over to the
  real arm with no changes.
- **Quest 2**: look for an existing open-source Quest/WebXR → SO-100/101 teleop project before
  writing our own (verify what is currently maintained). Expect to handle: SO-101 is 5-DOF plus a
  gripper, so it can't follow a full 6-DoF hand pose (we'll have to drop or limit one rotation); a
  clutch to re-center; workspace bounds; and latency.
- **Fallbacks**: LeRobot's official phone teleop (EE + IK, supports SO-101), or a cheap leader
  arm. A leader arm is still the reference for clean, fast demos.
- **Comparison to run in sim**: record about 50 demos per device on the same task, train ACT on
  each set, and compare success rate and demos per hour. The result tells you which device to use
  on the real arm.

## Verification
Each stage ends with something in `outputs/`: (1) an SO-101 ACT rollout video from the ODSC checkpoint, (2) rendered
SO-101 scene images, (3) a replayed community episode plus checkpoint eval, (4) our trained ACT
success rate, (5-6) a new dataset plus a comparison table from the ablations.
