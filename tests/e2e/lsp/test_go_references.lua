-- E2E workflow: `gr` on a Go function in a fresh copy of the gomod fixture
-- (tests/fixtures/build.sh) lists its references through gopls in Telescope,
-- and Return on one opens it. Real key presses, state read over RPC; expected
-- locations come from the fixture's manifest.
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

local T = MiniTest.new_set({ hooks = { pre_once = start, post_once = stop } })

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

local PICKER_COUNT = [[if vim.bo.filetype ~= "TelescopePrompt" then return -1 end
	local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
	return picker.manager:num_results()]]

local PICKER_ENTRIES = [[local root = vim.uv.fs_realpath(...) .. "/"
	local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
	local entries = {}
	for entry in picker.manager:iter() do
		local path = vim.uv.fs_realpath(entry.filename) or entry.filename
		table.insert(entries, { path = path:sub(#root + 1), line = entry.lnum, col = entry.col })
	end
	return entries]]

---@param s e2e.Stack
---@param n integer
local function wait_picker(s, n)
	local count ---@type integer?
	local ok, err = pcall(S.wait_for, function()
		count = s:lua(PICKER_COUNT)
		return count == n
	end, string.format("Telescope picker with %d entries", n))
	if not ok then
		error(string.format("%s (last count %s), screen:\n%s", err, count, s:zellij("dump-screen")), 0)
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
			return s:lua(PICKER_COUNT) > 0
		end, "Telescope references picker with entries")
	end)
end

--- The references picker of `Format`, opened unless the previous case left it open.
---@param s e2e.Stack
local function ensure_references(s)
	if s:lua("return vim.bo.filetype") ~= "TelescopePrompt" then
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
	wait_picker(s, #manifest.references.Format)
	eq(sorted(s:lua(PICKER_ENTRIES, { root })), sorted(manifest.references.Format))
	eq(paths(manifest.references.Format), {
		"billing/invoice.go",
		"billing/invoice.go",
		"internal/money/money.go",
		"internal/money/money_test.go",
		"report/summary.go",
	})
end

T["lsp: Selecting a reference opens its file at the call site"] = function()
	local s = get()
	ensure_references(s)
	local call = reference_in("report/summary.go")
	E.burst(s, function()
		E.press(s, { "s", "u", "m", "m", "a", "r", "y" })
		wait_picker(s, 1)
		E.press(s, "return")
		S.wait_for(function()
			return s:lua("return vim.bo.filetype") ~= "TelescopePrompt"
		end, "Telescope picker closed")
	end)
	eq(s:lua(CURRENT_FILE), {
		path = vim.uv.fs_realpath(root .. "/" .. call.path),
		line = call.line,
		col = call.col,
	})
end

return T
