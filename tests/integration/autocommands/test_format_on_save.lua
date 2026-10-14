local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.cmd("edit " .. vim.fn.fnameescape(vim.fn.tempname() .. ".txt"))
end

local T = H.child_set(child, start)

T["autocommands: Saving without a formatting server is silent"] = function()
	child.lua([[
FormatCalls = 0
local format = vim.lsp.buf.format
vim.lsp.buf.format = function(opts)
	FormatCalls = FormatCalls + 1
	return format(opts)
end
]])
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
	child.cmd("messages clear")

	child.cmd("write")

	eq(child.lua_get("FormatCalls"), 0)
	eq(child.cmd_capture("messages"):find("no matching language servers", 1, true), nil)
end

T["autocommands: Saving with a formatting server formats the buffer"] = function()
	local bufnr = child.api.nvim_get_current_buf()
	child.lua(
		[[
local bufnr = ...
FormatProbe = {}
vim.lsp.get_clients = function(opts)
	if opts.method == "textDocument/formatting" then
		FormatProbe.checked_bufnr = opts.bufnr
		FormatProbe.checked_method = opts.method
		if opts.bufnr == bufnr then
			return { {} }
		end
	end
	return {}
end
vim.lsp.buf.format = function(opts)
	FormatProbe.formatted_bufnr = opts.bufnr
	vim.api.nvim_buf_set_lines(opts.bufnr, 0, -1, false, { "formatted" })
end
]],
		{ bufnr }
	)
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "unformatted" })

	child.cmd("write")

	eq(child.lua_get("FormatProbe"), {
		checked_bufnr = bufnr,
		checked_method = "textDocument/formatting",
		formatted_bufnr = bufnr,
	})
	eq(child.api.nvim_buf_get_lines(bufnr, 0, -1, false), { "formatted" })
end

return T
