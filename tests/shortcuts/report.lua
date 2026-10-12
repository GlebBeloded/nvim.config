-- `make chain` report: the shortcut table as computed from the real configs.
-- Run: nvim -u tests/minimal_init.lua -l tests/shortcuts/report.lua
local H = require("tests.helpers")
local C = require("tests.shortcuts.chain")

local child = H.new_child()
child.start_config()
child.wait_very_lazy()

---@param lhs string?
---@return string
local function mapping(lhs)
	if not lhs then
		return "—"
	end
	local map = child.lua(
		[[local map = vim.fn.maparg(..., "n", false, true)
		if vim.tbl_isempty(map) then return "none" end
		return map.desc or (map.callback and "<Lua callback>") or map.rhs]],
		{ lhs }
	)
	return map
end

local rows = {}
for _, row in ipairs(C.shortcut_rows()) do
	local shortcut = C.shortcut(row.shortcut)
	local route = C.route(shortcut.bytes, "normal")
	local key = route.bytes ~= "" and C.decode(route.bytes) or nil
	table.insert(rows, {
		row.shortcut,
		shortcut.source,
		C.escape(shortcut.bytes),
		C.route_text(route),
		key and key.nvim or "—",
		mapping(key and key.nvim),
	})
end
child.stop()

local zellij = C.configs().zellij
io.write(
	string.format(
		"Shortcut chain (Alacritty %s, zellij %s, mode %s)\n",
		C.configs().alacritty.root,
		zellij.root,
		zellij.default_mode
	)
)
io.write(C.format_table({ "Shortcut", "Source", "Sends", "zellij", "Neovim", "Mapping" }, rows), "\n")
io.write("\nCollisions (spec: openspec/specs/shortcuts/spec.md, Collision table):\n")
for _, line in ipairs(C.collision_rows()) do
	io.write("  ", line, "\n")
end
io.flush()
