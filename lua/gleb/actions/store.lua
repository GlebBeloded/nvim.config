-- Persistent shortcuts are validated at the file boundary so a broken edit cannot replace working bindings.

---@alias gleb.ShortcutMap table<string, string[]>

---@class gleb.ShortcutStore
---@field path string
---@field catalog gleb.ActionCatalog
---@field last_good gleb.ShortcutMap
---@field warned_unknown table<string, boolean>
local Store = {}
Store.__index = Store

local M = {}

---@param message string
local function notify_error(message)
	vim.notify(message, vim.log.levels.ERROR)
end

---@param shortcuts unknown
---@return boolean
local function has_valid_shape(shortcuts)
	if type(shortcuts) ~= "table" then
		return false
	end
	if next(shortcuts) ~= nil and vim.islist(shortcuts) then
		return false
	end
	for id, lhs_list in pairs(shortcuts) do
		if type(id) ~= "string" or type(lhs_list) ~= "table" or not vim.islist(lhs_list) then
			return false
		end
		for _, lhs in ipairs(lhs_list) do
			if type(lhs) ~= "string" or lhs == "" then
				return false
			end
		end
	end
	return true
end

---@param self gleb.ShortcutStore
---@param shortcuts gleb.ShortcutMap
---@param warn_unknown boolean
---@return gleb.ShortcutMap?
local function validate_actions(self, shortcuts, warn_unknown)
	local valid = {}
	for id, lhs_list in pairs(shortcuts) do
		local action = self.catalog:get(id)
		if not action then
			if warn_unknown then
				if not self.warned_unknown[id] then
					vim.notify("Unknown action id: " .. id, vim.log.levels.WARN)
					self.warned_unknown[id] = true
				end
			else
				notify_error("Unknown action id: " .. id)
				return nil
			end
		elseif action.hidden then
			notify_error("Hidden action cannot receive shortcuts: " .. id)
			return nil
		else
			valid[id] = lhs_list
		end
	end
	return valid
end

---@return gleb.ShortcutMap
function Store:load()
	local read_ok, lines = pcall(vim.fn.readfile, self.path)
	if not read_ok then
		notify_error("Could not read shortcut file: " .. tostring(lines))
		return vim.deepcopy(self.last_good)
	end

	local decode_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not decode_ok or not has_valid_shape(decoded) then
		notify_error("Invalid shortcut JSON: " .. tostring(decoded))
		return vim.deepcopy(self.last_good)
	end

	local shortcuts = validate_actions(self, decoded, true)
	if not shortcuts then
		return vim.deepcopy(self.last_good)
	end
	self.last_good = vim.deepcopy(shortcuts)
	return shortcuts
end

---@param shortcuts gleb.ShortcutMap
---@return boolean
function Store:save(shortcuts)
	if not has_valid_shape(shortcuts) then
		notify_error("Invalid shortcut map")
		return false
	end
	local valid = validate_actions(self, shortcuts, false)
	if not valid then
		return false
	end

	local value = next(valid) == nil and vim.empty_dict() or valid
	local encoded = vim.json.encode(value, { indent = "  ", sort_keys = true })
	local write_result = vim.fn.writefile(vim.split(encoded, "\n", { plain = true }), self.path)
	if write_result ~= 0 then
		notify_error("Could not write shortcut file: " .. self.path)
		return false
	end
	self.last_good = vim.deepcopy(valid)
	return true
end

---@param path string
---@param catalog gleb.ActionCatalog
---@return gleb.ShortcutStore
function M.new(path, catalog)
	return setmetatable({
		path = path,
		catalog = catalog,
		last_good = {},
		warned_unknown = {},
	}, Store)
end

return M
