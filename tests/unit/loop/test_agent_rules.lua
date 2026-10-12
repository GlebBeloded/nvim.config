local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

--- Real path of `name`, or nil when it is not a symlink (readlink fails).
---@param name string Repo-root relative path.
---@return string?
local function symlink_target(name)
	if not vim.uv.fs_readlink(name) then
		return nil
	end
	return vim.uv.fs_realpath(name)
end

T["loop: AGENTS.md resolves to the agent rules"] = function()
	local rules = vim.uv.fs_realpath("docs/CLAUDE.md")
	for _, name in ipairs({ "CLAUDE.md", "AGENTS.md" }) do
		eq({ name, symlink_target(name) }, { name, rules })
	end
end

return T
