#!/usr/bin/env python3
"""Refuse a loop Codex call on an untested Codex or with GUI tools or MCP servers left on.

Usage: codex_preflight.py <codex bin> <user Codex home> -- <the wrapper's -c overrides...>

Cheap, no model call: `<bin> --version`, the user's config.toml and the plugin cache's `.mcp.json`
files. Effective = configured minus what the wrapper's `enabled=false` overrides turn off. Refused:
any enabled MCP server (config or plugin-bundled) and any enabled GUI plugin. Exit 2 names them all.
"""

from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys
import tomllib

TESTED = ((0, 153, 0), (0, 154, 0))  # [min, max) codex-cli the overrides were checked against
GUI_PLUGIN = re.compile(r"computer-use|browser|chrome|visualize|app-tools|photos|screen", re.I)
DISABLED = re.compile(r'^(mcp_servers|plugins)\.(?:"([^"]+)"|([^.]+))\.enabled=false$')


def version(binary: str) -> tuple[int, ...] | None:
    out = subprocess.run([binary, "--version"], capture_output=True, text=True, check=False).stdout
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", out)
    return tuple(int(part) for part in match.groups()) if match else None


def disabled(overrides: list[str]) -> dict[str, set[str]]:
    """Names the wrapper's `-c <table>.<name>.enabled=false` overrides turn off, by table."""
    off: dict[str, set[str]] = {"mcp_servers": set(), "plugins": set()}
    for value in overrides:
        match = DISABLED.match(value)
        if match:
            off[match[1]].add(match[2] or match[3])
    return off


def bundled_servers(home: pathlib.Path, plugin: str) -> list[str]:
    """Enabled MCP servers in the cached `.mcp.json` of `<name>@<marketplace>`."""
    name, _, marketplace = plugin.partition("@")
    servers = []
    for path in home.glob(f"plugins/cache/{marketplace}/{name}/*/.mcp.json"):
        try:
            declared = json.loads(path.read_text()).get("mcpServers", {})
        except (OSError, ValueError):
            declared = {"<unreadable .mcp.json>": {}}
        servers += [server for server, spec in declared.items() if spec.get("enabled", True) is not False]
    return servers


def cached_plugins(home: pathlib.Path) -> set[str]:
    return {f"{d.name}@{d.parent.name}" for d in home.glob("plugins/cache/*/*") if d.is_dir()}


def unsafe_tools(home: pathlib.Path, overrides: list[str]) -> list[str]:
    try:
        config = tomllib.loads((home / "config.toml").read_text())
    except FileNotFoundError:
        config = {}
    off = disabled(overrides)
    found = [
        f"MCP server {name}"
        for name, spec in config.get("mcp_servers", {}).items()
        if spec.get("enabled", True) is not False and name not in off["mcp_servers"]
    ]
    plugins = config.get("plugins", {})
    for plugin in sorted(cached_plugins(home) | set(plugins)):
        if plugin in off["plugins"] or plugins.get(plugin, {}).get("enabled", True) is False:
            continue
        if GUI_PLUGIN.search(plugin):
            found.append(f"GUI plugin {plugin}")
        found += [f"MCP server {server} (plugin {plugin})" for server in bundled_servers(home, plugin)]
    return found


def main(argv: list[str]) -> int:
    binary, home, overrides = argv[0], pathlib.Path(argv[1]), argv[3:]
    errors = []
    found = version(binary)
    if found is None or not TESTED[0] <= found < TESTED[1]:
        shown = ".".join(map(str, found)) if found else "unknown"
        low, high = (".".join(map(str, v)) for v in TESTED)
        errors.append(f"codex-cli {shown} is outside the tested range [{low}, {high}) of codex_preflight.py")
    errors += [f"{tool} is enabled; turn it off with a -c override in codex-loop.sh" for tool in unsafe_tools(home, overrides)]
    for error in errors:
        print(f"codex-loop: refusing to run: {error}", file=sys.stderr)
    return 2 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
