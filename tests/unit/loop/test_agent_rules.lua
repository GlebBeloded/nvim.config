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

---@type string[] Plain-text needles `docs/CLAUDE.md` must contain to tell an agent how to operate the loop.
local OPERATING_NEEDLES = {
	"make fix",
	"make feature",
	"make queue",
	"make update",
	"make console",
	"`auto`",
	"make quick",
	"make check",
	"make e2e",
	"sandbox VM",
	"never posted on the host",
	"openspec/changes/*/proposal.md",
	"Decision",
}

--- Needles not found in `text`, in list order.
---@param text string
---@param needles string[]
---@return string[]
local function missing_needles(text, needles)
	return vim.tbl_filter(function(needle)
		return not text:find(needle, 1, true)
	end, needles)
end

T["loop: Agent rules cover how to operate the loop"] = function()
	local text = table.concat(vim.fn.readfile("docs/CLAUDE.md"), "\n")
	eq(missing_needles(text, OPERATING_NEEDLES), {})
end

return T
