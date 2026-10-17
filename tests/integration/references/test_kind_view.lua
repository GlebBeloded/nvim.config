local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local TIMEOUT_MS = H.lsp_timeout(10000)

local root
local manifest

local function start()
	root, manifest = F.copy("gomod", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.lua([[require("null-ls").disable({ name = "golangci_lint" })]])
	child.o.lines, child.o.columns = 30, 100
end

local T = H.child_set(child, start)

---@param symbol "Calls"|"Format"
---@param before_open? fun()
local function open_symbol(symbol, before_open)
	local declaration = manifest.references[symbol][1]
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
	if before_open then
		before_open()
	end
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
end

---@return string
local function title()
	return child.lua_get([=[vim.api.nvim_win_get_config(require("gleb.references.view").state.tree_win).title[1][1]]=])
end

---@return string
local function lines()
	return table.concat(child.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

---@return string
local function hint()
	return child.lua_get([[
vim.api.nvim_buf_get_lines(require("gleb.references.view").state.hint_buf, 0, 1, false)[1]
]])
end

---@param drop boolean
local function hold_document_highlights(drop)
	child.lua(
		[[
local drop = ...
local client = assert(vim.lsp.get_clients({ bufnr = 0, name = "gopls" })[1])
local original = client.request
client.request = function(self, method, params, handler, bufnr)
	if method == "textDocument/documentHighlight" then
		if not drop then
			_G.HeldHighlight = { self = self, method = method, params = params, handler = handler, bufnr = bufnr }
		end
		return true, 9001
	end
	return original(self, method, params, handler, bufnr)
end
_G.ReleaseHighlight = function()
	client.request = original
	local held = _G.HeldHighlight
	if held then
		local handler = held.handler
		held.handler = function(...)
			handler(...)
			_G.HighlightAnswered = true
		end
		original(held.self, held.method, held.params, held.handler, held.bufnr)
	end
end
]],
		{ drop }
	)
end

local persistence_scenario = "references: Read/write state persists across sessions"
T[persistence_scenario] = MiniTest.new_set()
T[persistence_scenario]["restores the disabled level"] = function()
	open_symbol("Calls")
	eq(
		child.wait([[vim.api.nvim_buf_get_lines(0, 0, -1, false)[2]:find("Value write", 1, true) ~= nil]], TIMEOUT_MS),
		true
	)
	child.type_keys("w")
	child.stop()

	child.restart_config({ "--cmd", "cd " .. root }, { env = F.go_env() })
	child.wait_very_lazy()
	child.lua([[require("null-ls").disable({ name = "golangci_lint" })]])
	open_symbol("Calls")
	eq(child.wait([[not vim.api.nvim_win_get_config(0).title[1][1]:find("classifying", 1, true)]], TIMEOUT_MS), true)
	eq(hint():find("○ Read/write w", 1, true) ~= nil, true)
	eq(lines():find("Value write", 1, true), nil)
	eq(lines():find("Value read", 1, true), nil)
end

local key_scenario = "references: The read/write key comes from the keymap file"
T[key_scenario] = MiniTest.new_set()
T[key_scenario]["owns the effective buffer mapping"] = function()
	open_symbol("Format")
	local actual = child.lua_get([[
(function()
	local map = vim.fn.maparg("w", "n", false, true)
	local shortcuts = vim.json.decode(table.concat(vim.fn.readfile(
		vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json")), "\n"))
	return { desc = map.desc, keys = shortcuts["references.toggle_read_write"] }
end)()
]])
	eq(actual, { desc = "References: Toggle Read/write", keys = { "w" } })
end

local async_scenario = "references: The view opens before classification finishes"
T[async_scenario] = MiniTest.new_set()
T[async_scenario]["leaves function-only views unchanged after classification"] = function()
	open_symbol("Format")
	eq(child.wait([[not vim.api.nvim_win_get_config(0).title[1][1]:find("classifying", 1, true)]], TIMEOUT_MS), true)
	eq(lines():find("Value write", 1, true), nil)
	eq(lines():find("Value read", 1, true), nil)
	eq(lines():find("Usage", 1, true), nil)
	eq(hint():find("Read/write", 1, true), nil)
end

T[async_scenario]["rebuilds around the selected usage"] = function()
	open_symbol("Calls", function()
		hold_document_highlights(false)
	end)
	eq(title(), " Usages of Calls · 4 · classifying ")
	eq(lines():find("Value write", 1, true), nil)

	local selected = manifest.references.Calls[4]
	local row = child.lua_get([[
(function()
	for index, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		if line:find("calls_test.go:8", 1, true) then return index end
	end
end)()
]])
	child.api.nvim_win_set_cursor(0, { row, 0 })
	eq(child.wait([[require("gleb.references.view").state.preview_usage.lnum == 8]]), true)
	child.lua([[_G.ReleaseHighlight()]])
	eq(
		child.wait([[vim.api.nvim_buf_get_lines(0, 0, -1, false)[2]:find("Value write", 1, true) ~= nil]], TIMEOUT_MS),
		true
	)
	eq(title(), " Usages of Calls · 4 ")
	eq(child.lua_get([[require("gleb.references.view").state.preview_usage.lnum]]), selected.line)
end

local timeout_scenario = "references: Classification gives up after the timeout"
T[timeout_scenario] = MiniTest.new_set()
T[timeout_scenario]["falls back silently after three seconds"] = function()
	local notifications
	open_symbol("Calls", function()
		hold_document_highlights(false)
		notifications = H.record_notify(child)
	end)
	eq(title(), " Usages of Calls · 4 · classifying ")
	eq(child.wait([[not vim.api.nvim_win_get_config(0).title[1][1]:find("classifying", 1, true)]], 5000), true)
	eq(lines():find("Value write", 1, true) ~= nil, true)
	child.lua([[_G.ReleaseHighlight()]])
	eq(child.wait([[_G.HighlightAnswered == true]], TIMEOUT_MS), true)
	child.type_keys("w")
	eq(lines():find("read", 1, true), nil)
	eq(notifications(), {})
end

return T
