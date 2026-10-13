#!/usr/bin/env bash
# Codex for loop runs (assistants.codex.codexBinaryPath): no sub-agents (they pick their own models;
# features.multi_agent=false alone does not stop gpt-5.6-sol, openai/codex#50880, agents.enabled=false does), no
# user hooks (they inject extra skills),
# no computer use, browser, host-GUI or MCP tools (each adds tool schemas to every turn). Everything else is the user's ~/.codex config.
exec /opt/homebrew/bin/codex \
	-c features.multi_agent=false \
	-c agents.enabled=false \
	-c features.hooks=false \
	-c mcp_servers.computer-use.enabled=false \
	-c mcp_servers.node_repl.enabled=false \
	-c mcp_servers.cograph.enabled=false \
	-c mcp_servers.telegram.enabled=false \
	-c 'plugins."computer-use@openai-bundled".enabled=false' \
	-c 'plugins."unified-computer-use@openai-bundled".enabled=false' \
	-c 'plugins."browser@openai-bundled".enabled=false' \
	-c 'plugins."visualize@openai-bundled".enabled=false' \
	-c 'plugins."codex-app-tools@openai-bundled".enabled=false' \
	-c 'plugins."apple-photos@apple-photos-mcp".enabled=false' \
	"$@"
