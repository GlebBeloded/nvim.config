local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
end

---@param name string file name inside a fresh non-git temp dir
local function edit_scratch(name)
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	child.cmd("cd " .. dir .. " | edit " .. name)
end

local T = H.child_set(child, start)

T["lsp: diagnostic signs use Nerd Font glyphs"] = function()
	local text = child.lua_get([[vim.diagnostic.config().signs.text]])
	local severity = vim.diagnostic.severity

	eq(text[severity.ERROR], "\u{F057}")
	eq(text[severity.WARN], "\u{F071}")
	eq(text[severity.HINT], "\u{F0335}")
	eq(text[severity.INFO], "\u{F05A}")
end

T["lsp: error sign drawn in sign column"] = function()
	edit_scratch("sample.lua")
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "local M = {}" })
	child.lua([[
		local ns = vim.api.nvim_create_namespace("test")
		vim.diagnostic.set(ns, 0, { { lnum = 0, col = 0, message = "e", severity = vim.diagnostic.severity.ERROR } })
	]])
	child.cmd("redraw")

	local first_row = child.fn.win_screenpos(0)[1]
	eq(H.screen_rows(child, first_row).text[1][1], "\u{F057}")
end

return T
