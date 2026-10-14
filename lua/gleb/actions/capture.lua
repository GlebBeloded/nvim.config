-- Shortcut capture keeps key editing and scope-aware conflict detection independent from UI.

---@class gleb.ShortcutConflict
---@field action_id string
---@field lhs string
---@field proposed_lhs string

local M = {}

---@param action gleb.Action
---@return string[]
local function modes(action)
	return action.modes or { "n" }
end

---@param left gleb.Action
---@param right gleb.Action
---@return boolean
local function modes_overlap(left, right)
	for _, left_mode in ipairs(modes(left)) do
		if vim.tbl_contains(modes(right), left_mode) then
			return true
		end
	end
	return false
end

---@param left gleb.Action
---@param right gleb.Action
---@return boolean
local function scopes_overlap(left, right)
	if left.ft or right.ft then
		return left.ft ~= nil and left.ft == right.ft
	end
	return true
end

---@param left string
---@param right string
---@return boolean
local function lhs_overlaps(left, right)
	return left:sub(1, #right) == right or right:sub(1, #left) == left
end

---@param read_key? fun(): string
---@return string?
function M.capture(read_key)
	read_key = read_key or vim.fn.getcharstr
	local keys = {}
	while true do
		local key = vim.fn.keytrans(read_key())
		if key == "<CR>" then
			return table.concat(keys)
		elseif key == "<Esc>" then
			return nil
		elseif key == "<BS>" then
			table.remove(keys)
		else
			table.insert(keys, key)
		end
	end
end

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@param action_id string
---@param proposed_lhs string
---@return gleb.ShortcutConflict[]
function M.conflicts(catalog, shortcuts, action_id, proposed_lhs)
	local action = assert(catalog:get(action_id), "unknown action id: " .. action_id)
	local conflicts = {}
	for _, other in ipairs(catalog.actions) do
		if other.id ~= action.id and modes_overlap(action, other) and scopes_overlap(action, other) then
			for _, lhs in ipairs(shortcuts[other.id] or {}) do
				if lhs_overlaps(proposed_lhs, lhs) then
					table.insert(conflicts, {
						action_id = other.id,
						lhs = lhs,
						proposed_lhs = proposed_lhs,
					})
				end
			end
		end
	end
	return conflicts
end

return M
