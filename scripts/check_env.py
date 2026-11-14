"""Sanity-check the dev environment: GPU, headless rendering, GUI, robot ports, cameras.

Usage:
    python scripts/check_env.py           # all checks
    python scripts/check_env.py --viewer  # also open a MuJoCo viewer window for a few seconds
"""

import argparse
import glob
import os
import sys
import time

OK, WARN, FAIL = "\033[32mOK  \033[0m", "\033[33mWARN\033[0m", "\033[31mFAIL\033[0m"

SCENE = """
<mujoco>
  <worldbody>
    <light pos="0 0 3"/>
    <geom type="plane" size="1 1 0.1" rgba=".8 .8 .8 1"/>
    <body pos="0 0 0.5"><freejoint/><geom type="box" size=".1 .1 .1" rgba=".9 .3 .2 1"/></body>
  </worldbody>
</mujoco>
"""


def check_torch():
    import torch

    if torch.cuda.is_available():
        name = torch.cuda.get_device_name(0)
        mem = torch.cuda.get_device_properties(0).total_memory / 2**30
        x = torch.randn(1024, 1024, device="cuda")
        (x @ x).sum().item()
        print(f"{OK} torch {torch.__version__} CUDA {torch.version.cuda}: {name} ({mem:.1f} GiB)")
    else:
        print(f"{WARN} torch {torch.__version__}: no CUDA GPU visible (training will be CPU-only)")


def check_mujoco_render(backend):
    """Render offscreen in a subprocess, since MUJOCO_GL must be set before mujoco is imported."""
    import subprocess

    code = (
        "import mujoco, numpy as np;"
        f"m = mujoco.MjModel.from_xml_string('''{SCENE}''');"
        "d = mujoco.MjData(m); mujoco.mj_step(m, d);"
        "r = mujoco.Renderer(m, 240, 320); r.update_scene(d); img = r.render();"
        "print(mujoco.__version__, img.shape, int(img.mean()))"
    )
    env = dict(os.environ, MUJOCO_GL=backend, PYOPENGL_PLATFORM=backend)
    res = subprocess.run([sys.executable, "-c", code], env=env, capture_output=True, text=True)
    if res.returncode == 0 and res.stdout.strip():
        print(f"{OK} MuJoCo offscreen render with MUJOCO_GL={backend}: {res.stdout.strip()}")
        return True
    err = (res.stderr.strip().splitlines() or ["?"])[-1]
    print(f"{WARN} MuJoCo offscreen render with MUJOCO_GL={backend} failed: {err}")
    return False


def check_display(open_viewer):
    display = os.environ.get("DISPLAY")
    if not display:
        print(f"{WARN} DISPLAY not set: GUI windows (MuJoCo viewer) won't open")
        return
    if not os.path.exists("/tmp/.X11-unix"):
        print(f"{WARN} DISPLAY={display} but /tmp/.X11-unix is not mounted")
        return
    import subprocess

    res = subprocess.run(["xdpyinfo"], capture_output=True, text=True) if _which("xdpyinfo") else None
    if res is not None and res.returncode != 0:
        print(f"{FAIL} DISPLAY={display} not reachable. On the host run: xhost +SI:localuser:$USER")
        return
    print(f"{OK} X display {display} reachable")
    if open_viewer:
        import mujoco
        import mujoco.viewer

        m = mujoco.MjModel.from_xml_string(SCENE)
        d = mujoco.MjData(m)
        with mujoco.viewer.launch_passive(m, d) as v:
            t0 = time.time()
            while v.is_running() and time.time() - t0 < 5:
                mujoco.mj_step(m, d)
                v.sync()
                time.sleep(m.opt.timestep)
        print(f"{OK} MuJoCo viewer window opened")


def _which(cmd):
    from shutil import which

    return which(cmd)


def check_serial():
    ports = sorted(glob.glob("/dev/ttyACM*") + glob.glob("/dev/ttyUSB*"))
    by_id = sorted(glob.glob("/dev/serial/by-id/*"))
    if not ports:
        print(f"{WARN} no serial ports (/dev/ttyACM*, /dev/ttyUSB*). Plug in the arm's bus adapter.")
        return
    for p in ports:
        try:
            fd = os.open(p, os.O_RDWR | os.O_NONBLOCK)
            os.close(fd)
            print(f"{OK} serial port {p} readable/writable")
        except OSError as e:
            print(f"{FAIL} serial port {p}: {e}")
    for link in by_id:
        print(f"      {os.path.basename(link)} -> {os.path.realpath(link)}")


def check_cameras():
    cams = sorted(glob.glob("/dev/video*"))
    if not cams:
        print(f"{WARN} no cameras (/dev/video*)")
        return
    bad = [c for c in cams if not os.access(c, os.R_OK | os.W_OK)]
    if bad:
        print(f"{FAIL} cameras without access: {bad} (is your user in group 'video'?)")
    else:
        print(f"{OK} cameras accessible: {' '.join(cams)}")


def check_lerobot():
    import lerobot

    print(f"{OK} lerobot {lerobot.__version__}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--viewer", action="store_true", help="open a MuJoCo viewer window for 5s")
    args = ap.parse_args()

    for check in (check_torch, check_lerobot):
        try:
            check()
        except Exception as e:  # noqa: BLE001
            print(f"{FAIL} {check.__name__}: {e!r}")
    if not check_mujoco_render("egl"):
        check_mujoco_render("osmesa")
    check_display(args.viewer)
    check_serial()
    check_cameras()


if __name__ == "__main__":
    main()
