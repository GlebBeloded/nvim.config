local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local SHOW_AFTER_MS = 500
local LOG_PATH = "/tmp/nvim-lsp-progress.log"

local function start()
	child.start_bare()
	-- isolate from lualine: the module only calls refresh() from its timer
	child.lua([[
		package.loaded.lualine = { refresh = function() end }
		Progress = require("gleb.statusline.lsp_progress")
	]])
end

---@param value table LSP `$/progress` value (kind, title, message, percentage)
---@param token? string
local function fire(value, token)
	child.lua(
		[[vim.api.nvim_exec_autocmds("LspProgress", { data = { client_id = 1, params = { token = ..., value = select(2, ...) } } })]],
		{ token or "t1", value }
	)
end

---@return string
local function progress_after_delay()
	vim.uv.sleep(SHOW_AFTER_MS + 50)
	return child.lua_get("Progress.progress()")
end

--- Entry is `<spinner> <label>`; every spinner frame is 3 bytes of UTF-8.
---@param actual string
---@param label string
local function expect_entry(actual, label)
	local spinner, rest = actual:sub(1, 3), actual:sub(4)
	eq({ vim.list_contains(SPINNER, spinner), rest }, { true, " " .. label })
end

---@param a string
---@param b string
local function by_label(a, b)
	return a:sub(4) < b:sub(4)
end

local T = H.child_set(child, start)

T["statusline: progress hidden before 500 ms"] = function()
	fire({ kind = "begin", title = "Indexing" })

	eq(child.lua_get("Progress.progress()"), "")
end

T["statusline: progress shown after 500 ms with alias"] = function()
	fire({ kind = "begin", message = "Setting up workspace", percentage = 40 })

	expect_entry(progress_after_delay(), "indexing workspace 40%%")
end

T["statusline: report updates percentage"] = function()
	fire({ kind = "begin", title = "Building" })
	fire({ kind = "report", percentage = 75 })

	expect_entry(progress_after_delay(), "building 75%%")
end

T["statusline: end removes the task"] = function()
	fire({ kind = "begin", title = "Building" })
	fire({ kind = "end" })

	eq(progress_after_delay(), "")
end

T["statusline: concurrent tasks joined"] = function()
	fire({ kind = "begin", title = "Building" }, "a")
	fire({ kind = "begin", title = "Formatting" }, "b")

	local entries = vim.split(progress_after_delay(), "  ", { plain = true })
	table.sort(entries, by_label)
	eq(#entries, 2)
	expect_entry(entries[1], "building")
	expect_entry(entries[2], "formatting")
end

T["statusline: progress events are logged"] = function()
	local title = "SmokeTitle" .. vim.uv.hrtime()
	fire({ kind = "begin", title = title, message = "msg", percentage = 7 })

	local logged = vim.tbl_filter(function(line)
		return line:find(title, 1, true) ~= nil
	end, vim.fn.readfile(LOG_PATH))
	eq(#logged, 1)
	eq(
		logged[1]:match("kind=begin") ~= nil and logged[1]:match('msg="msg"') ~= nil and logged[1]:match("pct=7") ~= nil,
		true
	)
end

T["statusline: progress falls back to working"] = function()
	fire({ kind = "begin" })

	expect_entry(progress_after_delay(), "working")
end

T["statusline: unmatched message shown verbatim"] = function()
	fire({ kind = "begin", message = "Resolving" })

	expect_entry(progress_after_delay(), "Resolving")
end

return T
