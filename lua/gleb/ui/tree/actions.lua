-- Tree action definitions keep fold behavior and metadata identical across feature-owned tree buffers.

local M = {}

---@class gleb.ui.tree.ActionOptions
---@field area string
---@field category string
---@field ft string
---@field toggle_id? string
---@field close_title? string

---@param verb "close"|"open"|"toggle"|"close_all"|"open_all"
---@return fun(): boolean
local function run(verb)
	return function()
		return require("gleb.ui.tree")[verb]()
	end
end

---@param options gleb.ui.tree.ActionOptions
---@return gleb.Action[]
function M.fold_actions(options)
	local prefix = options.area .. "."
	return {
		{
			id = prefix .. "close_node",
			title = options.close_title or "Collapse Node",
			category = options.category,
			ft = options.ft,
			run = run("close"),
		},
		{
			id = prefix .. "expand_node",
			title = "Expand Node",
			category = options.category,
			ft = options.ft,
			run = run("open"),
		},
		{
			id = options.toggle_id or prefix .. "toggle_fold",
			title = "Toggle Fold",
			category = options.category,
			ft = options.ft,
			run = run("toggle"),
		},
		{
			id = prefix .. "fold_all",
			title = "Fold All",
			category = options.category,
			ft = options.ft,
			run = run("close_all"),
		},
		{
			id = prefix .. "unfold_all",
			title = "Unfold All",
			category = options.category,
			ft = options.ft,
			run = run("open_all"),
		},
	}
end

return M
