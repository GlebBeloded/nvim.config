-- Project-tree display state persists independently from expansion and transient view state.
local M = {}

---@class FileTreePersistedViewState
---@field show_ignored boolean

---@type FileTreePersistedViewState
M.state = { show_ignored = false }

---@return string
local function path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "file_tree", "view.json")
end

---@param value unknown
---@return boolean
local function valid(value)
	return type(value) == "table"
		and not vim.islist(value)
		and (value.show_ignored == nil or type(value.show_ignored) == "boolean")
end

---@return boolean
function M.load()
	local read_ok, lines = pcall(vim.fn.readfile, path())
	if not read_ok then
		M.state.show_ignored = false
		return false
	end
	local decode_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not decode_ok or not valid(decoded) then
		M.state.show_ignored = false
		return false
	end
	M.state.show_ignored = decoded.show_ignored == true
	return M.state.show_ignored
end

---@return boolean
function M.show_ignored()
	return M.state.show_ignored
end

---@param value boolean
---@return nil
function M.set_show_ignored(value)
	M.state.show_ignored = value
	local state_path = path()
	vim.fn.mkdir(vim.fs.dirname(state_path), "p")
	vim.fn.writefile({ vim.json.encode({ show_ignored = value }, { sort_keys = true }) }, state_path)
end

---@return nil
function M.reset()
	M.state = { show_ignored = false }
end

return M
