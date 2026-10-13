"""Skill preflight: fail a run whose workflow nodes declare `skills:` that do not resolve in this
worktree for the provider that runs them. Archon only warns for `plugin:skill` names, the Claude SDK
treats `skills:` as an allowlist and Codex ignores it, so a missing skill would otherwise go unnoticed.
A node's provider is its `provider:`, else its loop node's, else `assistant:` of `.archon/config.yaml`,
else claude.
- claude: a project skill needs `.claude/skills/<name>/SKILL.md`; a `<plugin>:<skill>` needs the
  plugin reported enabled without errors by `claude plugin list --json` (run in the worktree, so scope
  and path problems show) and `<installPath>/skills/<skill>/SKILL.md`.
- codex: a project skill needs `.agents/skills/<name>/SKILL.md`; a `<plugin>:<skill>` needs the plugin
  reported installed and enabled by `codex plugin list --json` and `<root>/skills/<skill>/SKILL.md`, where
  `<root>` is its `source.path` (a local plugin), else the Codex plugin cache
  `${CODEX_HOME:-~/.codex}/plugins/cache/<marketplaceName>/<name>/<version>` (a remote plugin).
`--install-plugins` (run by `make loop-setup`) instead installs at user scope every plugin that
`.claude/settings.json` enables and Claude does not load (project scope is recorded per path, and
every Archon run has a new worktree path), and every Codex plugin the given workflows' codex nodes
declare and Codex does not have.
Usage: skills_check.py <workflow.yaml>... | skills_check.py --install-plugins [workflow.yaml...]
"""

import json
import os
import pathlib
import shutil
import subprocess
import sys

PROJECT_SKILL_DIRS = {"claude": ".claude/skills", "codex": ".agents/skills"}
# Codex has no project plugin manifest like `.claude/settings.json`: plugins come from this marketplace.
CODEX_MARKETPLACE = "openai-curated-remote"


def configured_assistant() -> str:
    """`assistant:` of `.archon/config.yaml`, else claude."""
    config = pathlib.Path(".archon/config.yaml")
    if not config.is_file():
        return "claude"
    import yaml

    return (yaml.safe_load(config.read_text()) or {}).get("assistant") or "claude"


def declared_skills_by_provider(workflow: dict, default: str) -> dict[str, list[str]]:
    """Every skill name the workflow's nodes declare, loop nodes included, keyed by node provider."""
    by_provider: dict[str, list[str]] = {}

    def walk(nodes: list[dict], inherited: str) -> None:
        for node in nodes:
            provider = node.get("provider") or inherited
            by_provider.setdefault(provider, []).extend(node.get("skills") or [])
            walk((node.get("loop_group") or node.get("loop") or {}).get("nodes") or [], provider)

    walk(workflow.get("nodes") or [], default)
    return by_provider


def run_plugin_list(cli: str) -> subprocess.CompletedProcess:
    """`<cli> plugin list --json`; exits with a message naming `cli` when it fails."""
    try:
        proc = subprocess.run([cli, "plugin", "list", "--json"], capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit(f"skills_check: `{cli}` is not on PATH")
    if proc.returncode != 0:
        sys.exit(f"skills_check: `{cli} plugin list --json` failed: {proc.stderr.strip()}")
    return proc


def plugin_list(cli: str) -> object:
    """Parsed `<cli> plugin list --json`."""
    return json.loads(run_plugin_list(cli).stdout)


# `codex plugin list` still exits 0 but omits every remote plugin when its catalog request fails
# (offline, or slow under load), warning on stderr.
CODEX_REMOTE_FAILED = "failed to list remote marketplace plugins"
CODEX_REMOTE_MARK = ".codex-remote-plugin-install.json"  # a remote install in the plugin cache


def codex_home() -> pathlib.Path:
    return pathlib.Path(os.environ.get("CODEX_HOME") or pathlib.Path.home() / ".codex")


def cached_remote_plugins() -> list[dict]:
    """Remote plugins installed in the Codex plugin cache, at their newest cached version."""
    plugins = []
    for mark in sorted(codex_home().glob(f"plugins/cache/*/*/{CODEX_REMOTE_MARK}")):
        versions = sorted(path.name for path in mark.parent.iterdir() if path.is_dir())
        if versions:
            name, market = mark.parent.name, mark.parent.parent.name
            plugins.append({"name": name, "marketplaceName": market, "version": versions[-1], "installed": True, "enabled": True})
    return plugins


def codex_installed() -> list[dict]:
    """`installed` of `codex plugin list --json`, plus the cached remote plugins when the remote
    catalog request failed (so the preflight never depends on the network)."""
    proc = run_plugin_list("codex")
    installed = json.loads(proc.stdout).get("installed") or []
    if CODEX_REMOTE_FAILED in proc.stderr:
        listed = {plugin.get("name") for plugin in installed}
        installed += [plugin for plugin in cached_remote_plugins() if plugin["name"] not in listed]
    return installed


def claude_plugins() -> dict[str, dict]:
    """Plugins Claude Code would load here (enabled, no errors), keyed by name (id before `@`)."""
    return {
        plugin["id"].split("@")[0]: plugin
        for plugin in plugin_list("claude")
        if plugin.get("enabled") and not plugin.get("errors")
    }


def codex_plugins(*, include_disabled: bool = False) -> dict[str, dict]:
    """Plugins Codex has installed (and enabled, unless `include_disabled`), keyed by name."""
    return {
        plugin["name"]: plugin
        for plugin in codex_installed()
        if plugin.get("installed") and (include_disabled or plugin.get("enabled"))
    }


def codex_plugin_root(plugin: dict) -> pathlib.Path | None:
    """`source.path` of a local plugin, else its Codex plugin cache dir; None when a field is missing."""
    path = (plugin.get("source") or {}).get("path")
    if path:
        return pathlib.Path(path)
    parts = [plugin.get(key) for key in ("marketplaceName", "name", "version")]
    if not all(parts):
        return None
    return codex_home().joinpath("plugins", "cache", *parts)


def claude_plugin_root(plugin: dict) -> pathlib.Path | None:
    """`installPath` of a Claude plugin; None when it is missing."""
    path = plugin.get("installPath")
    return pathlib.Path(path) if path else None


def plugin_skill_path(provider: str, plugin: dict, skill: str) -> pathlib.Path | None:
    root = claude_plugin_root(plugin) if provider == "claude" else codex_plugin_root(plugin)
    return root and root / "skills" / skill / "SKILL.md"


USER_SKILLS = pathlib.Path(os.environ.get("AGENTS_SKILLS_DIR") or pathlib.Path.home() / ".agents" / "skills")
COPY_MARK = ".copied-by-nvim-loop"  # only copies carrying this mark are ever replaced


def codex_skill_copy(skill: str) -> pathlib.Path:
    """Codex `codex exec` loads no plugin skills, only real (not symlinked) skill folders such as
    ~/.agents/skills/<skill>, invoked as `$<skill>`; loop-setup copies each plugin skill there."""
    return USER_SKILLS / skill / "SKILL.md"


def unresolved(provider: str, names: list[str]) -> list[str]:
    if any(":" in name for name in names):
        plugins = claude_plugins() if provider == "claude" else codex_plugins()
    else:
        plugins = {}

    def resolves(name: str) -> bool:
        if ":" not in name:
            return pathlib.Path(PROJECT_SKILL_DIRS[provider], name, "SKILL.md").is_file()
        plugin_name, skill = name.split(":", 1)
        plugin = plugins.get(plugin_name)
        if plugin is None:
            return False
        path = plugin_skill_path(provider, plugin, skill)
        if provider == "codex":
            copy = codex_skill_copy(skill)
            return path is not None and path.is_file() and copy.is_file() and not copy.parent.is_symlink()
        return path is not None and path.is_file()

    return [name for name in names if not resolves(name)]


def skills_by_provider(paths: list[str]) -> dict[str, list[str]]:
    """Declared skills of every existing workflow in `paths`, merged per provider and sorted."""
    paths = [path for path in paths if pathlib.Path(path).is_file()]
    if not paths:
        return {}
    import yaml  # only workflows need PyYAML; --install-plugins with none stays stdlib only

    default = configured_assistant()
    merged: dict[str, set[str]] = {}
    for path in paths:
        for provider, names in declared_skills_by_provider(yaml.safe_load(pathlib.Path(path).read_text()), default).items():
            merged.setdefault(provider, set()).update(names)
    return {provider: sorted(names) for provider, names in merged.items()}


def enabled_plugins() -> list[str]:
    settings = pathlib.Path(".claude/settings.json")
    enabled = json.loads(settings.read_text()).get("enabledPlugins") or {} if settings.is_file() else {}
    return [plugin_id for plugin_id, on in enabled.items() if on]


def install_claude_plugins() -> int:
    enabled = enabled_plugins()
    loaded = claude_plugins() if enabled else {}
    for plugin_id in enabled:
        if plugin_id.split("@")[0] not in loaded:
            print(f"skills_check: installing {plugin_id} at user scope", flush=True)
            if subprocess.run(["claude", "plugin", "install", plugin_id, "--scope", "user"]).returncode != 0:
                return 1
    return 0


def install_codex_plugins(paths: list[str]) -> int:
    names = skills_by_provider(paths).get("codex") or []
    wanted = sorted({name.split(":", 1)[0] for name in names if ":" in name})
    installed = codex_plugins(include_disabled=True) if wanted else {}
    for plugin in wanted:
        if plugin in installed:
            if not installed[plugin].get("enabled"):
                print(f"skills_check: Codex plugin {plugin} is installed but disabled; enable it in Codex", flush=True)
            continue
        print(f"skills_check: installing Codex plugin {plugin}@{CODEX_MARKETPLACE}", flush=True)
        if subprocess.run(["codex", "plugin", "add", f"{plugin}@{CODEX_MARKETPLACE}"]).returncode != 0:
            return 1
    return copy_codex_skills(names)


def copy_codex_skills(names: list[str]) -> int:
    """Fresh copy of every declared `<plugin>:<skill>` into USER_SKILLS, so plugin updates reach Codex."""
    plugins = codex_plugins() if any(":" in n for n in names) else {}
    for name in [n for n in names if ":" in n]:
        plugin_name, skill = name.split(":", 1)
        source = plugins.get(plugin_name) and plugin_skill_path("codex", plugins[plugin_name], skill)
        target = USER_SKILLS / skill
        if not source or not source.is_file():  # the run preflight then fails and names it
            print(f"skills_check: {name} not found in the Codex plugin cache; not copied", file=sys.stderr)
            continue
        if target.exists() and not (target / COPY_MARK).exists():
            print(f"skills_check: {target} exists and is not a loop copy; leaving it", file=sys.stderr)
            continue
        shutil.rmtree(target, ignore_errors=True)
        shutil.copytree(source.parent, target, symlinks=False)
        (target / COPY_MARK).write_text(f"{name}\n")
    return 0


def install_plugins(paths: list[str]) -> int:
    return install_claude_plugins() or install_codex_plugins(paths)


def main(args: list[str]) -> int:
    if args[:1] == ["--install-plugins"]:
        return install_plugins(args[1:])
    missing = [
        f"{name} ({provider})"
        for provider, names in skills_by_provider(args).items()
        for name in unresolved(provider, names)
    ]
    if missing:
        print(
            "skills_check: declared skills do not resolve in this worktree: "
            + ", ".join(missing)
            + ". Run `make loop-setup` (installs the Claude and Codex plugins the loop needs).",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
