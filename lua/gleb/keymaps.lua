--- Set a silent, non-recursive mapping named `<Area>: <Action>`.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string
local function map(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

-- Modes: n=normal, i=insert, v=visual, x=visual_block, t=term, c=command

-- Window navigation (seamless with Zellij via smart-splits)
-- Cmd+H sends Ctrl+H, Cmd+L sends Ctrl+L
-- Cmd+J sends Alt+j, Cmd+K sends Alt+k (to avoid terminal conflicts)
map("n", "<C-h>", require("smart-splits").move_cursor_left, "Window: Move left")
map("n", "<A-j>", require("smart-splits").move_cursor_down, "Window: Move down")
map("n", "<A-k>", require("smart-splits").move_cursor_up, "Window: Move up")
map("n", "<C-l>", require("smart-splits").move_cursor_right, "Window: Move right")

-- Jump list navigation
map("n", "gb", "<C-O>", "Jump: Back")
map("n", "gB", "<C-I>", "Jump: Forward")

-- Resize windows
map("n", "<C-Up>", "<Cmd>resize +2<CR>", "Window: Increase height")
map("n", "<C-Down>", "<Cmd>resize -2<CR>", "Window: Decrease height")
map("n", "<C-Left>", "<Cmd>vertical resize -2<CR>", "Window: Decrease width")
map("n", "<C-Right>", "<Cmd>vertical resize +2<CR>", "Window: Increase width")

-- Resize with Cmd+Shift+H/J/K/L (via smart-splits)
-- Cmd+Shift sends Alt+Shift sequences (ESC + uppercase letter)
map("n", "<A-H>", require("smart-splits").resize_left, "Window: Resize left") -- Cmd+Shift+H
map("n", "<A-J>", require("smart-splits").resize_down, "Window: Resize down") -- Cmd+Shift+J
map("n", "<A-K>", require("smart-splits").resize_up, "Window: Resize up") -- Cmd+Shift+K
map("n", "<A-L>", require("smart-splits").resize_right, "Window: Resize right") -- Cmd+Shift+L

-- Buffer management
map("n", "<C-q>", "<Cmd>Bdelete<CR>", "Buffer: Close")

-- Insert mode
map("i", "jk", "<ESC>", "Edit: Leave insert mode")

-- Visual mode: stay in indent mode
map("x", "<", "<gv", "Edit: Outdent selection")
map("x", ">", ">gv", "Edit: Indent selection")

-- Visual mode: move text and paste without yanking
map("x", "p", '"_dP', "Edit: Paste without yanking")

-- Visual block: move text
map("x", "J", ":move '>+1<CR>gv-gv", "Edit: Move selection down")
map("x", "K", ":move '<-2<CR>gv-gv", "Edit: Move selection up")
map("x", "<A-j>", ":move '>+1<CR>gv-gv", "Edit: Move selection down")
map("x", "<A-k>", ":move '<-2<CR>gv-gv", "Edit: Move selection up")

-- Smart neo-tree toggle: switch source, close if same & focused, focus if not
---@param source string
---@param current_source string
local function apply_neotree_toggle(source, current_source)
	if current_source == source then
		vim.cmd("Neotree close")
	else
		vim.cmd("Neotree " .. source)
	end
end

---@param callback function
local function after_pending_filesystem_render(callback)
	local state = require("neo-tree.sources.manager").get_state("filesystem")
	local events = require("neo-tree.events")
	local render_generation = 0
	local finished = false
	local subscription
	local function finish()
		if finished then
			return
		end
		finished = true
		events.unsubscribe(subscription)
		callback()
	end

	local function finish_after_debounce()
		render_generation = render_generation + 1
		local expected_generation = render_generation
		vim.defer_fn(function()
			if expected_generation == render_generation and state._ready ~= false then
				finish()
			end
		end, 120)
	end

	subscription = {
		event = events.AFTER_RENDER,
		handler = function(rendered_state)
			if rendered_state ~= state then
				return
			end
			finish_after_debounce()
		end,
	}
	events.subscribe(subscription)
	finish_after_debounce()
	vim.defer_fn(finish, 5000)
end

local function smart_toggle_neotree(source)
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_win_get_buf(current_win)
	local current_ft = vim.api.nvim_get_option_value("filetype", { buf = current_buf })

	if current_ft == "neo-tree" then
		local bufname = vim.api.nvim_buf_get_name(current_buf)
		local current_source = bufname:match("neo%-tree ([%w_]+)")

		if current_source == "filesystem" then
			after_pending_filesystem_render(function()
				apply_neotree_toggle(source, current_source)
			end)
		else
			apply_neotree_toggle(source, current_source)
		end
	else
		if source == "filesystem" then
			local current_file = vim.fn.expand("%:p")
			-- Skip reveal for special URIs (vscodediff://, etc.) as neo-tree can't parse them
			if current_file ~= "" and not current_file:match("^%w+://") then
				vim.cmd("Neotree reveal_file=" .. vim.fn.fnameescape(current_file) .. " filesystem")
			else
				require("neo-tree.command").execute({ source = "filesystem", action = "focus", reveal = false })
			end
		else
			vim.cmd("Neotree focus " .. source)
		end
	end
end

-- Neo-tree (Cmd+E/G via Alt escape sequences from Alacritty)
map("n", "<A-e>", function()
	smart_toggle_neotree("filesystem")
end, "Tree: Toggle filesystem")
-- <A-g>: differ.nvim (new). <A-G>: old neo-tree git_status + vscode-diff preview.
map("n", "<A-g>", "<Cmd>Differ<CR>", "Git: Open Differ")
map("n", "<A-G>", function()
	smart_toggle_neotree("git_status")
end, "Tree: Toggle git status")

-- Telescope
map("n", "<A-F>", "<Cmd>Telescope live_grep<CR>", "Search: Live grep")

-- Code actions
map("n", "<C-CR>", vim.lsp.buf.code_action, "LSP: Code action")
map("x", "<C-CR>", vim.lsp.buf.code_action, "LSP: Code action")

-- LSP navigation
local function lsp_references()
	require("telescope.builtin").lsp_references({ include_current_line = true })
end

map("n", "gD", vim.lsp.buf.declaration, "LSP: Go to declaration")
map("n", "gd", vim.lsp.buf.definition, "LSP: Go to definition")
map("n", "K", vim.lsp.buf.hover, "LSP: Hover")
map("n", "gi", vim.lsp.buf.implementation, "LSP: Go to implementation")
map("n", "gr", lsp_references, "LSP: References")
for _, lhs in ipairs({ "grn", "gra", "grx", "grr", "gri", "grt" }) do
	vim.keymap.del("n", lhs)
end
map("n", "<A-r>", vim.lsp.buf.rename, "LSP: Rename")

-- Diagnostics
--- Open the diagnostic float at the cursor after a jump (`on_jump` of `vim.diagnostic.jump`).
---@param diagnostic vim.Diagnostic?
---@param bufnr integer
local function open_float_on_jump(diagnostic, bufnr)
	if not diagnostic then
		return
	end
	vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
end

--- Jump to the next diagnostic.
local function jump_next()
	vim.diagnostic.jump({ count = 1, on_jump = open_float_on_jump })
end

--- Jump to the previous diagnostic.
local function jump_prev()
	vim.diagnostic.jump({ count = -1, on_jump = open_float_on_jump })
end

map("n", "<A-w>", jump_next, "Diagnostics: Next")
map("n", "ge", jump_next, "Diagnostics: Next")
map("n", "[d", jump_prev, "Diagnostics: Previous")
