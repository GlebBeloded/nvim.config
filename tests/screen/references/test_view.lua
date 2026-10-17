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
	i = "@punctuation.delimiter",
	j = "@operator",
	q = "@variable.member",
	v = "@type",
	H = "@function",
	J = "@property",
	M = "@module.go",
	V = "@variable.go",
	B = "@punctuation.bracket.go",
	P = "ReferencesProduction",
	p = "ReferencesProductionLabel",
	E = "ReferencesTest",
	e = "ReferencesTestLabel",
	D = "ReferencesFolder",
	d = "ReferencesFolderLabel",
	G = "DevIconGo",
	g = "ReferencesFileLabelDevIconGo",
	C = "ReferencesUsageTypeCall",
	a = "ReferencesUsageTypeCallLabel",
	W = "ReferencesUsageTypeWrite",
	w = "ReferencesUsageTypeWriteLabel",
	Y = "ReferencesUsageTypeRead",
	y = "ReferencesUsageTypeReadLabel",
	z = "ReferencesMaskBackground",
}

local KIND_GROUPED_MASK = {
	"....................................................................................................",
	"..btttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssfffffffffffffffffffffffffffffffffb..",
	"..bfffffWfwwwwwwwwwwwffsfffffffffffffffffffffbfsssffkkkkkkkfMMMMMMfffffffffffffffffffffffffffffffb..",
	"..bfffffffDfddddddffsffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bcccccccccGcggggggggcccccccccccccccccccccccbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffb..",
	"..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffkkkfVVVVVfTTTffffffffffffffffffffffffffffffffb..",
	"..bfffffWfwwwwwwwwwwwffsfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffDfddddddffsffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffb..",
	"..bfffffffffGfgggggggggggggssffffffffffffffffbfsssffkkkkfHHHHHBBfBfffffffffffffffffffffffffffffffb..",
	"..bfffffYfyyyyyyyyyyffsffffffffffffffffffffffbfrrrffffffhhhhhjjffffffffffffffffffffffffffffffffffb..",
	"..bfffffffDfddddddffsffffffffffffffffffffffffbfsssffBffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffffGfgggggggggggggssffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffffGfgggggggggggggssffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..",
	"..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"....................................................................................................",
}

local KIND_TAGGED_MASK = {
	"....................................................................................................",
	"..btttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssfffffffffffffffffffffffffffffffffb..",
	"..bfffffDfddddddffsffffffffffffffffffffffffffbfsssffkkkkkkkfMMMMMMfffffffffffffffffffffffffffffffb..",
	"..bcccccccGcggggggggcccccccccccccccccWcwwwwwcbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffb..",
	"..bfffffDfddddddffsffffffffffffffffffffffffffbfsssffkkkfVVVVVfTTTffffffffffffffffffffffffffffffffb..",
	"..bfffffffGfgggggggggggggssffffffffffWfwwwwwfbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffGfgggggggggggggssfffffffffffYfyyyyfbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffb..",
	"..bfffffffGfgggggggggggggssfffffffffffYfyyyyfbfsssffkkkkfHHHHHBBfBfffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffhhhhhjjffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffBffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb..",
	"..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"....................................................................................................",
}

local WIDE_DEFAULT_MASK = {
	"....................................................................................................",
	"..bttttttttttttttttttttttbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb..",
	"..bfffPfppppppppppffsffffffffffffffffffffffffbfsssssssssssssssssssssfffffffffffffffffffffffffffffb..",
	"..bfffffDfdddddddffsfffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmb..",
	"..bcccccccGcggggggggggcccccccccccccccccccccccbfsssffkkkkfffffffffkkkkkkfzffffffffffffffffffffffffb..",
	"..bfffffffGfggggggggggsssffffffffffffffffffffbfsssffffffffffffzzTTTffffffffffffffffffffffffffffffb..",
	"..bfffffDfddddddffsffffffffffffffffffffffffffbfsssffzffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffGfggggggggggssfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffEfeeeeffsffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmfffffffffb..",
	"..bfffffDfddddddddddddddffsffffffffffffffffffbfsssffkkkkfzzfvvvvvvvzfHHHzzfTTTTTTfzffffffffffffffb..",
	"..bfffffffGfgggggggggggggssffffffffffffffffffbfsssffffffffffffjjfnfffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkffifffffffjjfkkkkkffiJJJJJfzffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffjjfffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffzffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfrrrffffffkkkkkkffffffihhhhhhzfffffzfffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffzffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffkkkkfzzfvvvvvvvzfHHHHHHHHzzfzzTTTTTTfzfffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffjjfzzTTTTTTzzffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkffifffffffjjfkkkkkffiJJJJJfzffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffffffffffffjfHHHHHHzfffffiffffffihhhhhhzffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffzffffffffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffffffffffffffffffb..",
	"..bffffffffffffffffffffffffffffffffffffffffffbfsssffzffffffffffffffffffffffffffffffffffffffffffffb..",
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

-- Pin each usage-type colour family and the state hint against the proposed
-- renders. The screenshots above these masks pin every cell and attribute.
WIDE_DEFAULT_MASK[4] =
	"BBbVVVVVCVaaaaVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmbBB"
WIDE_DEFAULT_MASK[28] =
	"..bfffffffffffffffffffffffffxxxxxxxxxxxxxxxxxxxoxxxxxxxxxxxxxoxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxb.."
NARROW_MASK[7] = "BBBBBBBBBbVVVVVCVaaaaVVDVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBBBBBBBBBB"

KIND_GROUPED_MASK[4] =
	"BBbVVVVVHVwwwwwwwwwwwVVDVVVVVVVVVVVVVVVVVVVVVbVDDDVVjjjjjjjVBBBBBBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB"
KIND_GROUPED_MASK[8] =
	"..bfffffYfyyyyyyyyyyffsffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb.."
KIND_GROUPED_MASK[12] =
	"..bfffffWfwwwwwwwwwwwffsfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb.."
KIND_GROUPED_MASK[28] = WIDE_DEFAULT_MASK[28]

KIND_TAGGED_MASK[8] =
	"..bfffffffGfgggggggggggggssffffffffffWfwwwwwfbfsssfffffffffffffffffffffffffffffffffffffffffffffffb.."
KIND_TAGGED_MASK[9] =
	"BBbVVVVVVVGVgggggggggggggDDVVVVVVVVVVVEVeeeeVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmVVVVVVVbBB"
KIND_TAGGED_MASK[10] =
	"..bfffffffGfgggggggggggggssfffffffffffYfyyyyfbfsssffkkkkfooooofffffffffffffffffffffffffffffffffffb.."

local STRUCT_GROUPED_MASK = {
	"BBbVVVVVJVpppppppppppppppppVVDVVVVVVVVVVVVVVVbVDDDVVjjjjjjjVBBBBBBBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVbBB",
	"..bfffffPfpppppppppppppppppppppffsfffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffPfppppppppffsffffffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffPfpppppppppppffsfffffffffffffffffffffbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffCfaaaaaaaaaaaaaaaaaaaaaffsfffffffffffbfsssffffffffffffffffffoooooofffffffffffffffffffffffb..",
	"..bfffffCfaaaaaaaaaaaaaaaaaaaaaffsfffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
}

local STRUCT_TAGGED_MASK = {
	"BBbVVVVVVVGVggggggggDDVVVVVVVVVVVVVVVJVpppppVbVDDDVVmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmbBB",
	"..bfffffffGfggggggggsssfffffffffffffPfppppppfbfsssffkkkkfffffffkkkkkkffffffffffffffffffffffffffffb..",
	"..bfffffffGfggggggggsssfffffffffffffffCfaaaafbfffffffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffGfggggggggsssffffffffffffffPfpppppfbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffGfggggggggsssfffffffffffffPfppppppfbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffGfggggggggggsssfffffffffPfppppppppfbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
	"..bfffffffGfggggggggggsssfffffffffPfppppppppfbfsssffsssssssssssssssssssssssssssssssssssssssssssssb..",
	"..bfffYfyyyyffsffffffffffffffffffffffffffffffbfsssffkkkkfoooffffffffffffffPPPffffffffffffffffffffb..",
	"..bfffffDfdddddddffsfffffffffffffffffffffffffbfsssffffffkkkkkkfffffffffffffffffffPPPfffffffffffffb..",
	"..bfffffffGfgggggggggggggggssfffffffffCfaaaafbfsssfffffffffffffffffffffffffffffffffffffffffffffffb..",
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
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
	child.cmd("redraw")
end

local function open_calls()
	child.o.columns, child.o.lines = 100, 30
	local declaration = manifest.references.Calls[1]
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
	child.cmd("redraw")
end

local function open_invoice()
	child.o.columns, child.o.lines = 100, 30
	local declaration = manifest.references.Invoice[1]
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
	child.cmd("redraw")
end

local function tree_lines()
	return child.lua_get([[vim.api.nvim_buf_get_lines(require("gleb.references.view").state.tree_buf, 0, -1, false)]])
end

local function hint_line()
	return child.lua_get(
		[=[vim.api.nvim_buf_get_lines(require("gleb.references.view").state.hint_buf, 0, 1, false)[1]]=]
	)
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
	for index = 1, #result do
		result[index] = result[index]:gsub("%.", "z")
	end
	return result
end

T["references: Wide view matches reference screenshot"] = function()
	open_format(100, 30)
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 4, with_cleared_background({ WIDE_DEFAULT_MASK[4] }), LEGEND)
	H.expect_screen_colors(child, 28, with_cleared_background({ WIDE_DEFAULT_MASK[28] }), LEGEND)
end

T["references: Tests key cycles grouped, hidden and mixed"] = function()
	open_format(100, 30)
	local default = tree_lines()
	child.type_keys("t")
	eq(child.lua_get([[require("gleb.references.view").state.tree.count]]), 3)
	eq(hint_line():find("Tests: hidden t", 1, true) ~= nil, true)
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())

	child.type_keys("t")
	eq(
		child.lua_get([[(function()
		local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
		return {
			text:find("Production", 1, true) == nil,
			text:find("Test  ", 1, true) == nil,
			text:find("money_test.go:6", 1, true) ~= nil,
			text:find(" test", 1, true) ~= nil,
		}
	end)()]]),
		{ true, true, true, true }
	)
	eq(tree_lines()[1], "▾  Call  4")
	eq(hint_line():find("Tests: mixed t", 1, true) ~= nil, true)

	child.type_keys("t")
	eq(tree_lines(), default)
end

T["references: Mixed tests without folders is a flat list"] = function()
	open_format(100, 30)
	child.type_keys("ttf")
	eq(tree_lines(), {
		"▾  Call  4",
		"   billing/invoice.go:16",
		"   billing/invoice.go:23",
		"   …ternal/money/money_test.go:6  test",
		"   report/summary.go:7",
	})
	eq(hint_line():find("Tests: mixed t · ○ Folders f", 1, true) ~= nil, true)
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())
end

T["references: Narrow view fits its content"] = function()
	open_format(70, 24)
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 7, with_cleared_background({ NARROW_MASK[7] }), LEGEND)
end

local grouped_scenario = "references: Variable usages are grouped by write and read"
T[grouped_scenario] = MiniTest.new_set()
T[grouped_scenario]["matches approved K1"] = function()
	open_calls()
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 4, with_cleared_background({ KIND_GROUPED_MASK[4] }), LEGEND)
end

local tagged_scenario = "references: u turns the level into row tags"
T[tagged_scenario] = MiniTest.new_set()
T[tagged_scenario]["matches approved K2 through the real key"] = function()
	open_calls()
	child.type_keys("u")
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 8, with_cleared_background({ KIND_TAGGED_MASK[8] }), LEGEND)
end

T["references: Struct usages are grouped by usage type"] = function()
	open_invoice()
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 4, with_cleared_background({ STRUCT_GROUPED_MASK[1] }), LEGEND)
end

T["references: u turns struct usage types into row tags"] = function()
	open_invoice()
	child.type_keys("u")
	child.cmd("redraw")
	H.expect_screenshot(child.get_screenshot())
	clear_background_for_mask()
	H.expect_screen_colors(child, 6, with_cleared_background({ STRUCT_TAGGED_MASK[1] }), LEGEND)
end

return T
