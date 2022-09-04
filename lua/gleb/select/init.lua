-- TODO-list
-- first simple drop-down under cursor
-- then add diff rendering
-- then add resizing

-- do one for references
-- do generic one
-- do one for the input

local defaultSelect = vim.ui.select
local codeAction = require("gleb.select.code_action")

vim.ui.select = function(items, opts, on_choice)
	if opts.kind == "codeaction" then
		codeAction:new(items, opts, on_choice):select()
	else
		-- defaultSelect(items, opts, on_choice)
	end
end
