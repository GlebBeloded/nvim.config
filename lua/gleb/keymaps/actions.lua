-- Core editor actions keep behavior separate from user-assigned shortcuts.

local Context = require("gleb.actions.context")

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

--- Shift the selection `count` times and reselect it.
---@param keys "<"|">"
---@return fun(ctx: gleb.ActionContext)
local function shift_selection(keys)
	return function(ctx)
		normal(Context.counted(ctx, keys .. "gv"))
	end
end

--- Jump list motion with the typed count; a count also keeps `:normal` from dropping a leading <Tab>.
---@param keys string
local function jump(keys)
	normal(vim.v.count1 .. keys)
end

local function leave_insert()
	vim.cmd.stopinsert()
end

--- Leave Visual mode so `'<`/`'>` mark the selection, move it, then reselect it.
---@param target string `:move` address
local function move_selection(target)
	normal("<Esc>")
	vim.cmd("'<,'>move " .. target)
	normal("gv-gv")
end

local function signature_help()
	vim.lsp.buf.signature_help()
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
		title = "Focus Left Window",
		category = "Window",
		run = require("smart-splits").move_cursor_left,
		mapping = require("smart-splits").move_cursor_left,
	},
	{
		id = "window.move_down",
		title = "Focus Down Window",
		category = "Window",
		run = require("smart-splits").move_cursor_down,
		mapping = require("smart-splits").move_cursor_down,
	},
	{
		id = "window.move_up",
		title = "Focus Up Window",
		category = "Window",
		run = require("smart-splits").move_cursor_up,
		mapping = require("smart-splits").move_cursor_up,
	},
	{
		id = "window.move_right",
		title = "Focus Right Window",
		category = "Window",
		run = require("smart-splits").move_cursor_right,
		mapping = require("smart-splits").move_cursor_right,
	},
	{
		id = "jump.back",
		title = "Navigate Back",
		category = "Jump",
		run = function()
			jump("<C-O>")
		end,
	},
	{
		id = "jump.forward",
		title = "Navigate Forward",
		category = "Jump",
		run = function()
			jump("<C-I>")
		end,
	},
	{
		id = "window.increase_height",
		title = "Increase Window Height",
		category = "Window",
		run = command("resize +2"),
	},
	{
		id = "window.decrease_height",
		title = "Decrease Window Height",
		category = "Window",
		run = command("resize -2"),
	},
	{
		id = "window.decrease_width",
		title = "Decrease Window Width",
		category = "Window",
		run = command("vertical resize -2"),
	},
	{
		id = "window.increase_width",
		title = "Increase Window Width",
		category = "Window",
		run = command("vertical resize +2"),
	},
	{
		id = "window.resize_left",
		title = "Resize Window Left",
		category = "Window",
		run = require("smart-splits").resize_left,
		mapping = require("smart-splits").resize_left,
	},
	{
		id = "window.resize_down",
		title = "Resize Window Down",
		category = "Window",
		run = require("smart-splits").resize_down,
		mapping = require("smart-splits").resize_down,
	},
	{
		id = "window.resize_up",
		title = "Resize Window Up",
		category = "Window",
		run = require("smart-splits").resize_up,
		mapping = require("smart-splits").resize_up,
	},
	{
		id = "window.resize_right",
		title = "Resize Window Right",
		category = "Window",
		run = require("smart-splits").resize_right,
		mapping = require("smart-splits").resize_right,
	},
	{ id = "buffer.close", title = "Close Buffer", category = "Buffer", run = command("Bdelete") },
	{
		id = "edit.leave_insert",
		title = "Leave Insert Mode",
		category = "Edit",
		modes = { "i" },
		run = leave_insert,
	},
	{
		id = "edit.outdent_selection",
		title = "Outdent Selection",
		category = "Edit",
		modes = { "x" },
		run = shift_selection("<"),
	},
	{
		id = "edit.indent_selection",
		title = "Indent Selection",
		category = "Edit",
		modes = { "x" },
		run = shift_selection(">"),
	},
	{
		id = "edit.paste_without_yanking",
		title = "Paste Without Yanking",
		category = "Edit",
		modes = { "x" },
		run = function()
			normal('"_dP')
		end,
	},
	{
		id = "edit.move_selection_down",
		title = "Move Selection Down",
		category = "Edit",
		modes = { "x" },
		run = function()
			move_selection("'>+1")
		end,
	},
	{
		id = "edit.move_selection_up",
		title = "Move Selection Up",
		category = "Edit",
		modes = { "x" },
		run = function()
			move_selection("'<-2")
		end,
	},
	{
		id = "search.live_grep",
		title = "Find in Files...",
		category = "Edit | Find",
		run = require("gleb.picker").grep_live,
		mapping = require("gleb.picker").grep_live,
	},
	{
		id = "lsp.code_action",
		title = "Show Code Actions...",
		category = "LSP",
		modes = { "n", "x" },
		run = vim.lsp.buf.code_action,
		mapping = vim.lsp.buf.code_action,
	},
	{
		id = "lsp.go_to_declaration",
		title = "Go to Declaration",
		category = "LSP",
		run = vim.lsp.buf.declaration,
		mapping = vim.lsp.buf.declaration,
	},
	{
		id = "lsp.go_to_definition",
		title = "Go to Definition",
		category = "LSP",
		run = vim.lsp.buf.definition,
		mapping = vim.lsp.buf.definition,
	},
	{
		id = "lsp.hover",
		title = "Show Hover Info",
		category = "LSP",
		run = vim.lsp.buf.hover,
		mapping = vim.lsp.buf.hover,
	},
	{
		id = "lsp.go_to_implementation",
		title = "Go to Implementation",
		category = "LSP",
		run = vim.lsp.buf.implementation,
		mapping = vim.lsp.buf.implementation,
	},
	{
		id = "lsp.references",
		title = "Find References",
		category = "LSP",
		run = require("gleb.picker").lsp_references,
		mapping = require("gleb.picker").lsp_references,
	},
	{
		id = "lsp.rename",
		title = "Rename Symbol...",
		category = "LSP",
		run = vim.lsp.buf.rename,
		mapping = vim.lsp.buf.rename,
	},
	{
		id = "lsp.signature_help",
		title = "Signature Help",
		category = "LSP",
		modes = { "i", "s" },
		run = signature_help,
		mapping = signature_help,
	},
	{ id = "diag.next", title = "Next Diagnostic", category = "Diagnostics", run = jump_next },
	{ id = "diag.previous", title = "Previous Diagnostic", category = "Diagnostics", run = jump_previous },
}

return actions
