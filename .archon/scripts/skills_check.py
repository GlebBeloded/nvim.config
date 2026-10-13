"""Skill preflight: fail a run whose workflow nodes declare `skills:` that do not resolve in this
worktree. Archon only warns for `plugin:skill` names and the SDK treats `skills:` as an allowlist, so
a missing plugin would otherwise go unnoticed. A project skill needs `.claude/skills/<name>/SKILL.md`;
a `<plugin>:<skill>` needs the plugin reported enabled without errors by `claude plugin list --json`
(run in the worktree, so scope and path problems show) and `<installPath>/skills/<skill>/SKILL.md`.
Usage: skills_check.py <workflow.yaml>...
"""

import json
import pathlib
import subprocess
import sys


def declared_skills(workflow: dict) -> list[str]:
    """Every skill name the workflow's nodes declare, loop nodes included."""

    def walk(nodes: list[dict]) -> list[str]:
        names = []
        for node in nodes:
            names += node.get("skills") or []
            names += walk((node.get("loop_group") or node.get("loop") or {}).get("nodes") or [])
        return names

    return walk(workflow.get("nodes") or [])


def project_skill_ok(name: str) -> bool:
    return pathlib.Path(".claude/skills", name, "SKILL.md").is_file()


def loaded_plugins() -> dict[str, dict]:
    """Plugins Claude Code would load here (enabled, no errors), keyed by name (id before `@`)."""
    proc = subprocess.run(["claude", "plugin", "list", "--json"], capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(f"skills_check: `claude plugin list --json` failed: {proc.stderr.strip()}")
    return {
        plugin["id"].split("@")[0]: plugin
        for plugin in json.loads(proc.stdout)
        if plugin.get("enabled") and not plugin.get("errors")
    }


def plugin_skill_ok(name: str, plugins: dict[str, dict]) -> bool:
    plugin_name, skill = name.split(":", 1)
    plugin = plugins.get(plugin_name)
    return plugin is not None and pathlib.Path(plugin["installPath"], "skills", skill, "SKILL.md").is_file()


def unresolved(names: list[str]) -> list[str]:
    plugins = loaded_plugins() if any(":" in name for name in names) else {}
    return [
        name
        for name in names
        if not (plugin_skill_ok(name, plugins) if ":" in name else project_skill_ok(name))
    ]


def main(paths: list[str]) -> int:
    import yaml

    names = sorted({name for path in paths for name in declared_skills(yaml.safe_load(pathlib.Path(path).read_text()))})
    missing = unresolved(names)
    if missing:
        print(
            "skills_check: declared skills do not resolve in this worktree: "
            + ", ".join(missing)
            + ". Run `make loop-setup` (installs the plugins .claude/settings.json enables).",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
