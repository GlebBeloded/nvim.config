-- Chain layer: the real Alacritty and zellij configs (parsed, not run) and the
-- real Neovim config (child) against the shortcut table in the spec.
local MiniTest = require("mini.test")
local H = require("tests.helpers")
local C = require("tests.shortcuts.chain")

local child = H.new_child()
local MAP_MODES = { "n", "x", "s", "o", "i", "c", "t" }

--- maparg() in the child without the callback (functions do not cross RPC).
local MAPARG = [[local map = vim.fn.maparg(...)
	if vim.tbl_isempty(map) then return {} end
	return { rhs = map.rhs, desc = map.desc, callback = map.callback ~= nil }]]

---@param lhs string
---@param mode string
---@return { rhs?: string, desc?: string, callback?: boolean }
local function maparg(lhs, mode)
	return child.lua(MAPARG, { lhs, mode, false, true })
end

local T = MiniTest.new_set({
	hooks = {
		pre_once = function()
			child.start_config()
			child.wait_very_lazy()
		end,
		post_once = child.stop,
	},
})

--- Fail with one line per mismatch so a red run reads like a diff.
---@param problems string[]
local function expect_none(problems)
	if #problems > 0 then
		error(table.concat(problems, "\n"), 0)
	end
end

---@param row shortcuts.Row
---@return string
local function label(row)
	return string.format("%-20s %-12s", row.shortcut, C.escape(row.bytes))
end

--- Does the normal-mode mapping of `lhs` match a *Mapping* cell of the spec?
---@param lhs string
---@param cell string
---@return boolean ok, string actual
local function mapping_matches(lhs, cell)
	local map = maparg(lhs, "n")
	local actual = vim.tbl_isempty(map) and "none" or (map.callback and "fn") or ("`" .. map.rhs .. "`")
	if map.desc then
		actual = actual .. " desc `" .. map.desc .. "`"
	end
	local expr = cell:match("^fn `(.+)`$")
	if expr then
		local same = child.lua_get(string.format("vim.fn.maparg(..., 'n', false, true).callback == %s", expr), { lhs })
		return same, actual
	end
	local desc = cell:match("^desc `(.+)`$")
	if desc then
		return map.desc == desc, actual
	end
	if cell == "fn" then
		return map.callback == true, actual
	end
	if cell == "none" then
		return vim.tbl_isempty(map), actual
	end
	local rhs = cell:match("^`(.+)`$")
	return rhs ~= nil and map.rhs ~= nil and map.rhs:lower() == rhs:lower(), actual
end

T["shortcuts: Alacritty bindings match the shortcut table"] = function()
	local bindings = C.alacritty_chars()
	local problems, seen = {}, {}
	for _, row in ipairs(C.shortcut_rows()) do
		seen[row.shortcut] = true
		local actual = C.shortcut(row.shortcut)
		if actual.source ~= row.source or actual.bytes ~= row.bytes then
			table.insert(
				problems,
				string.format(
					"%s spec %s, Alacritty %s %s",
					label(row),
					row.source,
					actual.source,
					C.escape(actual.bytes)
				)
			)
		end
	end
	for physical, binding in pairs(bindings) do
		if not seen[physical] then
			table.insert(
				problems,
				string.format("%s %s: chars binding missing from the spec", physical, C.escape(binding.bytes))
			)
		end
	end
	expect_none(problems)
end

T["shortcuts: Every Alacritty chars binding can match a key press"] = function()
	expect_none(C.unreachable_chars())
end

T["shortcuts: zellij routes every shortcut as in the table"] = function()
	local problems = {}
	for _, row in ipairs(C.shortcut_rows()) do
		local actual = C.route_text(C.route(row.bytes, "normal"))
		if actual ~= row.zellij then
			table.insert(problems, string.format("%s spec %q, zellij %q", label(row), row.zellij, actual))
		end
	end
	expect_none(problems)
end

T["shortcuts: Locked mode passes every shortcut through"] = function()
	local problems = {}
	for _, row in ipairs(C.shortcut_rows()) do
		local route = C.route(row.bytes, "locked")
		if route.kind ~= "pass" then
			table.insert(problems, string.format("%s locked: %s", label(row), C.route_text(route)))
		end
	end
	expect_none(problems)
end

T["shortcuts: Neovim receives the key in the table"] = function()
	local problems = {}
	for _, row in ipairs(C.shortcut_rows()) do
		local written = C.route(row.bytes, "normal").bytes
		local key = written ~= "" and C.decode(written) or nil
		local actual = key and key.nvim or nil
		if actual ~= row.receives then
			table.insert(
				problems,
				string.format("%s spec %s, Neovim %s", label(row), row.receives or "—", actual or "—")
			)
		end
	end
	expect_none(problems)
end

T["shortcuts: Neovim mappings match the table"] = function()
	local problems = {}
	for _, row in ipairs(C.shortcut_rows()) do
		if row.receives then
			local callback_mappings = {
				["Cmd+9"] = "none",
				["Cmd+Shift+F"] = 'fn `require("gleb.picker").grep_live`',
				["Cmd+Shift+A"] = 'fn `require("gleb.find_action").open`',
			}
			local mapping = callback_mappings[row.shortcut] or row.mapping
			local ok, actual = mapping_matches(row.receives, mapping)
			if not ok then
				table.insert(
					problems,
					string.format("%s %s spec %s, config %s", label(row), row.receives, mapping, actual)
				)
			end
		end
	end
	expect_none(problems)
end

--- Modes in which `lhs` has a global mapping in the child.
---@param lhs string
---@return string[]
local function mapped_modes(lhs)
	return vim.tbl_filter(function(mode)
		return not vim.tbl_isempty(maparg(lhs, mode))
	end, MAP_MODES)
end

---@return string[] "key | action | nvim key | modes", sorted
local function collisions()
	local rows = {}
	local function add(zkey, action, lhs)
		local modes = mapped_modes(lhs)
		table.sort(modes)
		if #modes > 0 then
			table.insert(rows, table.concat({ zkey, action, lhs, table.concat(modes, " ") }, " | "))
		end
	end
	for _, bind in ipairs(C.consumed("normal")) do
		add(bind.key, bind.action, C.zellij_to_nvim(bind.key))
	end
	for zkey in pairs(C.configs().zellij.modes.normal) do
		local lhs = C.zellij_to_nvim(zkey)
		local route = C.route_key(zkey, "", "normal")
		local written = route.kind == "navigator" and C.decode(route.bytes)
		if written and written.nvim ~= lhs then
			add(zkey, C.route_text(route), lhs)
		end
	end
	table.sort(rows)
	return rows
end

T["shortcuts: Collision report matches the collision table"] = function()
	local expected = C.collision_rows()
	table.sort(expected)
	MiniTest.expect.equality(collisions(), expected)
end

return T
