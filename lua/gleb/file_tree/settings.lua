-- File-tree settings state keeps test and user configuration paths separate.

local fs = require("gleb.workspace")
local ignore = require("gleb.file_tree.ignore")

local M = {}

---@class FileTreeSettingsOptions
---@field path? string

---@class FileTreeSettingsState
---@field path? string
---@field generation integer
---@field loaded_path? string
---@field settings? FileTreeSettings

---@class FileTreeSettings
---@field nesting FileTreeNestingSettings
---@field ignore string[]
---@field matcher FileTreeIgnoreMatcher

---@type FileTreeSettingsState
M.state = { generation = 0 }

---@return string
local function default_path()
	return vim.fs.joinpath(vim.fn.stdpath("config"), "settings", "file_tree.json")
end

---@return FileTreeSettings
local function disabled_settings()
	return {
		nesting = { enabled = false, rules = {}, generation = M.state.generation },
		ignore = {},
		matcher = ignore.matcher({}),
	}
end

---@param value unknown
---@return boolean
local function string_list(value)
	if type(value) ~= "table" or not vim.islist(value) then
		return false
	end
	for _, item in ipairs(value) do
		if type(item) ~= "string" then
			return false
		end
	end
	return true
end

---@param decoded unknown
---@return FileTreeSettings?
---@return string?
local function validate(decoded)
	if type(decoded) ~= "table" or vim.islist(decoded) then
		return nil, "root must be an object"
	end
	local nesting = decoded.nesting
	if type(nesting) ~= "table" or vim.islist(nesting) then
		return nil, "nesting must be an object"
	end
	if nesting.enabled ~= nil and type(nesting.enabled) ~= "boolean" then
		return nil, "nesting.enabled must be a boolean"
	end
	if nesting.rules ~= nil and (type(nesting.rules) ~= "table" or not vim.islist(nesting.rules)) then
		return nil, "nesting.rules must be an array"
	end
	if decoded.ignore ~= nil and not string_list(decoded.ignore) then
		return nil, "ignore must be an array of strings"
	end
	local globs = decoded.ignore or {}
	local matcher, errors = ignore.matcher(globs)
	for _, item in ipairs(errors) do
		vim.notify(("File tree ignore pattern %d skipped: %s"):format(item.index, item.reason), vim.log.levels.WARN)
	end
	return {
		nesting = {
			enabled = nesting.enabled ~= false,
			rules = nesting.rules or {},
			generation = M.state.generation,
		},
		ignore = globs,
		matcher = matcher,
	}
end

---@param reason string
---@return FileTreeSettings
local function invalid_settings(reason)
	vim.notify("File tree settings invalid: " .. reason, vim.log.levels.ERROR)
	return disabled_settings()
end

local function reload_written_settings(args)
	if fs.normalize(args.file) ~= M.state.path then
		return
	end
	M.reload()
	local ok, view = pcall(require, "gleb.file_tree.view")
	if ok then
		view.redraw_all()
	end
end

--- Select the settings file used by the file tree.
---@param opts FileTreeSettingsOptions
---@return nil
function M.setup(opts)
	M.state.path = fs.normalize(opts.path or default_path())
	M.state.generation = M.state.generation + 1
	M.state.loaded_path = nil
	M.state.settings = nil
	local group = vim.api.nvim_create_augroup("gleb_file_tree_settings", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", { group = group, callback = reload_written_settings })
end

--- Load and validate the file-tree settings.
---@param path? string
---@return FileTreeSettings
function M.load(path)
	local selected_path = fs.normalize(path or M.state.path or default_path())
	if M.state.settings and M.state.loaded_path == selected_path then
		return M.state.settings
	end

	local read_ok, lines = pcall(vim.fn.readfile, selected_path)
	local settings
	if not read_ok then
		settings = disabled_settings()
	else
		local decode_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
		if not decode_ok then
			settings = invalid_settings(tostring(decoded))
		else
			local validated, reason = validate(decoded)
			settings = validated or invalid_settings(reason or "unknown error")
		end
	end
	M.state.loaded_path = selected_path
	M.state.settings = settings
	return settings
end

--- Mark cached settings as stale.
---@return nil
function M.reload()
	M.state.generation = M.state.generation + 1
	M.state.loaded_path = nil
	M.state.settings = nil
end

--- Return the generation used by derived caches.
---@return integer
function M.generation()
	return M.state.generation
end

--- Clear settings state for a fresh load.
---@return nil
function M.reset()
	M.state = { generation = 0 }
end

return M
