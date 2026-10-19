"""On-demand plugin updates, one plugin at a time (plugin-update workflow, `make outdated`).
lazy.nvim always runs on a private APFS clone of the plugin dir (`lazy/` and `site/`, where build
hooks such as :TSUpdate write parsers), so the live ~/.local/share/nvim is never touched.
INPUTS_MODE selects the step:
  outdated - `:Lazy! check` on a throwaway clone and config copy; print the plugins whose upstream
             target is past lazy-lock.json. Read-only.
  update   - `:Lazy! restore` then `:Lazy! update <INPUTS_PLUGIN>` in .tests/xdg/ of the run
             worktree (the Makefile points the tests at it), keep only that plugin's lazy-lock.json
             line, write the changelog (old..new) and run `make check E2E=1`; print one JSON object.
"""

import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

LOCK = pathlib.Path("lazy-lock.json")
LIVE_DATA = pathlib.Path.home() / ".local/share/nvim"
XDG = pathlib.Path(".tests/xdg").resolve()  # NVIM_TEST_DATA_DIR in the Makefile
BASE = os.environ.get("BASE_BRANCH") or "auto"
ARTIFACTS = pathlib.Path(os.environ.get("ARTIFACTS_DIR", ".")).resolve()


def run(*cmd: str, **kw) -> str:
    return subprocess.run(cmd, capture_output=True, text=True, check=True, **kw).stdout.strip()


def isolate(xdg: pathlib.Path, config: pathlib.Path) -> dict[str, str]:
    """Clone the live plugin data into xdg/data/nvim once; return an env whose nvim uses it."""
    data = xdg / "data/nvim"
    if not data.exists():
        data.mkdir(parents=True)
        for sub in ("lazy", "site", "mason"):
            if (LIVE_DATA / sub).exists():
                run("cp", "-cR", str(LIVE_DATA / sub), str(data / sub))
    (xdg / "config").mkdir(exist_ok=True)
    if not (xdg / "config/nvim").exists():
        (xdg / "config/nvim").symlink_to(config)
    for sub in ("state", "cache"):
        (xdg / sub).mkdir(exist_ok=True)
    return {
        **os.environ,
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
    }


def nvim(env: dict[str, str], *cmds: str) -> str:
    args = ["nvim", "--headless"] + [f"+{c}" for c in cmds] + ["+qa!"]
    proc = subprocess.run(args, env=env, capture_output=True, text=True, timeout=1800)
    return proc.stdout + proc.stderr


def lock_lines(text: str) -> dict[str, str]:
    return {m.group(1): line for line in text.splitlines() if (m := re.match(r'\s*"([^"]+)":', line))}


def commit(lock: dict[str, str], name: str) -> str:
    return json.loads("{" + lock[name].rstrip(",") + "}")[name]["commit"]


# `:Lazy! check` fetched every plugin; print name, locked commit and upstream target commit
OUTDATED_LUA = """lua
local Config, Git = require("lazy.core.config"), require("lazy.manage.git")
local lock = vim.json.decode(table.concat(vim.fn.readfile(Config.options.lockfile), "\\n"))
for name, plugin in vim.spairs(Config.plugins) do
  local target = lock[name] and Git.get_target(plugin)
  if target and target.commit and target.commit ~= lock[name].commit then
    io.stdout:write(("%s %s %s\\n"):format(name, lock[name].commit, target.commit))
  end
end
"""


def outdated() -> None:
    with tempfile.TemporaryDirectory(prefix="nvim-outdated-") as tmp:
        config = pathlib.Path(tmp) / "repo"
        run("cp", "-cR", str(pathlib.Path.cwd()), str(config))  # a copy, so no lockfile write lands here
        xdg = pathlib.Path(tmp) / "xdg"
        xdg.mkdir()
        env = isolate(xdg, config)
        out = nvim(env, "Lazy! check", OUTDATED_LUA.replace("\n", " "))
        rows = [line.split() for line in out.splitlines() if re.fullmatch(r"\S+ [0-9a-f]{40} [0-9a-f]{40}", line)]
        for name, old, new in rows:
            plugin_dir = xdg / "data/nvim/lazy" / name
            count = subprocess.run(
                ["git", "-C", str(plugin_dir), "rev-list", "--count", f"{old}..{new}"], capture_output=True, text=True
            ).stdout.strip()
            print(f"{name:32} {count or '?':>4} commits  {old[:7]}..{new[:7]}")
        if not rows:
            print("All plugins are at their upstream target.")


def change_id(name: str) -> str:
    return "update-" + re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


ANSI = re.compile(r"\x1b\[[0-9;]*m")
FETCH_ERROR = re.compile(r"fatal: (unable to access|could not read)|Could not resolve host|Connection timed out", re.IGNORECASE)


def fetch_failed(log: str, name: str) -> bool:
    """`:Lazy! update` printed a git transport error on one of `name`'s lines (e.g. `[rustaceanvim] fetch | fatal: …`)."""
    tag = f"[{name}]"
    return any(tag in line and FETCH_ERROR.search(line) for line in ANSI.sub("", log).splitlines())


def update() -> dict:
    name = os.environ.get("INPUTS_PLUGIN", "").strip()
    before_text = run("git", "show", f"HEAD:{LOCK}")
    before = lock_lines(before_text)
    if name not in before:
        sys.exit(f"unknown plugin {name!r}; `make outdated` lists the updatable ones")
    env = isolate(XDG, pathlib.Path.cwd())
    log = nvim(env, "Lazy! restore", f"Lazy! update {name}")
    (ARTIFACTS / "lazy.log").write_text(log)
    if fetch_failed(log, name):  # an offline fetch left the pin as it was: never report "nothing to update" (run 16a2b177)
        sys.exit(f"{name}: the fetch failed (see {ARTIFACTS / 'lazy.log'}); check the network and run make update again")
    after = lock_lines(LOCK.read_text())
    # lazy rewrites every line; keep the committed lock except this plugin's line
    LOCK.write_text(before_text.replace(before[name], after.get(name, before[name])) + "\n")
    old, new = commit(before, name), commit(lock_lines(LOCK.read_text()), name)
    result = {"changed": old != new, "plugin": name, "change": change_id(name), "old": old, "new": new}
    if old == new:
        return {**result, "green": True, "changelog": "", "message": ""}
    plugin_dir = XDG / "data/nvim/lazy" / name
    commits = run("git", "-C", str(plugin_dir), "log", "--oneline", "--no-merges", f"{old}..{new}")
    url = re.sub(r"\.git$", "", run("git", "-C", str(plugin_dir), "remote", "get-url", "origin"))
    changelog = f"{name} {old[:7]}..{new[:7]} ({url}/compare/{old}...{new})\n\n{commits}"
    (ARTIFACTS / "changelog.md").write_text(changelog + "\n")
    print(changelog, file=sys.stderr)
    check = subprocess.run(["make", "check", "E2E=1"], capture_output=True, text=True)
    (ARTIFACTS / "check-update.log").write_text(check.stdout + check.stderr)
    message = f"chore(deps): update {name} {old[:7]}..{new[:7]}\n\n" + "\n".join(changelog.splitlines()[2:52])
    return {**result, "green": check.returncode == 0, "changelog": changelog, "message": message}


mode = os.environ.get("INPUTS_MODE", "")
if mode == "outdated":
    outdated()
elif mode == "update":
    print(json.dumps(update()))
else:
    sys.exit(f"INPUTS_MODE must be outdated or update, got {mode!r}")
