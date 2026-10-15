-- Ownership audit: every pressable global mapping is assigned to a registered action or is Neovim grammar.

local M = {}

local MODES = { "n", "x", "s", "o", "i", "c", "t" }

-- Neovim defaults that refine built-in keys, operators, motions and text objects (matchit included).
local GRAMMAR = {
	n = { "Y", "&", "gc", "gcc", "%", "g%", "[%", "]%" },
	x = { "*", "#", "@", "Q", "gc", "an", "in", "[n", "]n", "[N", "]N", "%", "g%", "[%", "]%", "a%" },
	o = { "gc", "an", "in", "%", "g%", "[%", "]%" },
	s = { "<Tab>", "<S-Tab>" },
	i = { "<C-U>", "<C-W>", "<Tab>", "<S-Tab>" },
}

---@param keys table<string, true>
---@param lhs_list string[]
local function add_keys(keys, lhs_list)
	for _, lhs in ipairs(lhs_list) do
		keys[vim.keycode(lhs)] = true
	end
end

---@param action? gleb.Action
---@return string[]
local function action_modes(action)
	if not action then
		return {}
	end
	return action.modes or { "n" }
end

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@return table<string, table<string, true>> keys allowed per mode
local function allowed_keys(catalog, shortcuts)
	local allowed = {}
	for _, mode in ipairs(MODES) do
		allowed[mode] = {}
		add_keys(allowed[mode], GRAMMAR[mode] or {})
	end
	for id, lhs_list in pairs(shortcuts) do
		for _, mode in ipairs(action_modes(catalog:get(id))) do
			if allowed[mode] then
				add_keys(allowed[mode], lhs_list)
			end
		end
	end
	return allowed
end

---@param action gleb.Action
---@return string
local function description(action)
	return action.category .. ": " .. action.title
end

---@param catalog gleb.ActionCatalog
---@return table<string, gleb.Action[]>
local function actions_by_description(catalog)
	local descriptions = {}
	for _, action in ipairs(catalog.actions) do
		local desc = description(action)
		descriptions[desc] = descriptions[desc] or {}
		table.insert(descriptions[desc], action)
	end
	return descriptions
end

---@param action gleb.Action
---@param shortcuts gleb.ShortcutMap
---@param mode string
---@param lhs string
---@return boolean
local function owns_buffer_mapping(action, shortcuts, mode, lhs)
	if not vim.tbl_contains(action_modes(action), mode) then
		return false
	end
	for _, configured_lhs in ipairs(shortcuts[action.id] or {}) do
		if vim.keycode(configured_lhs) == vim.keycode(lhs) then
			return true
		end
	end
	return false
end

--- `<Plug>` and script-local targets are reached through other mappings, never pressed.
---@param lhs string
---@return boolean
local function is_pressable(lhs)
	return not vim.startswith(lhs, "<Plug>") and not lhs:find("<SNR>", 1, true)
end

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@return string[] "<mode> <lhs>" of each global mapping no action owns, sorted
function M.run(catalog, shortcuts)
	local allowed = allowed_keys(catalog, shortcuts)
	local descriptions = actions_by_description(catalog)
	local unowned = {}
	for _, mode in ipairs(MODES) do
		for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
			if is_pressable(mapping.lhs) and not allowed[mode][vim.keycode(mapping.lhs)] then
				table.insert(unowned, mode .. " " .. mapping.lhs)
			end
		end
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			for _, mode in ipairs(MODES) do
				for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
					local actions = descriptions[mapping.desc]
					if
						actions
						and not vim.iter(actions):any(function(action)
							return owns_buffer_mapping(action, shortcuts, mode, mapping.lhs)
						end)
					then
						table.insert(unowned, vim.bo[buf].filetype .. " " .. mode .. " " .. mapping.lhs)
					end
				end
			end
		end
	end
	table.sort(unowned)
	return unowned
end

return M
