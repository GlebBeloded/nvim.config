-- Features own action lists; this module is their catalog entry point.

local Registry = require("gleb.actions.registry")
local Apply = require("gleb.actions.apply")
local Store = require("gleb.actions.store")

---@class gleb.ActionsState
---@field store? gleb.ShortcutStore
---@field applicator? gleb.ActionApplicator

local M = {
	---@type gleb.ActionsState
	state = {},
}

---@param feature_actions gleb.Action[][]
---@return gleb.ActionCatalog
function M.catalog(feature_actions)
	return Registry.new(feature_actions)
end

---@return boolean
function M.apply()
	local store = assert(M.state.store, "actions are not set up")
	local shortcuts, loaded = store:load()
	if not loaded then
		return false
	end
	assert(M.state.applicator, "actions are not set up"):apply(shortcuts)
	return true
end

---@param feature_actions gleb.Action[][]
---@param path? string
function M.setup(feature_actions, path)
	if M.state.applicator then
		M.state.applicator:clear()
	end

	local catalog = M.catalog(feature_actions)
	M.state.store = Store.new(path or vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json"), catalog)
	M.state.applicator = Apply.new(catalog)

	local group = vim.api.nvim_create_augroup("gleb_actions", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "VeryLazy",
		callback = M.apply,
	})
	if vim.g.did_very_lazy then
		M.apply()
	end
end

function M.reset()
	if M.state.applicator then
		M.state.applicator:clear()
	end
	M.state = {}
	vim.api.nvim_del_augroup_by_name("gleb_actions")
end

return M
