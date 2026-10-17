local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local TIMEOUT_MS = H.lsp_timeout(10000)

local root
local manifest

local function start()
	root, manifest = F.copy("gomod", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.lua([[require("null-ls").disable({ name = "golangci_lint" })]])
	child.o.lines, child.o.columns = 30, 100
end

local T = H.child_set(child, start)

---@param path string
---@param line integer
---@param col integer
local function edit(path, line, col)
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(path))
	child.api.nvim_win_set_cursor(0, { line, col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
end

local function open_format()
	local declaration = manifest.references.Format[1]
	edit(declaration.path, declaration.line, declaration.col)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
end

---@param label string
local function select_usage(label)
	local row = child.lua_get(
		[[
(function(label)
	for index, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		if line:find(label, 1, true) then
			return index
		end
	end
end)(...)
]],
		{ label }
	)
	child.api.nvim_win_set_cursor(0, { row, 0 })
end

local function preview_info()
	return child.lua_get([[
(function()
	local state = require("gleb.references.view").state
	local win = state.preview_win
	local buf = win and vim.api.nvim_win_get_buf(win) or nil
	return {
		buf = buf,
		cursor = win and vim.api.nvim_win_get_cursor(win) or nil,
		lines = buf and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or nil,
		path = state.preview_usage and state.preview_usage.path or nil,
		syntax = buf and vim.bo[buf].syntax or nil,
		treesitter = buf and vim.treesitter.highlighter.active[buf] ~= nil or false,
	}
end)()
]])
end

T["references: Preview follows the selection"] = function()
	open_format()
	select_usage("summary.go:7")
	eq(child.wait([[(require("gleb.references.view").state.preview_usage or {}).path == "report/summary.go"]]), true)

	local preview = preview_info()
	eq(preview.lines[7], [[	return "total: " + money.Format(total)]])
	eq(preview.cursor, { 7, 0 })
	eq(
		child.lua_get(
			[[
(function(buf)
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, { 6, 0 }, { 6, -1 }, { details = true })) do
		if mark[4].hl_group == "Search" then
			return { mark[2], mark[3], mark[4].end_col }
		end
	end
end)(...)
]],
			{ preview.buf }
		),
		{ 6, 26, 32 }
	)
	eq(child.lua_get([[vim.wo[require("gleb.references.view").state.preview_win].cursorlineopt]]), "number")
end

T["references: Preview highlighting matches a regular buffer"] = function()
	local invoice = manifest.references.Format[3]
	edit(invoice.path, invoice.line, invoice.col)
	eq(child.wait([[vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil]]), true)
	child.lua([[RegularInvoiceBuffer = vim.api.nvim_get_current_buf()]])
	open_format()
	eq(child.wait([[(require("gleb.references.view").state.preview_usage or {}).path == "billing/invoice.go"]]), true)

	local captures = child.lua_get([[(function()
local function captures(buf, first, last)
	local result = {}
	for row = first - 1, last - 1 do
		local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
		local columns = {}
		for col = 0, #line - 1 do
			local names = vim.tbl_map(function(item) return item.capture end,
				vim.treesitter.get_captures_at_pos(buf, row, col))
			table.sort(names)
			columns[col + 1] = table.concat(names, ",")
		end
		result[row + 1] = columns
	end
	return result
end
local preview = vim.api.nvim_win_get_buf(require("gleb.references.view").state.preview_win)
return { captures(RegularInvoiceBuffer, 11, 16), captures(preview, 11, 16) }
end)()]])
	eq(captures[2], captures[1])
end

T["references: Preview falls back to Vim syntax without a parser"] = function()
	H.write_files(root, { ["script.py"] = "value = 1\nprint(value)\n" })
	child.lua(
		[[
require("gleb.references.view").open("value", {
	{ uri = vim.uri_from_fname(...), path = "script.py", lnum = 1, col = 1, filetype = "python" },
})
]],
		{ vim.fs.joinpath(root, "script.py") }
	)

	local preview = preview_info()
	eq(preview.syntax, "python")
	eq(preview.treesitter, false)
end

T["references: Preview leaves no buffer or client behind"] = function()
	open_format()
	local before = child.lua_get([[(function()
local client = vim.lsp.get_clients({ name = "gopls" })[1]
return { #vim.api.nvim_list_bufs() - #require("gleb.references.view").state.buffers,
	#vim.lsp.get_buffers_by_client_id(client.id) }
end)()]])
	child.lua([[
local state = require("gleb.references.view").state
local tree_win = vim.api.nvim_get_current_win()
local tree_buf = vim.api.nvim_get_current_buf()
for row, node in ipairs(state.tree.nodes) do
	if node.kind == "usage" then
		vim.api.nvim_win_set_cursor(tree_win, { row, 0 })
		vim.api.nvim_exec_autocmds("CursorMoved", { buffer = tree_buf })
	end
end
]])
	child.type_keys("q")
	eq(child.wait([[next(require("gleb.references.view").state) == nil]]), true)

	local after = child.lua_get([[(function()
local client = vim.lsp.get_clients({ name = "gopls" })[1]
return { #vim.api.nvim_list_bufs(), #vim.lsp.get_buffers_by_client_id(client.id) }
end)()]])
	eq(after, before)
end

T["references: Preview shows unsaved edits"] = function()
	local invoice = manifest.references.Format[3]
	edit(invoice.path, invoice.line, invoice.col)
	child.api.nvim_buf_set_lines(0, 14, 15, false, { "\t// unsaved preview" })
	open_format()

	eq(preview_info().lines[15], "\t// unsaved preview")
end

T["references: P toggles the preview pane"] = function()
	open_format()
	local initial = child.lua_get([[(function()
local win = vim.api.nvim_get_current_win()
return { vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_config(win).col }
end)()]])
	child.type_keys("P")
	eq(child.wait([[require("gleb.references.view").state.preview_win == nil]]), true)
	local fitted = child.lua_get([[(function()
local win = vim.api.nvim_get_current_win()
return { vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_config(win).col }
end)()]])
	eq(fitted[1] < initial[1], true)
	eq(fitted[2], math.floor((100 - fitted[1] - 2) / 2))

	child.type_keys("P")
	eq(child.wait([[require("gleb.references.view").state.preview_win ~= nil]]), true)
	local restored = child.lua_get([[(function()
local win = vim.api.nvim_get_current_win()
return { vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_config(win).col }
end)()]])
	eq(restored, initial)
end

return T
