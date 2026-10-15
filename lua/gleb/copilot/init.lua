-- Loaded from the copilot spec's `config`, so only after InsertEnter or :Copilot.
local status_ok, copilot = pcall(require, "copilot")
if not status_ok then
	return
end

local actions = require("gleb.actions")
local adapter = require("gleb.actions.adapters.copilot")
local store = assert(actions.state.store, "actions are not set up")
local catalog = assert(actions.state.applicator, "actions are not set up").catalog
local keymap = {}
for name in pairs(require("copilot.config.suggestion").default.keymap) do
	keymap[name] = false
end
keymap = vim.tbl_extend("force", keymap, adapter.mappings(catalog, store:load()).suggestion.keymap)

copilot.setup({
	suggestion = {
		auto_trigger = true,
		keymap = keymap,
	},
})

-- the blink menu and the inline suggestion never show at the same time
local function hide_suggestion()
	require("copilot.suggestion").dismiss()
	vim.b.copilot_suggestion_hidden = true
end

local function allow_suggestion()
	vim.b.copilot_suggestion_hidden = false
end

local group = vim.api.nvim_create_augroup("gleb_copilot_blink", { clear = true })
vim.api.nvim_create_autocmd("User", { group = group, pattern = "BlinkCmpMenuOpen", callback = hide_suggestion })
vim.api.nvim_create_autocmd("User", { group = group, pattern = "BlinkCmpMenuClose", callback = allow_suggestion })
