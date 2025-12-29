-- for comment colorschemes refer to gleb.colors.[theme].comments

local opts = { noremap = true, silent = true }

-- keymaps
-- line comment for <c-/> idk why it's mapped to gc
vim.api.nvim_set_keymap("n", "<A-/>", ":lua require('Comment.api').toggle.linewise.current({})<CR>", opts)

-- multiline comment for <c-/>
vim.api.nvim_set_keymap(
	"x",
	"<A-/>",
	'<ESC><CMD>lua require("Comment.api").toggle.linewise(vim.fn.visualmode())<CR>',
	opts
)
