local opts = { noremap = true, silent = true }
local kmap = vim.keymap.set

-- Modes: n=normal, i=insert, v=visual, x=visual_block, t=term, c=command

-- Window navigation
kmap("n", "<C-h>", "<C-w>h", opts)
kmap("n", "<C-j>", "<C-w>j", opts)
kmap("n", "<C-k>", "<C-w>k", opts)
kmap("n", "<C-l>", "<C-w>l", opts)

-- Jump list navigation
kmap("n", "gb", "<C-O>", opts)
kmap("n", "gB", "<C-I>", opts)

-- Resize windows
kmap("n", "<C-Up>", ":resize +2<CR>", opts)
kmap("n", "<C-Down>", ":resize -2<CR>", opts)
kmap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
kmap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Buffer management
kmap("n", "<C-q>", ":bdelete<CR>", opts)

-- Insert mode
kmap("i", "jk", "<ESC>", opts)

-- Visual mode: stay in indent mode
kmap("v", "<", "<gv", opts)
kmap("v", ">", ">gv", opts)

-- Visual mode: move text and paste without yanking
kmap("v", "<A-j>", ":m .+1<CR>==", opts)
kmap("v", "<A-k>", ":m .-2<CR>==", opts)
kmap("v", "p", '"_dP', opts)

-- Visual block: move text
kmap("x", "J", ":move '>+1<CR>gv-gv", opts)
kmap("x", "K", ":move '<-2<CR>gv-gv", opts)
kmap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
kmap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

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
kmap("n", "<A-e>", function()
	smart_toggle_neotree("filesystem")
end, opts)
kmap("n", "<A-g>", function()
	smart_toggle_neotree("git_status")
end, opts)

-- Telescope
kmap("n", "<A-F>", ":Telescope live_grep<cr>", opts)

-- Code actions
kmap("n", "<C-CR>", vim.lsp.buf.code_action, opts)
kmap("x", "<C-CR>", vim.lsp.buf.code_action, opts)
kmap("v", "<C-CR>", vim.lsp.buf.code_action, opts)

-- LSP navigation
kmap("n", "gD", vim.lsp.buf.declaration, opts)
kmap("n", "gd", vim.lsp.buf.definition, opts)
kmap("n", "K", vim.lsp.buf.hover, opts)
kmap("n", "gi", vim.lsp.buf.implementation, opts)
kmap("n", "gr", require("telescope.builtin").lsp_references, opts)
kmap("n", "<A-r>", vim.lsp.buf.rename, opts)

-- Diagnostics
kmap("n", "<A-f>", vim.diagnostic.open_float, opts)
kmap("n", "<A-w>", vim.diagnostic.goto_next, opts)
kmap("n", "[d", function()
	vim.diagnostic.goto_prev({ border = "rounded" })
end, opts)
kmap("n", "gl", function()
	vim.diagnostic.open_float({ border = "rounded" })
end, opts)
kmap("n", "ge", function()
	vim.diagnostic.goto_next({ border = "rounded" })
end, opts)
kmap("n", "<leader>q", vim.diagnostic.setloclist, opts)

-- Disable recording
kmap("n", "q", "<Nop>", opts)

-- Leader keys
vim.g.mapleader = "<D->"
vim.g.maplocalleader = "\\"
