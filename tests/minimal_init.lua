-- Init for the mini.test runner and for "bare" child Neovims (unit layer).
-- Adds the config root and the pinned mini.nvim (tests/bootstrap.sh) to the
-- runtimepath without loading the user's config or plugins.

---@type string
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local deps = vim.env.TEST_DEPS_DIR or (root .. "/.tests/deps")

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(deps .. "/mini.nvim")
package.path = string.format("%s/?.lua;%s/?/init.lua;%s", root, root, package.path)

vim.o.swapfile = false
vim.o.shadafile = "NONE"

require("mini.test").setup()
