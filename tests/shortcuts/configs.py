"""Dump the effective Alacritty and zellij key bindings as JSON (chain layer).

Run with the pinned venv (tests/shortcuts/bootstrap.sh):
    .tests/venv/bin/python -I tests/shortcuts/configs.py

Both configs are external and unversioned. Directories are resolved as
  1. $ALACRITTY_CONFIG_DIR / $ZELLIJ_CONFIG_DIR
  2. <repo>/terminal/<tool> if it exists
  3. ~/.config/<tool>

Alacritty: TOML via tomllib, `import` (top level or [general]) followed in
order, the importing file last; for the same trigger the last binding wins.
Imports under ~/.config/alacritty/ are read from the resolved directory.

zellij 0.45 semantics (zellij-utils/src/kdl/mod.rs, Keybinds::from_kdl):
  - clear-defaults=true starts empty, otherwise from the default keybinds
    (`zellij setup --dump-config`)
  - shared / shared_except / shared_among blocks in file order, then per-mode
    blocks; a later bind of the same key replaces the earlier one
  - inside a block all binds, then all unbinds; a top-level `unbind` last
  - "Alt H" == "Alt Shift h" (uppercase ASCII char = lowercase + Shift)
"""

import json
import os
import subprocess
import sys
import tomllib
from pathlib import Path

import kdl

REPO = Path(__file__).resolve().parents[2]
HOME = Path.home()

# zellij-utils/src/data.rs InputMode, iteration order
ZELLIJ_MODES = [
    "normal", "locked", "resize", "pane", "tab", "scroll", "entersearch", "search",
    "renametab", "renamepane", "session", "move", "prompt", "tmux",
]
ZELLIJ_MODIFIERS = ["ctrl", "alt", "shift", "super"]


def config_dir(tool: str, env: str) -> Path:
    if os.environ.get(env):
        return Path(os.environ[env]).expanduser()
    versioned = REPO / "terminal" / tool
    if versioned.is_dir():
        return versioned
    return HOME / ".config" / tool


# --- Alacritty -----------------------------------------------------------------

def alacritty_import_path(raw: str, importer: Path, root: Path) -> Path:
    path = Path(raw).expanduser()
    default_root = HOME / ".config" / "alacritty"
    if path.is_relative_to(default_root):
        return root / path.relative_to(default_root)
    if not path.is_absolute():
        return importer.parent / path
    return path


def alacritty_files(path: Path, root: Path, seen: set) -> list[tuple[Path, dict]]:
    if path in seen or not path.exists():
        return []
    seen.add(path)
    data = tomllib.loads(path.read_text())
    imports = data.get("import", []) + data.get("general", {}).get("import", [])
    files = []
    for raw in imports:
        files += alacritty_files(alacritty_import_path(raw, path, root), root, seen)
    return files + [(path, data)]


def alacritty_mods(mods: str) -> list[str]:
    alias = {"command": "Command", "super": "Command", "control": "Control", "ctrl": "Control",
             "option": "Option", "alt": "Option", "shift": "Shift"}
    if not mods or mods.lower() == "none":
        return []
    return sorted({alias[m.strip().lower()] for m in mods.split("|")})


def alacritty() -> dict:
    root = config_dir("alacritty", "ALACRITTY_CONFIG_DIR")
    main = root / "alacritty.toml"
    files = alacritty_files(main, root, set())
    effective: dict[tuple, dict] = {}
    window: dict = {}
    for path, data in files:
        window.update(data.get("window", {}))
        for binding in data.get("keyboard", {}).get("bindings", []):
            entry = {
                "key": str(binding["key"]),
                "mods": alacritty_mods(binding.get("mods", "")),
                "mode": binding.get("mode", ""),
                "chars": binding.get("chars"),
                "action": binding.get("action"),
                "file": str(path),
            }
            trigger = (entry["key"].lower(), tuple(entry["mods"]), entry["mode"])
            effective.pop(trigger, None)  # keep file order of the winner
            effective[trigger] = entry
    return {
        "root": str(root),
        "files": [str(p) for p, _ in files],
        "option_as_alt": window.get("option_as_alt", "None"),
        "bindings": list(effective.values()),
    }


# --- zellij ------------------------------------------------------------------------

def zellij_key(raw: str) -> str:
    """Canonical KeyWithModifier string: sorted modifiers + key."""
    parts = raw.split()
    key, mods = parts[-1], {m.lower() for m in parts[:-1]}
    if len(key) == 1:
        if key.isascii() and key.isupper():
            key, mods = key.lower(), mods | {"shift"}
    else:
        key = key.lower()
    return " ".join([m for m in ZELLIJ_MODIFIERS if m in mods] + [key])


def zellij_action(node) -> dict:
    action = {"name": node.name, "args": [str(a) for a in node.args]}
    children = {child.name: [str(a) for a in child.args] for child in node.nodes}
    if children:
        action["children"] = children
    return action


def zellij_block(modes: dict, targets: list[str], block, section: str) -> None:
    binds = [n for n in block.nodes if n.name == "bind"]
    unbinds = [n for n in block.nodes if n.name == "unbind"]
    for mode in targets:
        for bind in binds:
            for raw in bind.args:
                modes[mode][zellij_key(str(raw))] = {
                    "key": str(raw),
                    "section": section,
                    "actions": [zellij_action(a) for a in bind.nodes],
                }
        for unbind in unbinds:
            for raw in unbind.args:
                modes[mode].pop(zellij_key(str(raw)), None)


def zellij_keybinds(keybinds, base: dict | None) -> dict:
    modes = {m: dict((base or {}).get(m, {})) for m in ZELLIJ_MODES}
    if keybinds is None:
        return modes
    if keybinds.props.get("clear-defaults") is True:
        modes = {m: {} for m in ZELLIJ_MODES}
    for block in keybinds.nodes:
        args = [str(a) for a in block.args]
        section = " ".join([block.name] + [f'"{a}"' for a in args])
        if block.name in ("shared", "shared_except"):
            zellij_block(modes, [m for m in ZELLIJ_MODES if m not in args], block, section)
        elif block.name == "shared_among":
            zellij_block(modes, [m for m in ZELLIJ_MODES if m in args], block, section)
    for block in keybinds.nodes:
        if block.name in ZELLIJ_MODES:
            if block.props.get("clear-defaults") is True:
                modes[block.name] = {}
            zellij_block(modes, [block.name], block, block.name)
    unbind = next((n for n in keybinds.nodes if n.name == "unbind"), None)
    if unbind is not None:
        for mode in ZELLIJ_MODES:
            for raw in unbind.args:
                modes[mode].pop(zellij_key(str(raw)), None)
    return modes


def first(doc, name: str):
    return next((n for n in doc.nodes if n.name == name), None)


def zellij_defaults() -> dict:
    dump = subprocess.run(["zellij", "setup", "--dump-config"], capture_output=True, text=True, check=True)
    return zellij_keybinds(first(kdl.parse(dump.stdout), "keybinds"), None)


def zellij() -> dict:
    root = config_dir("zellij", "ZELLIJ_CONFIG_DIR")
    path = root / "config.kdl"
    doc = kdl.parse(path.read_text())
    keybinds = first(doc, "keybinds")
    clear = keybinds is not None and keybinds.props.get("clear-defaults") is True
    options = {n.name: [str(a) for a in n.args] for n in doc.nodes if not n.nodes and n.args}
    return {
        "root": str(root),
        "file": str(path),
        "clear_defaults": clear,
        "default_mode": (options.get("default_mode") or ["normal"])[0],
        "support_kitty_keyboard_protocol": (options.get("support_kitty_keyboard_protocol") or ["true"])[0],
        "modes": zellij_keybinds(keybinds, None if clear else zellij_defaults()),
    }


if __name__ == "__main__":
    json.dump({"alacritty": alacritty(), "zellij": zellij()}, sys.stdout, ensure_ascii=False, indent=1)
