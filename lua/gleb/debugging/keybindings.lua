local dap = require("dap")
local ui = require("dapui")

local opts = { noremap = true, silent = true }
-- Shorten function name
local keymap = vim.keymap.set

keymap("n", "<C-b>", dap.toggle_breakpoint, opts)
keymap("n", "<C-d>", dap.continue, opts)
keymap("n", "<A-J>", dap.step_over, opts)
keymap("n", "<A-H>", dap.step_out, opts)
keymap("n", "<A-L>", dap.step_into, opts)

-- toggle debugging ui
keymap("n", "<C-u>", ui.toggle, opts)
