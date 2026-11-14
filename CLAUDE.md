# CLAUDE.md

Team exploration repo for robot learning: SO-101 arms, LeRobot, MuJoCo, policy training.
Experiments are throwaway by default; optimize for learning fast, not for polish.

- Everything runs inside the devcontainer (`.devcontainer/`). Python env: `uv`, venv at `~/.venv` (on PATH).
  Add dependencies with `uv add`, never `pip install` (pip changes are lost and not shared).
- `playground/<person>/` is personal: only touch the folder of the person you're working with.
  `shared/` is used by everyone, so be careful there and don't break other people's imports.
- Never commit datasets, checkpoints or videos. Write them to `outputs/` (git-ignored).
- Offscreen rendering: `MUJOCO_GL=egl`. GPU is small on some machines (4 GB), so keep batch sizes modest.
- Robot serial ports: prefer `/dev/serial/by-id/...` over `/dev/ttyACM0`. Never send motor commands
  to real hardware without the user confirming that the arm is clear and powered as expected.
- Check the environment with `python scripts/check_env.py`.
