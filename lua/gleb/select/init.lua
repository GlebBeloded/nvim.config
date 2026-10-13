-- TODO-list
-- first simple drop-down under cursor
-- then add diff rendering
-- then add resizing

-- do one for references
-- do generic one
-- do one for the input

local default_select = vim.ui.select
local code_action = require("gleb.select.code_action")

-- Intended override: route code actions to the custom picker.
---@diagnostic disable-next-line: duplicate-set-field
vim.ui.select = function(items, opts, on_choice)
	if opts.kind == "codeaction" then
		code_action:new(items, opts, on_choice):select()
	else
		default_select(items, opts, on_choice)
	end
end
