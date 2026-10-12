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

-- gruvbox-material (medium, dark) colors the screenshots cannot see.
local DARK = "#282828"

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
end

T["statusline: insert mode accent matches reference screenshot"] = function()
	child.type_keys("i")
	expect_statusline_screenshot("INSERT")
	H.expect_colors(H.statusline_colors(child, "INSERT"), { fg = DARK, bg = "#7daea3", bold = true })
end

return T
