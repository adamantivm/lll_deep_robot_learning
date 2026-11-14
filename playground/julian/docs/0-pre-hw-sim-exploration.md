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
1. **Pretrained ACT on ALOHA sim** (½ day). Add `gym-aloha` (as a LeRobot extra) and run `lerobot-eval` on
   `lerobot/act_aloha_sim_transfer_cube_human`. You get a rollout video and a success rate. Learn
   the LeRobotDataset layout by browsing `lerobot/aloha_sim_transfer_cube_human`.
   - **Open decision:** `lerobot[aloha]` pulls in `gym-aloha` → `dm-control`, which pins MuJoCo
     to 3.8.1 and would downgrade the shared env from 4.0.1. Either accept the downgrade for the
     team or run this demo in a separate env (about 2 GB of torch to download again). If you switch back and forth,
     reinstall `mujoco`, `mujoco-core` and `mujoco-studio`: going 3.x → 4.x leaves the core bindings
     broken.
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
Each stage ends with something in `outputs/`: (1) an ALOHA eval video and success rate, (2) rendered
SO-101 scene images, (3) a replayed community episode plus checkpoint eval, (4) our trained ACT
success rate, (5-6) a new dataset plus a comparison table from the ablations.
