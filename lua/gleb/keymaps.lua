local opts = { noremap = true, silent = true }

-- pacakges used in keymaps
local copilot = require("copilot.suggestion")

-- Shorten function name
local keymap_old = vim.api.nvim_set_keymap
local kmap = vim.keymap.set

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Normal --
-- Better window navigation
keymap_old("n", "<C-h>", "<C-w>h", opts)
keymap_old("n", "<C-j>", "<C-w>j", opts)
keymap_old("n", "<C-k>", "<C-w>k", opts)
keymap_old("n", "<C-l>", "<C-w>l", opts)

keymap_old("n", "gb", "<C-O>", opts) -- prevous location
keymap_old("n", "gB", "<C-I>", opts) -- next location

-- Resize with arrows
keymap_old("n", "<C-Up>", ":resize +2<CR>", opts)
keymap_old("n", "<C-Down>", ":resize -2<CR>", opts)
keymap_old("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap_old("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
keymap_old("n", "<C-l>", ":bnext<CR>", opts)
keymap_old("n", "<C-h>", ":bprevious<CR>", opts)
keymap_old("n", "<C-q>", ":bdelete<CR>", opts)
-- TODO: make is a callble command: e.g CloseAllBuffers() or CloseAllBuffersExceptThisOne()
-- TODO: move to separate file ?
local function closeAllOtherBuffers()
	local currentBuffer = vim.api.nvim_get_current_buf()
	local buffers = vim.api.nvim_list_bufs()
	for _, buffer in ipairs(buffers) do
		if buffer ~= currentBuffer then
			require("bufferline").unpin_and_close(buffer)
		end
	end
end

-- TODO: conflicts with lowercase <C-q> (can't distinct) :(
-- keymap_lua("n", "<C-S-q>", closeAllOtherBuffers, opts)

-- TODO: make <A-q> close Diffview instead of closing just diff buffer
-- TODO: make <A-q> close file isntead of closing explorer
-- Move text up and down
-- keymap("n", "<A-j>", "<Esc>:m .+1<CR>==gi", opts)
-- keymap("n", "<A-k>", "<Esc>:m .-2<CR>==gi", opts)

-- Insert --
-- Press jk fast to exit insert mode
keymap_old("i", "jk", "<ESC>", opts)

-- Visual --
-- Stay in indent mode
keymap_old("v", "<", "<gv", opts)
keymap_old("v", ">", ">gv", opts)

-- Move text up and down
keymap_old("v", "<A-j>", ":m .+1<CR>==", opts)
keymap_old("v", "<A-k>", ":m .-2<CR>==", opts)
keymap_old("v", "p", '"_dP', opts)

-- Visual Block --
-- Move text up and down
keymap_old("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap_old("x", "K", ":move '<-2<CR>gv-gv", opts)
keymap_old("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap_old("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- Nvimtree
keymap_old("n", "<A-e>", ":NvimTreeToggle<cr>", opts)

-- telescope
keymap_old("n", "<A-F>", ":Telescope live_grep<cr>", opts)

-- code actions
--TODO: if two only code actions are import based,
-- just apply the organize imports one
-- even better, autoapply this code action if it is available
kmap("n", "<C-CR>", vim.lsp.buf.code_action, opts)
kmap("x", "<C-CR>", vim.lsp.buf.code_action, opts)
kmap("v", "<C-CR>", vim.lsp.buf.code_action, opts)
-- keymap("i", "<C-CR>", ":lua vim.lsp.buf.code_action()<cr>", opts)

kmap("n", "<A-w>", vim.diagnostic.goto_next, opts)
-- lsp keymaps
kmap("n", "gD", vim.lsp.buf.declaration, opts)
kmap("n", "gd", vim.lsp.buf.definition, opts)
kmap("n", "K", vim.lsp.buf.hover, opts)
kmap("n", "gi", vim.lsp.buf.implementation, opts)
kmap("n", "<A-r>", vim.lsp.buf.rename, opts)
kmap("n", "gr", vim.lsp.buf.references, opts)
kmap("n", "<A-f>", vim.diagnostic.open_float, opts)
keymap_old("n", "[d", ':lua vim.diagnostic.goto_prev({ border = "rounded" })<CR>', opts)
keymap_old("n", "gl", ':lua vim.diagnostic.open_float({ border = "rounded" })<CR>', opts)

keymap_old("n", "ge", '<cmd>lua vim.diagnostic.goto_next({ border = "rounded" })<CR>', opts)
kmap("i", "<S-CR>", copilot.accept, opts)
kmap("n", "<leader>q", vim.diagnostic.setloclist, opts)

-- std stuff
keymap_old("n", "q", "<Nop>", opts) -- disable recording feature

vim.g.mapleader = "<Space>"
keymap_old("n", "<Leader-e>", ":NvimTreeToggle<CR>", opts)

keymap_old("n", "<D-s>", ":NvimTreeToggle<CR>", opts)
keymap_old("n", "<M-s>", ":NvimTreeToggle<CR>", opts)

local refs = require("telescope.builtin").lsp_references

kmap("n", "gr", refs, opts)

local definitions = require("telescope.builtin").lsp_definitions
kmap("n", "gd", definitions, opts)

local opened = false

local function gitView()
	if not opened then
		require("diffview").open()
	else
		require("diffview").close()
	end

	opened = not opened
end

kmap("n", "<A-g>", gitView, opts)
