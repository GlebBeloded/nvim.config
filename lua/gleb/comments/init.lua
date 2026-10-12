local opts = { remap = true, silent = true }

vim.keymap.set("n", "<A-/>", "gcc", opts)
vim.keymap.set("x", "<A-/>", "gc", opts)
