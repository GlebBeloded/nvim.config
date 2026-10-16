-- Reference screenshots of Find Usages at its wide and narrow breakpoints.
local F = require("tests.fixtures")
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality
local TIMEOUT_MS = H.lsp_timeout(10000)

local root
local manifest

local LEGEND = {
	b = "PickerBorder",
	t = "MiniPickBorderText",
	f = "MiniPickNormal",
	c = "MiniPickMatchCurrent",
	s = "PickerSecondary",
	r = "CursorLineNr",
	h = "Search",
	x = "PickerHint",
	o = "PickerToggleOn",
	k = "@keyword",
	T = "@type.builtin",
	F = "@function.call",
	m = "@comment",
	n = "@number",
	P = "ReferencesProduction",
	p = "ReferencesProductionLabel",
	E = "ReferencesTest",
	e = "ReferencesTestLabel",
	D = "ReferencesFolder",
	d = "ReferencesFolderLabel",
	G = "DevIconGo",
	g = "ReferencesFileLabelDevIconGo",
	z = "ReferencesMaskBackground",
}

local WIDE_DEFAULT_MASK = {
	"....................................................................................................",
	"..bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssssssfffffffffffffffffffffffffffffb..",
	"..bfffffDfdddddddffsfffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..",
	"..bcccccccGcggggggggggcccccccccccccccccccccccbfsssffkkkkfffffffffkkkkkkffffffffffffffffffffffffffb..",
	"..bfffffffGfggggggggggsssffffffffffffffffffffbfsssffffffffffffffTTTffffffffffffffffffffffffffffffb..",
	"..bfffffDfddddddffsffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffGfggggggggggssfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..",
	"..bfffffDfddddddddddddddffsffffffffffffffffffbfsssffkkkkfffffffffffffFFFfffTTTTTTffffffffffffffffb..",
	"..bfffffffGfgggggggggggggssffffffffffffffffffbfsssfffffffffffffffnfffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffkkkkkkfffffffhhhhhhffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfffffffffffffFFFFFFFFfffffTTTTTTfffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffTTTTTTffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkfffffffffffffkkkkkffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffffFFFFFFffffffffffffffhhhhhhfffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"..bffffffffffffffffffffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..",
	"..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"....................................................................................................",
}

local NARROW_MASK = {
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"..................bttttttttttttttttttttttbbbbbbbbbbb..................",
	"..................bfffPfppppppppppffsffffffffffffffb..................",
	"..................bfffffDfdddddddffsfffffffffffffffb..................",
	"..................bcccccccGcggggggggggcccccccccccccb..................",
	"..................bfffffffGfggggggggggsssffffffffffb..................",
	"..................bfffffDfddddddffsffffffffffffffffb..................",
	"..................bfffffffGfggggggggggssfffffffffffb..................",
	"..................bfffEfeeeeffsffffffffffffffffffffb..................",
	"..................bfffffDfddddddddddddddffsffffffffb..................",
	"..................bfffffffGfgggggggggggggssffffffffb..................",
	"..................bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..................",
	"..................bfxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxb..................",
	"..................bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
}

local function start()
	root, manifest = F.copy("gomod", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.lua([[require("null-ls").disable({ name = "golangci_lint" })]])
end

local T = H.child_set(child, start)

---@param columns integer
---@param lines integer
local function open_format(columns, lines)
	child.o.columns, child.o.lines = columns, lines
	local call = vim.iter(manifest.references.Format):find(function(location)
		return location.path == "billing/invoice.go" and location.line == 16
	end)
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(call.path))
	child.api.nvim_win_set_cursor(0, { call.line, call.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	child.cmd("redraw")
end

-- Design masks intentionally leave the editor outside the view uncoloured. Clear
-- that background after the text screenshot so only view-owned colours are checked.
local function clear_background_for_mask()
	child.lua([[
local view = require("gleb.references.view")
local win = view.state.origin_win
local buf = vim.api.nvim_win_get_buf(win)
vim.bo[buf].modifiable = true
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
vim.wo[win].number = false
vim.wo[win].relativenumber = false
vim.wo[win].signcolumn = "no"
vim.wo[win].winhighlight = "EndOfBuffer:Normal,LineNr:Normal,SignColumn:Normal"
local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
vim.api.nvim_set_hl(0, "NormalNC", normal)
vim.api.nvim_set_hl(0, "NormalFloat", normal)
vim.api.nvim_set_hl(0, "EndOfBuffer", normal)
vim.api.nvim_set_hl(0, "NonText", normal)
local palette = require("gleb.colors.gruvbox-material.palette")
vim.api.nvim_set_hl(0, "ReferencesMaskBackground", {
	fg = palette.foreground.fg0,
	bg = palette.background.bg0,
})
vim.o.showtabline = 0
vim.o.laststatus = 0
vim.cmd("redraw!")
]])
end

---@param mask string[]
---@return string[]
local function with_cleared_background(mask)
	local result = vim.deepcopy(mask)
	for index = 2, #result do
		result[index] = result[index]:gsub("%.", "z")
	end
	return result
end

T["references: Wide view matches reference screenshot"] = function()
	open_format(100, 30)
	H.expect_screenshot(child.get_screenshot())

	child.type_keys("t")
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())

	child.type_keys("tf")
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())

	child.type_keys("tf")
	child.cmd("redraw")
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_background(WIDE_DEFAULT_MASK), LEGEND)
end

T["references: Narrow view fits its content"] = function()
	open_format(70, 24)
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 1, with_cleared_background(NARROW_MASK), LEGEND)
end

return T
