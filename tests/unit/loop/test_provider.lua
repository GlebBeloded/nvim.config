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

return T
