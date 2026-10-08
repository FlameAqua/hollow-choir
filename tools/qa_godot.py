#!/usr/bin/env python3
"""Run Godot for this project with isolated user data.

Every run gets a fresh user:// home (settings, saves, sandbox preferences, shader cache), so the
player's own text size, bindings, window mode and Lab choices never leak into tests or captures,
and nothing is written to their real user data. Godot arguments follow the launcher options.

  python tools/qa_godot.py --headless --script res://tools/check_scripts.gd
  python tools/qa_godot.py --headless --script res://tests/run_tests.gd -- --filter=test_v02_ui
  python tools/qa_godot.py --hidden --rendering-method gl_compatibility \
      --script res://tools/capture_battle.gd -- --state=planning --out=res://captures/planning.png

Godot executable: --godot PATH, else the GODOT environment variable, else `godot` on PATH.
The tests and capture tool print the user data directory and stop if isolation did not apply.
Standard library only (Python 3.8+).
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
HOME_ENV = "HOLLOW_CHOIR_QA_HOME"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0], allow_abbrev=False)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"), help="Godot 4.7.2 executable")
    parser.add_argument("--home", help="reuse this user-data home instead of a fresh temporary one")
    parser.add_argument("--keep-home", action="store_true", help="keep the temporary home afterwards")
    parser.add_argument("--hidden", action="store_true", help="Windows: start a rendering window hidden (captures)")
    parser.add_argument("--timeout", type=float, default=900.0, help="seconds before the run is stopped")
    options, godot_args = parser.parse_known_args()

    home = Path(options.home).resolve() if options.home else Path(tempfile.mkdtemp(prefix="hollow_choir_qa_"))
    home.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    # Godot derives user:// from APPDATA (Windows) or XDG_DATA_HOME (Linux, macOS).
    env["APPDATA"] = str(home)
    env["XDG_DATA_HOME"] = str(home)
    env[HOME_ENV] = str(home)
    command = [options.godot]
    if "--path" not in godot_args:
        command += ["--path", str(PROJECT)]
    command += godot_args
    extra = {}
    if options.hidden and os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0  # SW_HIDE: renders without covering the desktop.
        extra = {"startupinfo": startup}
    print(f"QA user data home: {home}", flush=True)
    try:
        return subprocess.run(command, env=env, timeout=options.timeout, **extra).returncode
    except FileNotFoundError:
        print(f"Godot executable not found: {options.godot} (use --godot or set GODOT)", file=sys.stderr)
        return 2
    except subprocess.TimeoutExpired:
        print(f"Stopped after {options.timeout:.0f} s: the run did not finish.", file=sys.stderr)
        return 124
    finally:
        if not options.home and not options.keep_home:
            shutil.rmtree(home, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
