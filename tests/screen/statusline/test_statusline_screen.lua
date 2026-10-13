-- Reference screenshots of the global statusline row (tests/screenshots/).
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local H = require("tests.helpers")

local child = H.new_child()

--- A Lua file in a non-git temp dir (no branch/diff) without an LSP client,
--- so the language chip shows the deterministic "no LSP" cap.
local function start()
	child.start_config()
	child.wait_very_lazy()
	child.lua([[vim.lsp.enable("lua_ls", false)]])
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	child.cmd("cd " .. dir .. " | edit sample.lua")
end

--- Wait until lualine has drawn the mode, then compare the last row.
---@param mode_label string
local function expect_statusline_screenshot(mode_label)
	vim.wait(1500, function()
		return table.concat(H.screen_rows(child, -1).text[1]):find(mode_label, 1, true) ~= nil
	end, 50)
	H.expect_screenshot(H.screen_rows(child, -1))
end

-- gruvbox-material (medium, dark) colors the masks cannot see: a mask compares
-- each cell with its own group, so the groups' palette colors are pinned here.
local DARK = "#282828"
local CHIP = { fg = "#ddc7a1", bg = "#413a36" } -- language chip (palette chip_bg / text_hi)

local T = H.child_set(child, start)

T["statusline: statusline matches reference screenshot"] = function()
	expect_statusline_screenshot("NORMAL")
	H.expect_screen_colors(child, -1, {
		"aaaaaaaacccccccccccccccccccccccccccccccccccccccccccccccccccccccceeeeewwwwtlttttt",
	}, {
		a = "lualine_a_normal",
		c = "lualine_c_normal",
		e = "lualine_x_diagnostics_error_normal",
		w = "lualine_x_diagnostics_warn_normal",
		t = "StatuslineLangText",
		l = "StatuslineLang_lua",
	})
	H.expect_hl_colors(child, "lualine_a_normal", { fg = DARK, bg = "#a9b665", bold = true })
	H.expect_hl_colors(child, "StatuslineLangText", CHIP)
end

T["statusline: insert mode accent matches reference screenshot"] = function()
	child.type_keys("i")
	expect_statusline_screenshot("INSERT")
	H.expect_screen_colors(child, -1, {
		"aaaaaaaacccccccccccccccccccccccccccccccccccccccccccccccccccccccceeeeewwwwtlttttt",
	}, {
		a = "lualine_a_insert",
		c = "lualine_c_normal", -- the theme has no Insert c section, so lualine draws Normal's
		e = "lualine_x_diagnostics_error_insert",
		w = "lualine_x_diagnostics_warn_insert",
		t = "StatuslineLangText",
		l = "StatuslineLang_lua",
	})
	H.expect_hl_colors(child, "lualine_a_insert", { fg = DARK, bg = "#7daea3", bold = true })
	H.expect_hl_colors(child, "StatuslineLangText", CHIP)
end

return T
