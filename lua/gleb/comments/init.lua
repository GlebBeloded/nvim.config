-- for comment colorschemes refer to gleb.colors.[theme].comments

-- pluggin for better comments (especially in multilang files)
local comments = require("Comment.api")
local opts = { noremap = true, silent = true }

-- keymaps
-- line comment for <c-/> idk why it's mapped to gc
vim.api.nvim_set_keymap("n", "gc", ":lua require('Comment.api').toggle.linewise.current({})<CR>", opts)

-- multiline comment for <c-/>
vim.api.nvim_set_keymap(
	"x",
	"gc",
	'<ESC><CMD>lua require("Comment.api").toggle.linewise(vim.fn.visualmode())<CR>',
	opts
)
