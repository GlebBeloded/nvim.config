-- E2E workflow: `gr` on a Go function in a fresh copy of the gomod fixture
-- opens Find Usages, `t` hides tests, and Return on a selected usage opens it.
-- Real key presses drive every transition; fixture facts and approved render rows
-- are independent expectations.
local MiniTest = require("mini.test")
local E = require("tests.e2e.alacritty")
local F = require("tests.fixtures")
local S = require("tests.shortcuts.stack")

local eq = MiniTest.expect.equality

---@type e2e.Stack?
local stack
---@type string?
local skipped
---@type string fixture copy (Neovim's cwd)
local root
---@type fixtures.Manifest
local manifest

---@param dir string the stack's temp dir
---@return string
local function copy_gomod(dir)
	root, manifest = F.copy("gomod", dir .. "/work")
	return root
end

local function start()
	stack, skipped = E.start_or_skip({ cwd = copy_gomod, env = F.go_env(), layout = "nvim", columns = 100, lines = 30 })
end

local function stop()
	if stack then
		stack:stop()
		stack = nil
	end
end

---@return e2e.Stack
local function get()
	if skipped then
		MiniTest.skip("SKIPPED (reason on the first line)")
	end
	return assert(stack, "e2e stack not started")
end

local RESET_VIEW = [[require("gleb.references.view").close()
	require("gleb.references.state").save({ tests = "grouped", folders = true, read_write = true })]]

--- Every case starts from the default view state, whatever earlier cases on the shared stack persisted.
local function reset_view()
	if stack then
		stack:lua(RESET_VIEW)
	end
end

local T = MiniTest.new_set({ hooks = { pre_once = start, pre_case = reset_view, post_once = stop } })

---@param locations fixtures.Location[]
---@return fixtures.Location[] sorted copy, for set comparison
local function sorted(locations)
	local copy = vim.deepcopy(locations)
	table.sort(copy, function(a, b)
		if a.path ~= b.path then
			return a.path < b.path
		end
		if a.line ~= b.line then
			return a.line < b.line
		end
		return a.col < b.col
	end)
	return copy
end

---@param locations fixtures.Location[]
---@return string[] sorted paths
local function paths(locations)
	local list = vim.tbl_map(function(location)
		return location.path
	end, locations)
	table.sort(list)
	return list
end

local GOPLS_READY = [[local client = vim.lsp.get_clients({ bufnr = 0, name = "gopls" })[1]
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	params.context = { includeDeclaration = true }
	local reply = client:request_sync("textDocument/references", params, 2000, 0)
	return reply ~= nil and reply.result ~= nil and #reply.result > 0]]

local VIEW_ENTRIES = [[local root = vim.uv.fs_realpath(...) .. "/"
	local entries = {}
	for _, entry in ipairs(require("gleb.references.view").state.usages or {}) do
		local path = vim.uv.fs_realpath(vim.uri_to_fname(entry.uri)) or vim.uri_to_fname(entry.uri)
		table.insert(entries, { path = path:sub(#root + 1), line = entry.lnum, col = entry.col })
	end
	return entries]]

---@param s e2e.Stack
---@param rows string[]
local function expect_render_rows(s, rows)
	local dump = s:zellij("dump-screen")
	for _, row in ipairs(rows) do
		assert(dump:find(row, 1, true), "approved render row missing: " .. row .. "\nscreen:\n" .. dump)
	end
end

--- Open the references picker of `Format` from its declaration (gopls ready first).
---@param s e2e.Stack
local function open_references(s)
	local declaration = manifest.references.Format[1]
	-- golangci-lint is not in the sandbox (mason's bin dir is isolated): null-ls would
	-- report it on a hit-enter prompt (cmdheight=0) that blocks Neovim
	s:lua([[require("null-ls").disable({ name = "golangci_lint" })]])
	s:lua("vim.cmd.edit({ ..., mods = { silent = true } })", { declaration.path })
	s:lua("vim.api.nvim_win_set_cursor(0, { ... })", { declaration.line, declaration.col - 1 })
	eq(s:lua([[return vim.fn.executable("gopls")]]), 1)
	S.wait_for(function()
		return s:lua([[return #vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]])
	end, "gopls attached to " .. declaration.path)
	S.wait_for(function()
		return s:lua(GOPLS_READY)
	end, "a non-empty textDocument/references reply from gopls")
	E.burst(s, function()
		E.press(s, { "g", "r" })
		S.wait_for(function()
			return s:lua([[return require("gleb.references.view").state.tree_win ~= nil]])
		end, "Find Usages view")
	end)
	S.wait_for(function()
		return not s:lua([[return require("gleb.references.view").state.classifying]])
	end, "Format usage classification")
end

--- Open the references picker of `Calls` from its declaration through `gr`.
---@param s e2e.Stack
local function open_calls(s)
	local declaration = manifest.references.Calls[1]
	s:lua([[require("null-ls").disable({ name = "golangci_lint" })]])
	s:lua("vim.cmd.edit({ ..., mods = { silent = true } })", { declaration.path })
	s:lua("vim.api.nvim_win_set_cursor(0, { ... })", { declaration.line, declaration.col - 1 })
	S.wait_for(function()
		return s:lua([[return #vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]])
	end, "gopls attached to " .. declaration.path)
	E.burst(s, function()
		E.press(s, { "g", "r" })
		S.wait_for(function()
			return s:lua([[return require("gleb.references.view").state.tree_win ~= nil]])
		end, "Find Usages view for Calls")
	end)
	S.wait_for(function()
		return not s:lua([[return require("gleb.references.view").state.classifying]])
	end, "Calls usage classification")
end

--- The references view of `Format`, opened unless the previous case left it open.
---@param s e2e.Stack
local function ensure_references(s)
	if not s:lua([[return require("gleb.references.view").state.tree_win ~= nil]]) then
		open_references(s)
	end
end

---@param path string repo-relative
---@return fixtures.Location
local function reference_in(path)
	local found = vim.iter(manifest.references.Format):find(function(location)
		return location.path == path
	end)
	return assert(found, "no manifest reference in " .. path)
end

local CURRENT_FILE = [[local name = vim.api.nvim_buf_get_name(0)
	local cursor = vim.api.nvim_win_get_cursor(0)
	return { path = vim.uv.fs_realpath(name) or name, line = cursor[1], col = cursor[2] + 1 }]]

T["lsp: References of a Go function list call sites across packages"] = function()
	local s = get()
	open_references(s)
	local expected = vim.list_slice(manifest.references.Format, 2)
	eq(sorted(s:lua(VIEW_ENTRIES, { root })), sorted(expected))
	eq(paths(expected), {
		"billing/invoice.go",
		"billing/invoice.go",
		"internal/money/money_test.go",
		"report/summary.go",
	})
	expect_render_rows(s, {
		"╭ Usages of Format · 4",
		"│ ▾  Production  3",
		"│   ▾  Call  3",
		"│          invoice.go:16",
		"│          summary.go:7",
		"│ ▾  Test  1",
		"Tests: grouped t · ● Folders f · ● Usage type u · Preview P · Open ↩",
	})

	E.burst(s, function()
		E.press(s, "t")
		S.wait_for(function()
			return s:lua([[return require("gleb.references.view").state.tree.count == 3]])
		end, "test usages hidden")
	end)
	expect_render_rows(s, {
		"╭ Usages of Format · 3",
		"│ ▾  Production  3",
		"│   ▾  Call  3",
		"│          summary.go:7",
		"Tests: hidden t · ● Folders f · ● Usage type u · Preview P · Open ↩",
	})
end

T["lsp: Selecting a reference opens its file at the call site"] = function()
	local s = get()
	ensure_references(s)
	local call = reference_in("report/summary.go")
	E.burst(s, function()
		if s:lua([[return require("gleb.references.view").state.options.tests == "grouped"]]) then
			E.press(s, "t")
		end
		E.press(s, { "j", "j", "j" })
		S.wait_for(function()
			return s:lua([[return vim.fn.getline("."):find("summary.go:7", 1, true) ~= nil]])
		end, "summary.go usage selected")
		E.press(s, "return")
		S.wait_for(function()
			return not s:lua([[return require("gleb.references.view").state.tree_win ~= nil]])
		end, "Find Usages view closed")
	end)
	eq(s:lua(CURRENT_FILE), {
		path = vim.uv.fs_realpath(root .. "/" .. call.path),
		line = call.line,
		col = call.col,
	})
end

T["references: Real key presses switch Calls usages from the level to row tags"] = function()
	local s = get()
	open_calls(s)
	expect_render_rows(s, {
		"╭ Usages of Calls · 4",
		"│ ▾  Production  1",
		"│   ▾ 󰏫 Value write  1",
		"│          calls.go:8",
		"│ ▾  Test  3",
		"│   ▾ 󰈈 Value read  2",
		"│          calls_test.go:8",
		"│          calls_test.go:9",
		"│   ▾ 󰏫 Value write  1",
		"│          calls_test.go:6",
		"Tests: grouped t · ● Folders f · ● Usage type u · Preview P · Open ↩",
	})

	E.burst(s, function()
		E.press(s, "u")
		S.wait_for(function()
			return s:lua([[return not require("gleb.references.view").state.options.usage_type]])
		end, "usage type level disabled")
	end)
	expect_render_rows(s, {
		"│        calls.go:8               󰏫 write",
		"│        calls_test.go:6          󰏫 write",
		"│        calls_test.go:8           󰈈 read",
		"│        calls_test.go:9           󰈈 read",
		"Tests: grouped t · ● Folders f · ○ Usage type u · Preview P · Open ↩",
	})
end

return T
