-- Find Action item selection keeps fuzzy search and MRU ordering independent from picker rendering.

local MAX_RECENT = 20

---@class gleb.FindActionSections
---@field recent gleb.Action[]
---@field curated gleb.Action[]

---@class gleb.FindActionHistory
---@field path string
local History = {}
History.__index = History

local M = {}

---@param text string
---@param query string
---@return boolean
local function fuzzy_matches(text, query)
	text = text:lower()
	query = query:lower()
	local position = 1
	for index = 1, #query do
		local found = text:find(query:sub(index, index), position, true)
		if not found then
			return false
		end
		position = found + 1
	end
	return true
end

---@param action gleb.Action
---@param query string
---@return boolean
local function action_matches(action, query)
	if fuzzy_matches(action.title, query) or fuzzy_matches(action.category, query) then
		return true
	end
	if query:find("%s") and fuzzy_matches(action.category .. " " .. action.title, query) then
		return true
	end
	for _, alias in ipairs(action.aliases or {}) do
		if fuzzy_matches(alias, query) then
			return true
		end
	end
	return false
end

---@param actions gleb.Action[]
---@param query string
---@return gleb.Action[]
function M.match(actions, query)
	local matches = {}
	for _, action in ipairs(actions) do
		if action_matches(action, query) then
			table.insert(matches, action)
		end
	end
	return matches
end

---@param actions gleb.Action[]
---@param recent_ids string[]
---@return gleb.FindActionSections
function M.order(actions, recent_ids)
	---@type table<string, gleb.Action>
	local by_id = {}
	for _, action in ipairs(actions) do
		by_id[action.id] = action
	end

	local sections = { recent = {}, curated = {} }
	---@type table<string, boolean>
	local used = {}
	for _, id in ipairs(recent_ids) do
		if by_id[id] and not used[id] then
			table.insert(sections.recent, by_id[id])
			used[id] = true
		end
	end
	for _, action in ipairs(actions) do
		if not used[action.id] then
			table.insert(sections.curated, action)
		end
	end
	return sections
end

---@return string[]
function History:load()
	local read_ok, lines = pcall(vim.fn.readfile, self.path)
	if not read_ok then
		return {}
	end
	local decode_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not decode_ok or type(decoded) ~= "table" or not vim.islist(decoded) then
		return {}
	end
	local ids = {}
	for _, id in ipairs(decoded) do
		if type(id) == "string" and #ids < MAX_RECENT then
			table.insert(ids, id)
		end
	end
	return ids
end

---@param id string
---@return nil
function History:record(id)
	local ids = { id }
	for _, existing in ipairs(self:load()) do
		if existing ~= id and #ids < MAX_RECENT then
			table.insert(ids, existing)
		end
	end
	vim.fn.mkdir(vim.fs.dirname(self.path), "p")
	vim.fn.writefile({ vim.json.encode(ids) }, self.path)
end

---@return gleb.FindActionHistory
function M.history()
	return setmetatable({
		path = vim.fs.joinpath(vim.fn.stdpath("state"), "find_action_recent.json"),
	}, History)
end

return M
