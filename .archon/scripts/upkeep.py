"""Weekly plugin upkeep (weekly-upkeep workflow). INPUTS_MODE selects the step:
  update - `:Lazy! update` in a private copy of the plugin dir, so the live ~/.local/share/nvim is
           untouched; lazy-lock.json is rewritten in this worktree.
  bisect - find the plugin updates that break `make check`: binary search over the changed
           plugins (revert a suffix in lazy-lock.json, `:Lazy! restore`, make check), pin each
           culprit back to its old commit, repeat until green or MAX_CULPRITS.
Both print one JSON object. Logs go to ARTIFACTS_DIR.
"""

import json
import os
import pathlib
import shutil
import subprocess
import sys

MAX_CULPRITS = 3
LOCK = pathlib.Path("lazy-lock.json")
ARTIFACTS = pathlib.Path(os.environ.get("ARTIFACTS_DIR", ".")).resolve()
LIVE_DATA = pathlib.Path.home() / ".local/share/nvim"
DATA = ARTIFACTS / "data" / "nvim"
BEFORE = ARTIFACTS / "lock-before.json"


def nvim_env() -> dict[str, str]:
    """XDG dirs that make the real config (this worktree) use the private plugin copy."""
    config = ARTIFACTS / "config"
    config.mkdir(exist_ok=True)
    if not (config / "nvim").exists():
        (config / "nvim").symlink_to(pathlib.Path.cwd())
    state = ARTIFACTS / "state"
    state.mkdir(exist_ok=True)
    return {
        **os.environ,
        "XDG_CONFIG_HOME": str(config),
        "XDG_DATA_HOME": str(DATA.parent),
        "XDG_STATE_HOME": str(state),
        "NVIM_TEST_DATA_DIR": str(DATA),
    }


def lazy(cmd: str) -> None:
    subprocess.run(["nvim", "--headless", f"+Lazy! {cmd}", "+qa"], env=nvim_env(), capture_output=True, timeout=1800)


def check(tag: str) -> bool:
    proc = subprocess.run(["make", "check"], env=nvim_env(), capture_output=True, text=True)
    (ARTIFACTS / f"check-{tag}.log").write_text(proc.stdout + proc.stderr)
    return proc.returncode == 0


def read_lock() -> dict[str, dict]:
    return json.loads(LOCK.read_text())


def write_lock(lock: dict[str, dict]) -> None:
    LOCK.write_text(json.dumps(dict(sorted(lock.items())), indent=2) + "\n")


def update() -> dict:
    if not DATA.exists():
        DATA.mkdir(parents=True)
        # APFS clones (instant, no extra space): build hooks such as :TSUpdate write parsers to site/
        for sub in ("lazy", "site"):
            subprocess.run(["cp", "-cR", str(LIVE_DATA / sub), str(DATA / sub)], check=True)
    shutil.copy(LOCK, BEFORE)
    lazy("update")
    old, new = json.loads(BEFORE.read_text()), read_lock()
    changed = sorted(n for n in new if old.get(n, {}).get("commit") != new[n].get("commit"))
    return {"changed": bool(changed), "plugins": changed, "green": check("update")}


def bisect() -> dict:
    old, new = json.loads(BEFORE.read_text()), read_lock()
    suspects = sorted(n for n in new if n in old and old[n]["commit"] != new[n]["commit"])
    culprits: list[str] = []

    def red_with(updated: list[str]) -> bool:
        lock = {n: (new[n] if n in updated else old.get(n, new[n])) for n in new}
        write_lock(lock)
        lazy("restore")
        return not check("bisect-" + str(len(updated)))

    while suspects and len(culprits) < MAX_CULPRITS:
        if not red_with(suspects):
            break
        lo, hi = 0, len(suspects)  # red_with(suspects[:hi]) is red, suspects[:lo] assumed green
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if red_with(suspects[:mid]):
                hi = mid
            else:
                lo = mid
        culprits.append(suspects.pop(hi - 1))
    green = not red_with(suspects)
    pins = [{"plugin": n, "old": old[n]["commit"], "new": new[n]["commit"]} for n in culprits]
    return {"green": green, "culprits": pins, "summary": json.dumps(pins)}


mode = os.environ.get("INPUTS_MODE", "")
steps = {"update": update, "bisect": bisect}
if mode not in steps:
    sys.exit(f"INPUTS_MODE must be one of {list(steps)}, got {mode!r}")
print(json.dumps(steps[mode]()))
