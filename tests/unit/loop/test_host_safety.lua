local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local YAML_TO_JSON = "import json,sys,yaml; print(json.dumps(yaml.safe_load(open(sys.argv[1]))))"

--- Lua patterns of a host application launch in shell, Python or a prompt. `open` counts only as a
--- command word (line start, after `;`, `&`, `|`, `(`, a backtick, `then`, `do`) or a quoted argv item,
--- so Python's `open(path)` and prose never match.
local LAUNCHERS = {
	"^%s*open%s",
	"[;&|(`]%s*open%s",
	"%f[%w]then%s+open%s",
	"%f[%w]do%s+open%s",
	"[\"']open[\"']%s*[,%]]",
	"/usr/bin/open%f[^%w]",
	"osascript",
	"xdg%-open",
	"webbrowser",
	"sensible%-browser",
	"x%-www%-browser",
	"vim%.ui%.open",
	"OPEN=1",
}

--- The first launcher pattern `line` matches.
---@param line string
---@return string?
local function launcher(line)
	for _, pattern in ipairs(LAUNCHERS) do
		if line:find(pattern) then
			return pattern
		end
	end
end

--- `file:line: text` of every line under `.archon/` that launches a host application.
---@return string[]
local function launches()
	local found = {}
	for _, path in ipairs(vim.fn.globpath(vim.fs.joinpath(H.root, ".archon"), "**/*", false, true)) do
		if vim.fn.filereadable(path) == 1 then
			for n, line in ipairs(vim.fn.readfile(path)) do
				if launcher(line) then
					table.insert(found, ("%s:%d: %s"):format(path:sub(#H.root + 2), n, line))
				end
			end
		end
	end
	return found
end

---@param path string repo-relative
---@return table
local function load_yaml(path)
	local result = H.system(child, { "python3", "-c", YAML_TO_JSON, path }, H.root)
	eq(result.code, 0, { fail_reason = path .. "\n" .. result.stderr })
	return vim.json.decode(result.stdout)
end

--- Every node of `workflow` with `id`, top-level and inside `loop_group`s.
---@param workflow { nodes: table[] }
---@param id string
---@return table[]
local function nodes(workflow, id)
	local found = {}
	for _, top in ipairs(workflow.nodes) do
		for _, node in ipairs(vim.list_extend({ top }, top.loop_group and top.loop_group.nodes or {})) do
			if node.id == id then
				table.insert(found, node)
			end
		end
	end
	return found
end

T["loop: Loop automation launches no host application"] = function()
	for _, line in ipairs({
		'if [ -n "$(OPEN)" ]; then open "$$out"; fi',
		'subprocess.run(["open", p])',
		"osascript -e x",
		"xdg-open x",
		"python3 -m webbrowser x",
		"make preview OPEN=1",
	}) do
		eq(launcher(line) ~= nil, true, { fail_reason = "scanner misses: " .. line })
	end
	eq(launcher("with open(path) as f:"), nil)
	eq(launches(), {})
end

T["loop: Design gate prints the preview path"] = function()
	local checked = 0
	for _, path in ipairs(vim.fn.glob(vim.fs.joinpath(H.root, ".archon/workflows/*/*.yaml"), false, true)) do
		local workflow = load_yaml(path:sub(#H.root + 2))
		for _, preview in ipairs(nodes(workflow, "preview")) do
			eq(
				preview.bash:match("^make %-s preview .* OPEN=$") ~= nil,
				true,
				{ fail_reason = path .. ": " .. preview.bash }
			)
			checked = checked + 1
		end
		for _, gate in ipairs(nodes(workflow, "design-gate")) do
			local message = gate.approval.message
			for _, needle in ipairs({ "$preview.output", "nothing opens on the host" }) do
				eq(
					message:find(needle, 1, true) ~= nil,
					true,
					{ fail_reason = path .. " design-gate lacks " .. needle }
				)
			end
		end
	end
	eq(checked >= 3, true, { fail_reason = "expected fix-bug, new-feature and work-queue preview nodes" })
end

T["loop: Preview prints the absolute preview path and opens nothing"] = function()
	local dir = H.tempdir(child)
	H.write_files(dir, {
		["openspec/changes/demo/proposal.md"] = "# Proposal",
		["bin/open"] = '#!/bin/sh\necho ran > "$(dirname "$0")/opened"',
	})
	child.lua(
		[[
        local dir, root = ...
        vim.uv.fs_chmod(dir .. "/bin/open", 493)
        vim.uv.fs_symlink(root .. "/Makefile", dir .. "/Makefile")
        vim.uv.fs_symlink(root .. "/ops", dir .. "/ops")
        ]],
		{ dir, H.root }
	)
	local env = { OPEN = "1", PATH = dir .. "/bin:" .. vim.env.PATH }
	local result = H.system(child, { "make", "-s", "preview", "CHANGE=demo", "OPEN=" }, dir, env)
	eq(result.code, 0, { fail_reason = result.stderr })
	local lines = vim.tbl_filter(function(line)
		return line ~= ""
	end, vim.split(result.stdout, "\n"))
	eq(lines, { dir .. "/openspec/changes/demo/preview.html" })
	eq(vim.fn.filereadable(dir .. "/bin/opened"), 0)
end

return T
