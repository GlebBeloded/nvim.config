local opts = { noremap = true, silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap
local keymap_lua = vim.keymap.set

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Normal --
-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

keymap("n", "gb", "<C-O>", opts) -- prevous location
keymap("n", "gB", "<C-I>", opts) -- next location

-- Resize with arrows
keymap("n", "<C-Up>", ":resize +2<CR>", opts)
keymap("n", "<C-Down>", ":resize -2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
keymap("n", "<C-l>", ":bnext<CR>", opts)
keymap("n", "<C-h>", ":bprevious<CR>", opts)
keymap("n", "<C-q>", ":bdelete<CR>", opts)
-- TODO: make is a callble command: e.g CloseAllBuffers() or CloseAllBuffersExceptThisOne()
-- keymap("n", "<C-W>", ":bufdo bwipeout<CR>", opts)

-- Move text up and down
-- keymap("n", "<A-j>", "<Esc>:m .+1<CR>==gi", opts)
-- keymap("n", "<A-k>", "<Esc>:m .-2<CR>==gi", opts)

-- Insert --
-- Press jk fast to exit insert mode
keymap("i", "jk", "<ESC>", opts)

-- Visual --
-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move text up and down
keymap("v", "<A-j>", ":m .+1<CR>==", opts)
keymap("v", "<A-k>", ":m .-2<CR>==", opts)
keymap("v", "p", '"_dP', opts)

-- Visual Block --
-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- Nvimtree
keymap("n", "<A-e>", ":NvimTreeToggle<cr>", opts)

-- telescope
keymap("n", "<A-F>", ":Telescope live_grep<cr>", opts)

-- code actions
keymap("n", "<C-CR>", ":lua vim.lsp.buf.code_action()<cr>", opts)
keymap("x", "<C-CR>", ":lua vim.lsp.buf.code_action()<cr>", opts)
keymap("v", "<C-CR>", ":lua vim.lsp.buf.code_action()<cr>", opts)
keymap("i", "<C-CR>", ":lua vim.lsp.buf.code_action()<cr>", opts)

keymap("n", "<A-w>", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
-- lsp keymaps
keymap("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
keymap("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
keymap("n", "<A-r>", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
keymap("n", "<A-f>", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)
keymap("n", "[d", '<cmd>lua vim.diagnostic.goto_prev({ border = "rounded" })<CR>', opts)
keymap("n", "gl", '<cmd>lua vim.diagnostic.open_float({ border = "rounded" })<CR>', opts)

keymap("n", "ge", '<cmd>lua vim.diagnostic.goto_next({ border = "rounded" })<CR>', opts)
keymap("i", "<A-c>", '<cmd>lua require("copilot.suggestion").accept()<CR>', opts)
keymap("n", "<leader>q", "<cmd>lua vim.diagnostic.setloclist()<CR>", opts)

-- std stuff
keymap("n", "q", "<Nop>", opts) -- disable recording feature

vim.g.mapleader = "<Space>"
keymap("n", "<Leader-e>", ":NvimTreeToggle<CR>", opts)

keymap("n", "<D-s>", ":NvimTreeToggle<CR>", opts)
keymap("n", "<M-s>", ":NvimTreeToggle<CR>", opts)

local refs = require("telescope.builtin").lsp_references

keymap_lua("n", "gr", refs, opts)

local opened = false

local function gitView()
  vim.pretty_print(opened)
  if not opened then
    require("diffview").open()
  else
    require("diffview").close()
  end

  opened = not opened
end

keymap_lua("n", "<A-g>", gitView, opts)
