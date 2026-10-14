#!/usr/bin/env bash
# Codex for loop runs (assistants.codex.codexBinaryPath): no sub-agents (they pick their own models;
# features.multi_agent=false alone does not stop gpt-5.6-sol, openai/codex#50880, agents.enabled=false does), no
# user hooks (they inject extra skills),
# no computer use, browser, host-GUI or MCP tools (each adds tool schemas to every turn).
# Tool output (a command's stdout) is cut to 6000 tokens per call, so one wide read cannot flood the context.
# Fixed context per call: no skills catalog (steps name their skill; `$name` still injects it), no apps,
# no recommended plugins, no collaboration-mode or multi-agent usage hints, and no global ~/.codex/AGENTS.md:
# CODEX_HOME is a mirror of ~/.codex (symlinks, so auth, config, plugins and sessions stay in ~/.codex)
# without AGENTS.md. The repo's AGENTS.md (project doc) still loads. Everything else is the user's ~/.codex config.
set -euo pipefail

user_home=${CODEX_LOOP_USER_HOME:-$HOME/.codex}
loop_home=${CODEX_LOOP_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/nvim-loop/codex-home}

# Link every entry of ~/.codex into the loop home except the global instructions; a link is only
# (re)made when missing or wrong, so concurrent runs never see auth.json vanish.
mirror_user_home() {
    mkdir -p "$loop_home"
    local src name dst
    for src in "$user_home"/* "$user_home"/.[!.]*; do
        [[ -e $src || -L $src ]] || continue
        name=${src##*/}
        [[ $name == AGENTS.md || $name == AGENTS.override.md ]] && continue
        dst=$loop_home/$name
        [[ $(readlink "$dst" 2>/dev/null) == "$src" ]] || ln -sfn "$src" "$dst"
    done
    rm -f "$loop_home/AGENTS.md" "$loop_home/AGENTS.override.md"
}

mirror_user_home
export CODEX_HOME=$loop_home
export CODEX_SQLITE_HOME=${CODEX_SQLITE_HOME:-$user_home}

# Overrides go after the subcommand: `codex -c k=v exec` ignores them (codex-cli 0.153).
overrides=(
    -c features.multi_agent=false
    -c agents.enabled=false
    -c features.hooks=false
    -c 'features.multi_agent_v2.root_agent_usage_hint_text=""'
    -c 'features.multi_agent_v2.multi_agent_mode_hint_text=""'
    -c features.apps=false
    -c include_apps_instructions=false
    -c include_collaboration_mode_instructions=false
    -c features.tool_suggest=false
    -c skills.include_instructions=false
    -c tool_output_token_limit=6000
    -c mcp_servers.computer-use.enabled=false
    -c mcp_servers.node_repl.enabled=false
    -c mcp_servers.cograph.enabled=false
    -c mcp_servers.telegram.enabled=false
    -c 'plugins."computer-use@openai-bundled".enabled=false'
    -c 'plugins."unified-computer-use@openai-bundled".enabled=false'
    -c 'plugins."browser@openai-bundled".enabled=false'
    -c 'plugins."visualize@openai-bundled".enabled=false'
    -c 'plugins."codex-app-tools@openai-bundled".enabled=false'
    -c 'plugins."apple-photos@apple-photos-mcp".enabled=false'
)

codex=${CODEX_LOOP_BIN:-/opt/homebrew/bin/codex}
# Fail closed (exit 2, reasons on stderr) on an untested Codex or a GUI tool / MCP server left on.
python3 "$(dirname "${BASH_SOURCE[0]}")/codex_preflight.py" "$codex" "$user_home" -- "${overrides[@]}"

if [[ $# -gt 0 && $1 != -* ]]; then
    subcommand=$1
    shift
    exec "$codex" "$subcommand" "${overrides[@]}" "$@"
fi
exec "$codex" "${overrides[@]}" "$@"
