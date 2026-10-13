local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local YAML_TO_JSON = "import json,sys,yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1]))))"

--- This checkout's `path` (repo-relative), parsed by PyYAML.
---@param path string
---@return table
local function load_yaml(path)
	local result = H.system(child, { "python3", "-c", YAML_TO_JSON, path }, H.root)
	eq(result.code, 0, { fail_reason = path .. "\n" .. result.stderr })
	return vim.json.decode(result.stdout)
end

--- Node `id` of `workflow`, searched among top-level and `loop_group.nodes`.
---@param workflow { nodes: table[] }
---@param id string
---@return table?
local function find_node(workflow, id)
	for _, top in ipairs(workflow.nodes) do
		if top.id == id then
			return top
		end
		for _, inner in ipairs(top.loop_group and top.loop_group.nodes or {}) do
			if inner.id == id then
				return inner
			end
		end
	end
end

T["loop: Default provider is codex with the chosen model"] = function()
	local cfg = load_yaml(".archon/config.yaml")
	eq(cfg.assistant, "codex")
	eq(cfg.assistants.codex.model, "gpt-5.6-sol")
	eq(cfg.assistants.codex.modelReasoningEffort, "medium")
	eq(cfg.assistants.claude ~= nil, true)
end

T["loop: Review runs on claude"] = function()
	local review = find_node(load_yaml(".archon/workflows/nvim-deliver/nvim-deliver.yaml"), "review") or {}
	eq(review.provider, "claude")
end

T["loop: Configured provider resolves every declared skill here"] = function()
	if child.lua_get("vim.fn.executable('codex') == 0 or vim.fn.executable('claude') == 0") then
		MiniTest.skip("codex or claude not on PATH")
	end
	local workflows = vim.fn.glob(vim.fs.joinpath(H.root, ".archon/workflows/*/*.yaml"), false, true)
	local result = H.system(child, vim.list_extend({ "python3", ".archon/scripts/skills_check.py" }, workflows), H.root)
	eq(result.code, 0, { fail_reason = result.stderr })
end

T["loop: Provider switch is documented"] = function()
	local text = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, "docs/workflow.md")), "\n")
	for _, needle in ipairs({ "assistant: codex", "assistant: claude", "provider: claude" }) do
		eq(text:find(needle, 1, true) ~= nil, true, { fail_reason = "docs/workflow.md lacks " .. needle })
	end
end

local WRAPPER = ".archon/scripts/codex-loop.sh"
local STUB = [[#!/bin/sh
if [ "$1" = --version ]; then echo "codex-cli ${STUB_VERSION:-0.153.4}"; exit 0; fi
printf "%s\n" "$CODEX_HOME" "$@" > "$STUB_LOG"
]]

---@class test.WrapperOpts
---@field files? table<string, string> user Codex home files (path -> content); default config.toml is empty
---@field version? string what the stub's `--version` reports
---@field code? integer expected exit code (default 0)

---@class test.WrapperRun
---@field args string[] stub arguments, empty when the stub never ran `exec`
---@field codex_home? string `CODEX_HOME` the stub saw
---@field stderr string
---@field user_home string
---@field loop_home string

--- Runs the Codex wrapper with `args` against a stub codex and a fake user Codex home.
---@param args string[]
---@param opts? test.WrapperOpts
---@return test.WrapperRun
local function run_wrapper(args, opts)
	opts = opts or {}
	local dir = H.tempdir(child)
	local user_home, loop_home = dir .. "/user", dir .. "/loop"
	local stub, log = dir .. "/codex", dir .. "/stub.log"
	local files =
		vim.tbl_extend("force", { ["AGENTS.md"] = "", ["auth.json"] = "{}", ["config.toml"] = "" }, opts.files or {})
	child.lua(
		[[
        local user_home, files, stub, script = ...
        vim.fn.mkdir(user_home .. "/sessions", "p")
        for name, content in pairs(files) do
            vim.fn.mkdir(vim.fs.dirname(user_home .. "/" .. name), "p")
            vim.fn.writefile(vim.split(content, "\n"), user_home .. "/" .. name)
        end
        vim.fn.writefile(vim.split(script, "\n"), stub)
        vim.uv.fs_chmod(stub, 493)
        ]],
		{ user_home, files, stub, STUB }
	)
	local env = {
		CODEX_LOOP_BIN = stub,
		CODEX_LOOP_USER_HOME = user_home,
		CODEX_LOOP_HOME = loop_home,
		STUB_LOG = log,
		STUB_VERSION = opts.version or "0.153.4",
	}
	local result = H.system(child, vim.list_extend({ "bash", WRAPPER }, args), H.root, env)
	eq(result.code, opts.code or 0, { fail_reason = result.stderr })
	local lines = child.lua_get("vim.fn.filereadable(...) == 1 and vim.fn.readfile(...) or {}", { log })
	return {
		codex_home = table.remove(lines, 1),
		args = lines,
		stderr = result.stderr,
		user_home = user_home,
		loop_home = loop_home,
	}
end

--- Asserts the wrapper refused (exit 2) without running Codex and named every `needles` on stderr.
---@param run test.WrapperRun
---@param needles string[]
local function expect_refused(run, needles)
	eq(run.args, {})
	for _, needle in ipairs(needles) do
		eq(
			run.stderr:find(needle, 1, true) ~= nil,
			true,
			{ fail_reason = "stderr lacks " .. needle .. ":\n" .. run.stderr }
		)
	end
end

T["loop: Codex wrapper passes its overrides after the subcommand"] = function()
	local run = run_wrapper({ "exec", "--experimental-json" })
	eq(run.args[1], "exec")
	eq(run.args[#run.args], "--experimental-json")
	for _, override in ipairs({
		"skills.include_instructions=false",
		"features.apps=false",
		"features.tool_suggest=false",
		"include_collaboration_mode_instructions=false",
		"agents.enabled=false",
		"features.hooks=false",
	}) do
		eq(vim.tbl_contains(run.args, override), true, { fail_reason = "missing -c " .. override })
	end
end

T["loop: Codex wrapper home mirrors the user's Codex home without global instructions"] = function()
	local run = run_wrapper({ "exec" })
	eq(run.codex_home, run.loop_home)
	for _, name in ipairs({ "auth.json", "config.toml", "sessions" }) do
		eq(child.lua_get("vim.uv.fs_realpath(...)", { run.loop_home .. "/" .. name }), run.user_home .. "/" .. name)
	end
	eq(child.lua_get("vim.uv.fs_lstat(...) == nil", { run.loop_home .. "/AGENTS.md" }), true)
end

T["loop: Codex wrapper refuses an untested Codex version"] = function()
	expect_refused(run_wrapper({ "exec" }, { version = "0.99.0", code = 2 }), { "0.99.0", "tested range" })
end

T["loop: Codex wrapper refuses an MCP server or GUI plugin it does not turn off"] = function()
	local config = '[mcp_servers.extra]\ncommand = "x"\n[plugins."chrome-pilot@m"]\nenabled = true\n'
	local run = run_wrapper({ "exec" }, { files = { ["config.toml"] = config }, code = 2 })
	expect_refused(run, { "MCP server extra", "GUI plugin chrome-pilot@m" })
end

T["loop: Codex wrapper refuses a plugin's bundled MCP server"] = function()
	local mcp = vim.json.encode({ mcpServers = { ["tool-server"] = { command = "x" } } })
	local run = run_wrapper({ "exec" }, { files = { ["plugins/cache/m/tool/1.0/.mcp.json"] = mcp }, code = 2 })
	expect_refused(run, { "MCP server tool-server (plugin tool@m)" })
end

T["loop: Codex wrapper runs when every GUI tool and MCP server is off"] = function()
	local config = table.concat({
		"[mcp_servers.computer-use]",
		'command = "x"',
		"[mcp_servers.idle]",
		'command = "x"',
		"enabled = false",
		'[plugins."browser@openai-bundled"]',
		"enabled = true",
	}, "\n")
	local run = run_wrapper({ "exec" }, { files = { ["config.toml"] = config }, version = "0.153.4" })
	eq(run.args[1], "exec")
end

return T
