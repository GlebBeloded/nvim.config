-- Loaded from the copilot spec's `config`, so only after InsertEnter or :Copilot.
local status_ok, copilot = pcall(require, "copilot")
if not status_ok then
	return
end

copilot.setup({
	suggestion = {
		auto_trigger = true,
		keymap = {
			accept = false,
			next = "<M-]>",
			prev = "<M-[>",
			dismiss = "<C-]>",
		},
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
