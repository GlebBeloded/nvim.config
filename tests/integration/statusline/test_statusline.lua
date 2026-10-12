local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ERROR_SYMBOL = vim.fn.nr2char(0xf057) .. " "
local WARN_SYMBOL = vim.fn.nr2char(0xf071) .. " "

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

---@return string text of the last screen row (the global statusline)
local function statusline_text()
	return table.concat(H.screen_rows(child, -1).text[1])
end

--- Poll: lualine refreshes on events and a timer, not synchronously.
---@param needle string
local function expect_statusline_contains(needle)
	local found = vim.wait(1500, function()
		return statusline_text():find(needle, 1, true) ~= nil
	end, 50)
	if not found then
		error(string.format("expected statusline %q to contain %q", statusline_text(), needle))
	end
end

--- Diff symbols of `lua/gleb/lualine.lua` (added, modified, removed); the spec
--- shows them as empty backticks until fix-empty-nerd-font-glyphs.
local DIFF_SYMBOLS = { vim.fn.nr2char(0xf457), vim.fn.nr2char(0xf459), vim.fn.nr2char(0xf458) }

---@param needles string[]
---@return boolean
local function statusline_has_any(needles)
	local text = statusline_text()
	return vim.iter(needles):any(function(needle)
		return text:find(needle, 1, true) ~= nil
	end)
end

--- Replace nvim-navic in the child with a stub that reports `location`.
---@param location string
local function stub_navic(location)
	child.lua(
		[[
		local location = ...
		package.loaded["nvim-navic"] = {
			is_available = function() return true end,
			get_location = function() return location end,
		}
	]],
		{ location }
	)
end

--- 1-based screen column where `text` starts in a row of cells (nil if absent).
---@param cells string[]
---@param text string
---@return integer?
local function location_column(cells, text)
	local first = vim.fn.strcharpart(text, 0, 1)
	for col = 1, #cells do
		if cells[col] == first and table.concat(cells, "", col):sub(1, #text) == text then
			return col
		end
	end
end

local T = H.child_set(child, start)

T["statusline: statusline is global"] = function()
	eq(child.o.laststatus, 3)
end

T["statusline: mode section shows current mode"] = function()
	edit_scratch("sample.txt")
	expect_statusline_contains("NORMAL")

	eq(vim.startswith(statusline_text(), " NORMAL "), true)
end

T["statusline: diagnostics always visible"] = function()
	child.o.columns = 100
	edit_scratch("sample.txt")

	expect_statusline_contains(ERROR_SYMBOL .. "0")
	expect_statusline_contains(WARN_SYMBOL .. "0")
end

T["statusline: diagnostics show error and warn counts"] = function()
	child.o.columns = 100
	edit_scratch("sample.txt")
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "a", "b", "c" })
	child.lua([[
		local ns = vim.api.nvim_create_namespace("test")
		local E, W = vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN
		vim.diagnostic.set(ns, 0, {
			{ lnum = 0, col = 0, message = "e1", severity = E },
			{ lnum = 1, col = 0, message = "e2", severity = E },
			{ lnum = 2, col = 0, message = "w1", severity = W },
		})
	]])

	expect_statusline_contains(ERROR_SYMBOL .. "2")
	expect_statusline_contains(WARN_SYMBOL .. "1")
end

T["statusline: statusline disabled on dashboard"] = function()
	eq(child.bo.filetype, "alpha")
	vim.uv.sleep(200)

	eq(statusline_text():find("NORMAL", 1, true), nil)
end

T["statusline: diff hidden in narrow windows"] = function()
	local repo = H.git_repo({ ["sample.txt"] = "a\nb\n" })
	H.write_files(repo, { ["sample.txt"] = "a\nchanged\nadded\n" })
	child.o.columns = 120
	child.cmd("cd " .. repo .. " | edit sample.txt")
	-- wide first: the diff is shown, so its absence below is due to the width
	expect_statusline_contains(DIFF_SYMBOLS[1])

	child.o.columns = 80
	child.cmd("redrawstatus")
	vim.wait(1500, function()
		return not statusline_has_any(DIFF_SYMBOLS)
	end, 50)

	eq(statusline_has_any(DIFF_SYMBOLS), false)
end

T["statusline: navic breadcrumb shown when available"] = function()
	child.o.columns = 100
	edit_scratch("sample.txt")
	stub_navic("Server ▸ Handle")
	expect_statusline_contains("Server ▸ Handle")

	local cells = H.screen_rows(child, -1).text[1]
	eq(location_column(cells, "Server ▸ Handle") <= #cells / 2, true)
end

T["statusline: chip highlights survive colorscheme change"] = function()
	child.cmd("colorscheme default")
	local groups = {
		"StatuslineLangText",
		"StatuslineLspOk",
		"StatuslineLspError",
		"StatuslineLangEdge",
		"StatuslineLangCapOk",
		"StatuslineLangCapError",
	}
	for _, group in ipairs(groups) do
		eq(
			{ group, child.lua_get("not vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = ... }))", { group }) },
			{ group, true }
		)
	end
end

return T
