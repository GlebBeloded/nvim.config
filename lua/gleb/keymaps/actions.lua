-- Core editor actions keep behavior separate from user-assigned shortcuts.

---@param keys string
local function normal(keys)
	vim.cmd.normal({ args = { vim.keycode(keys) }, bang = true })
end

---@param ex_command string
---@return fun()
local function command(ex_command)
	return function()
		vim.cmd(ex_command)
	end
end

---@param diagnostic vim.Diagnostic?
---@param bufnr integer
local function open_float_on_jump(diagnostic, bufnr)
	if diagnostic then
		vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
	end
end

local function jump_next()
	vim.diagnostic.jump({ count = 1, on_jump = open_float_on_jump })
end

local function jump_previous()
	vim.diagnostic.jump({ count = -1, on_jump = open_float_on_jump })
end

---@type gleb.Action[]
local actions = {
	{
		id = "window.move_left",
		title = "Move left",
		category = "Window",
		run = require("smart-splits").move_cursor_left,
		mapping = require("smart-splits").move_cursor_left,
	},
	{
		id = "window.move_down",
		title = "Move down",
		category = "Window",
		run = require("smart-splits").move_cursor_down,
		mapping = require("smart-splits").move_cursor_down,
	},
	{
		id = "window.move_up",
		title = "Move up",
		category = "Window",
		run = require("smart-splits").move_cursor_up,
		mapping = require("smart-splits").move_cursor_up,
	},
	{
		id = "window.move_right",
		title = "Move right",
		category = "Window",
		run = require("smart-splits").move_cursor_right,
		mapping = require("smart-splits").move_cursor_right,
	},
	{
		id = "jump.back",
		title = "Back",
		category = "Jump",
		run = function()
			normal("<C-O>")
		end,
	},
	{
		id = "jump.forward",
		title = "Forward",
		category = "Jump",
		run = function()
			normal("<C-I>")
		end,
	},
	{ id = "window.increase_height", title = "Increase height", category = "Window", run = command("resize +2") },
	{ id = "window.decrease_height", title = "Decrease height", category = "Window", run = command("resize -2") },
	{
		id = "window.decrease_width",
		title = "Decrease width",
		category = "Window",
		run = command("vertical resize -2"),
	},
	{
		id = "window.increase_width",
		title = "Increase width",
		category = "Window",
		run = command("vertical resize +2"),
	},
	{
		id = "window.resize_left",
		title = "Resize left",
		category = "Window",
		run = require("smart-splits").resize_left,
		mapping = require("smart-splits").resize_left,
	},
	{
		id = "window.resize_down",
		title = "Resize down",
		category = "Window",
		run = require("smart-splits").resize_down,
		mapping = require("smart-splits").resize_down,
	},
	{
		id = "window.resize_up",
		title = "Resize up",
		category = "Window",
		run = require("smart-splits").resize_up,
		mapping = require("smart-splits").resize_up,
	},
	{
		id = "window.resize_right",
		title = "Resize right",
		category = "Window",
		run = require("smart-splits").resize_right,
		mapping = require("smart-splits").resize_right,
	},
	{ id = "buffer.close", title = "Close", category = "Buffer", run = command("Bdelete") },
	{
		id = "edit.leave_insert",
		title = "Leave insert mode",
		category = "Edit",
		modes = { "i" },
		run = vim.cmd.stopinsert,
	},
	{
		id = "edit.outdent_selection",
		title = "Outdent selection",
		category = "Edit",
		modes = { "x" },
		run = function()
			normal("<gv")
		end,
	},
	{
		id = "edit.indent_selection",
		title = "Indent selection",
		category = "Edit",
		modes = { "x" },
		run = function()
			normal(">gv")
		end,
	},
	{
		id = "edit.paste_without_yanking",
		title = "Paste without yanking",
		category = "Edit",
		modes = { "x" },
		run = function()
			normal('"_dP')
		end,
	},
	{
		id = "edit.move_selection_down",
		title = "Move selection down",
		category = "Edit",
		modes = { "x" },
		run = function()
			vim.cmd("move '>+1")
			normal("gv-gv")
		end,
	},
	{
		id = "edit.move_selection_up",
		title = "Move selection up",
		category = "Edit",
		modes = { "x" },
		run = function()
			vim.cmd("move '<-2")
			normal("gv-gv")
		end,
	},
	{
		id = "search.live_grep",
		title = "Live grep",
		category = "Search",
		run = require("gleb.picker").grep_live,
		mapping = require("gleb.picker").grep_live,
	},
	{
		id = "lsp.code_action",
		title = "Code action",
		category = "LSP",
		modes = { "n", "x" },
		run = vim.lsp.buf.code_action,
		mapping = vim.lsp.buf.code_action,
	},
	{
		id = "lsp.go_to_declaration",
		title = "Go to declaration",
		category = "LSP",
		run = vim.lsp.buf.declaration,
		mapping = vim.lsp.buf.declaration,
	},
	{
		id = "lsp.go_to_definition",
		title = "Go to definition",
		category = "LSP",
		run = vim.lsp.buf.definition,
		mapping = vim.lsp.buf.definition,
	},
	{ id = "lsp.hover", title = "Hover", category = "LSP", run = vim.lsp.buf.hover, mapping = vim.lsp.buf.hover },
	{
		id = "lsp.go_to_implementation",
		title = "Go to implementation",
		category = "LSP",
		run = vim.lsp.buf.implementation,
		mapping = vim.lsp.buf.implementation,
	},
	{
		id = "lsp.references",
		title = "References",
		category = "LSP",
		run = require("gleb.picker").lsp_references,
		mapping = require("gleb.picker").lsp_references,
	},
	{ id = "lsp.rename", title = "Rename", category = "LSP", run = vim.lsp.buf.rename, mapping = vim.lsp.buf.rename },
	{ id = "diag.next", title = "Next", category = "Diagnostics", run = jump_next },
	{ id = "diag.previous", title = "Previous", category = "Diagnostics", run = jump_previous },
}

return actions
