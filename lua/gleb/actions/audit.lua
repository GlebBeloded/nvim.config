-- Ownership audit: every pressable mapping is assigned to a registered action, is Neovim grammar, or is a
-- plugin-native window key that the plugin offers no way to reassign.

local Registry = require("gleb.actions.registry")

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

-- Hardcoded plugin-window keys by filetype: Mason navigation and 99's `q` and `<CR>`.
local NATIVE = {
	mason = { n = { "<Esc>", "1", "2", "3", "4", "5", "q" } },
	["99"] = { n = { "q", "<CR>" } },
	["99prompt"] = { n = { "q", "<CR>" } },
}

-- nvim-autopairs marks its insert-mode pair mappings with these descriptions.
local AUTOPAIRS = { ["autopairs map key"] = true, ["autopairs delete"] = true, ["autopairs fastwrap"] = true }

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
---@param include fun(action: gleb.Action): boolean
---@return table<string, table<string, true>> keys assigned per mode to the included actions
local function assigned_keys(catalog, shortcuts, include)
	local keys = {}
	for _, mode in ipairs(MODES) do
		keys[mode] = {}
	end
	for id, lhs_list in pairs(shortcuts) do
		local action = catalog:get(id)
		for _, mode in ipairs(action and include(action) and action_modes(action) or {}) do
			if keys[mode] then
				add_keys(keys[mode], lhs_list)
			end
		end
	end
	return keys
end

---@return boolean
local function any_action()
	return true
end

---@param action gleb.Action
---@return boolean
local function is_plugin_action(action)
	return action.plugin ~= nil
end

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@return table<string, table<string, true>> keys allowed per mode
local function allowed_keys(catalog, shortcuts)
	local allowed = assigned_keys(catalog, shortcuts, any_action)
	for _, mode in ipairs(MODES) do
		add_keys(allowed[mode], GRAMMAR[mode] or {})
	end
	return allowed
end

---@param catalog gleb.ActionCatalog
---@return table<string, gleb.Action[]>
local function actions_by_description(catalog)
	local descriptions = {}
	for _, action in ipairs(catalog.actions) do
		local desc = Registry.description(action)
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

--- lazy.nvim's hardcoded view keys; its close key belongs to the `lazy.close` action.
---@return table<string, string[]>
local function lazy_view_keys()
	local view = require("lazy.view.config")
	local keys = { n = { "gx" }, x = {} }
	for name, lhs in pairs(view.keys) do
		if name ~= "close" then
			table.insert(keys.n, lhs)
		end
	end
	for _, command in pairs(view.commands) do
		vim.list_extend(keys.n, { command.key })
		vim.list_extend(keys.n, { command.key_plugin })
		vim.list_extend(keys.x, { command.key_plugin })
	end
	return keys
end

---@param filetype string
---@param mode string
---@return table<string, true>
local function native_keys(filetype, mode)
	local by_mode = filetype == "lazy" and lazy_view_keys() or NATIVE[filetype] or {}
	local keys = {}
	add_keys(keys, by_mode[mode] or {})
	return keys
end

--- Neovim's runtime files (ftplugins such as Go's section motions) define buffer-local grammar.
---@param sid? integer
---@return boolean
local function from_runtime(sid)
	if not sid or sid <= 0 then
		return false
	end
	local script = vim.fn.getscriptinfo({ sid = sid })[1]
	return script ~= nil and vim.startswith(vim.fs.normalize(script.name), vim.fs.normalize(vim.env.VIMRUNTIME) .. "/")
end

---@class gleb.AuditIndex
---@field shortcuts gleb.ShortcutMap
---@field descriptions table<string, gleb.Action[]>
---@field plugin_keys table<string, table<string, true>>

---@param index gleb.AuditIndex
---@param buf integer
---@param mode string
---@param mapping vim.api.keyset.get_keymap
---@return boolean
local function is_owned_buffer_mapping(index, buf, mode, mapping)
	local actions = index.descriptions[mapping.desc]
	if actions then
		return vim.iter(actions):any(function(action)
			return owns_buffer_mapping(action, index.shortcuts, mode, mapping.lhs)
		end)
	end
	local key = vim.keycode(mapping.lhs)
	return index.plugin_keys[mode][key] == true
		or (mode == "i" and AUTOPAIRS[mapping.desc] == true)
		or from_runtime(mapping.sid)
		or native_keys(vim.bo[buf].filetype, mode)[key] == true
end

---@param catalog gleb.ActionCatalog
---@param shortcuts gleb.ShortcutMap
---@return string[] "<mode> <lhs>" of each global and "<filetype> <mode> <lhs>" of each buffer mapping no action owns, sorted
function M.run(catalog, shortcuts)
	local allowed = allowed_keys(catalog, shortcuts)
	---@type gleb.AuditIndex
	local index = {
		shortcuts = shortcuts,
		descriptions = actions_by_description(catalog),
		plugin_keys = assigned_keys(catalog, shortcuts, is_plugin_action),
	}
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
					if is_pressable(mapping.lhs) and not is_owned_buffer_mapping(index, buf, mode, mapping) then
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
