-- Build on the host every treesitter parser lua/gleb/treesitter.lua lists, before the sandbox syncs
-- site/ into the guest (the guest has no tree-sitter CLI: a missing parser would be compiled at its
-- startup and stop Neovim on a hit-enter prompt). Already built parsers are skipped.
-- Run: nvim --headless --clean -l tests/sandbox/parsers.lua <treesitter.lua> <data dir>
local source, data = _G.arg[1], _G.arg[2]
local text = table.concat(vim.fn.readfile(source), "\n")
local block = assert(text:match("local parsers = (%b{})"), "no `local parsers = {...}` in " .. source)
local parsers = assert(loadstring("return " .. block))()
local plugin = vim.fs.joinpath(data, "lazy/nvim-treesitter")
assert(vim.uv.fs_stat(plugin), "parsers.lua: no nvim-treesitter at " .. plugin)
vim.opt.rtp:prepend(plugin)
package.path = plugin .. "/lua/?.lua;" .. plugin .. "/lua/?/init.lua;" .. package.path
local ts = require("nvim-treesitter")
ts.setup({ install_dir = vim.fs.joinpath(data, "site") })
local ok = ts.install(parsers):wait(600000)
assert(ok, "parsers.lua: installing " .. table.concat(parsers, " ") .. " failed")
