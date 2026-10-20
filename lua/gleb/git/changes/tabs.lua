-- Ordered changes-panel tabs keep extension and cycle policy independent from the panel UI.

local M = {}

---@class gleb.git.changes.TabView
---@field root string
---@field local_count integer
---@field branch_count integer
---@field branch_available boolean

---@class gleb.git.changes.Tab
---@field id string
---@field title string
---@field group string
---@field available fun(view: gleb.git.changes.TabView): boolean
---@field count fun(view: gleb.git.changes.TabView): integer
---@field editor? "file"

---@class gleb.git.changes.TabCycleState
---@field active string
---@field available string[]
---@field local_count integer

---@type gleb.git.changes.Tab[]
M.items = {
	{
		id = "local",
		title = "Local",
		group = "ChangesTabLocal",
		available = function(_)
			return true
		end,
		count = function(view)
			return view.local_count
		end,
	},
	{
		id = "branch",
		title = "Branch",
		group = "ChangesTabBranch",
		available = function(view)
			return view.branch_available
		end,
		count = function(view)
			return view.branch_count
		end,
	},
	{
		id = "comments",
		title = "Comments",
		group = "ChangesTabComments",
		editor = "file",
		available = function(view)
			local info = require("gleb.git.base").get(view.root)
			return info ~= nil and info.pr ~= nil
		end,
		count = function(view)
			local review = require("gleb.pr").get(view.root)
			return review and require("gleb.pr.threads").open_count(review.threads) or 0
		end,
	},
}

---@param values string[]
---@param wanted string
---@return boolean
local function contains(values, wanted)
	for _, value in ipairs(values) do
		if value == wanted then
			return true
		end
	end
	return false
end

---@param state gleb.git.changes.TabCycleState
---@return string
function M.first(state)
	if state.local_count == 0 and contains(state.available, "branch") then
		return "branch"
	end
	return "local"
end

---@param state gleb.git.changes.TabCycleState
---@return string
function M.next(state)
	for index, id in ipairs(state.available) do
		if id == state.active then
			return state.available[index + 1] or "close"
		end
	end
	return "close"
end

return M
