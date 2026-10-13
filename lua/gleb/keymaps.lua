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
map("n", "<C-Up>", ":resize +2<CR>", "Window: Increase height")
map("n", "<C-Down>", ":resize -2<CR>", "Window: Decrease height")
map("n", "<C-Left>", ":vertical resize -2<CR>", "Window: Decrease width")
map("n", "<C-Right>", ":vertical resize +2<CR>", "Window: Increase width")

-- Resize with Cmd+Shift+H/J/K/L (via smart-splits)
-- Cmd+Shift sends Alt+Shift sequences (ESC + uppercase letter)
map("n", "<A-H>", require("smart-splits").resize_left, "Window: Resize left") -- Cmd+Shift+H
map("n", "<A-J>", require("smart-splits").resize_down, "Window: Resize down") -- Cmd+Shift+J
map("n", "<A-K>", require("smart-splits").resize_up, "Window: Resize up") -- Cmd+Shift+K
map("n", "<A-L>", require("smart-splits").resize_right, "Window: Resize right") -- Cmd+Shift+L

-- Buffer management
map("n", "<C-q>", ":bdelete<CR>", "Buffer: Close")

-- Insert mode
map("i", "jk", "<ESC>", "Edit: Leave insert mode")

-- Visual mode: stay in indent mode
map("v", "<", "<gv", "Edit: Outdent selection")
map("v", ">", ">gv", "Edit: Indent selection")

-- Visual mode: move text and paste without yanking
map("v", "<A-j>", ":m .+1<CR>==", "Edit: Move selection down")
map("v", "<A-k>", ":m .-2<CR>==", "Edit: Move selection up")
map("v", "p", '"_dP', "Edit: Paste without yanking")

-- Visual block: move text
map("x", "J", ":move '>+1<CR>gv-gv", "Edit: Move selection down")
map("x", "K", ":move '<-2<CR>gv-gv", "Edit: Move selection up")
map("x", "<A-j>", ":move '>+1<CR>gv-gv", "Edit: Move selection down")
map("x", "<A-k>", ":move '<-2<CR>gv-gv", "Edit: Move selection up")

-- Smart neo-tree toggle: switch source, close if same & focused, focus if not
local function smart_toggle_neotree(source)
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_win_get_buf(current_win)
	local current_ft = vim.api.nvim_get_option_value("filetype", { buf = current_buf })

	if current_ft == "neo-tree" then
		local bufname = vim.api.nvim_buf_get_name(current_buf)
		local current_source = bufname:match("neo%-tree ([%w_]+)")

		if current_source == source then
			vim.cmd("Neotree close")
		else
			vim.cmd("Neotree " .. source)
		end
	else
		if source == "filesystem" then
			local current_file = vim.fn.expand("%:p")
			-- Skip reveal for special URIs (vscodediff://, etc.) as neo-tree can't parse them
			if current_file ~= "" and not current_file:match("^%w+://") then
				vim.cmd("Neotree reveal_file=" .. vim.fn.fnameescape(current_file) .. " filesystem")
			else
				vim.cmd("Neotree focus filesystem")
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
map("n", "<A-g>", ":Differ<cr>", "Git: Open Differ")
map("n", "<A-G>", function()
	smart_toggle_neotree("git_status")
end, "Tree: Toggle git status")

-- Telescope
map("n", "<A-F>", ":Telescope live_grep<cr>", "Search: Live grep")

-- Code actions
map("n", "<C-CR>", vim.lsp.buf.code_action, "LSP: Code action")
map("x", "<C-CR>", vim.lsp.buf.code_action, "LSP: Code action")
map("v", "<C-CR>", vim.lsp.buf.code_action, "LSP: Code action")

-- LSP navigation
map("n", "gD", vim.lsp.buf.declaration, "LSP: Go to declaration")
map("n", "gd", vim.lsp.buf.definition, "LSP: Go to definition")
map("n", "K", vim.lsp.buf.hover, "LSP: Hover")
map("n", "gi", vim.lsp.buf.implementation, "LSP: Go to implementation")
map("n", "gr", require("telescope.builtin").lsp_references, "LSP: References")
map("n", "<A-r>", vim.lsp.buf.rename, "LSP: Rename")

-- Diagnostics
map("n", "<A-w>", vim.diagnostic.goto_next, "Diagnostic: Next")
map("n", "[d", function()
	vim.diagnostic.goto_prev({ border = "rounded" })
end, "Diagnostic: Previous")
map("n", "ge", function()
	vim.diagnostic.goto_next({ border = "rounded" })
end, "Diagnostic: Next")

-- Leader keys
vim.g.mapleader = "<D->"
vim.g.maplocalleader = "\\"
