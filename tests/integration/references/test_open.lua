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
end

local T = H.child_set(child, start)

---@param path string
---@param line integer
---@param col integer
local function edit(path, line, col)
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(path))
	child.api.nvim_win_set_cursor(0, { line, col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
end

local function view_windows()
	return child.lua_get([[
vim.tbl_filter(function(win)
	return vim.bo[vim.api.nvim_win_get_buf(win)].filetype:match("^gleb%-references") ~= nil
end, vim.api.nvim_list_wins())
]])
end

local function open_format()
	local declaration = manifest.references.Format[1]
	edit(declaration.path, declaration.line, declaration.col)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
end

T["references: gr opens the view in a Go module"] = function()
	open_format()

	local title = child.lua_get("vim.api.nvim_win_get_config(0).title[1][1]")
	eq(title, " Usages of Format · 4 ")
	eq(#view_windows(), 3)
end

T["references: gr with no usages notifies and opens nothing"] = function()
	local due = { path = "billing/invoice.go", line = 11, col = 18 }
	edit(due.path, due.line, due.col)
	local notifications = H.record_notify(child)
	local before = #child.api.nvim_list_wins()

	child.type_keys("gr")
	eq(child.wait([[#Notifications > 0]], TIMEOUT_MS), true)

	eq(notifications(), { { msg = "No usages found", level = vim.log.levels.INFO } })
	eq(#child.api.nvim_list_wins(), before)
end

T["references: gr without a references-capable client notifies"] = function()
	child.cmd("enew")
	local notifications = H.record_notify(child)
	local before = #child.api.nvim_list_wins()

	child.type_keys("gr")
	eq(child.wait([[#Notifications > 0]], TIMEOUT_MS), true)

	eq(notifications(), { { msg = "No LSP references support", level = vim.log.levels.INFO } })
	eq(#child.api.nvim_list_wins(), before)
end

T["references: gr continues when one client refuses the request"] = function()
	local declaration = manifest.references.Format[1]
	edit(declaration.path, declaration.line, declaration.col)
	child.lua([[
		local function server()
			return {
				request = function(method, _, callback)
					callback(nil, method == "initialize" and { capabilities = { referencesProvider = true } } or {})
					return true, 1
				end,
				notify = function() return true end,
				is_closing = function() return false end,
				terminate = function() end,
			}
		end
		vim.lsp.start({ name = "refusing-references", cmd = server, root_dir = vim.fn.getcwd() })
		vim.wait(1000, function()
			return #vim.lsp.get_clients({ bufnr = 0, name = "refusing-references" }) == 1
		end)
		vim.lsp.get_clients({ bufnr = 0, name = "refusing-references" })[1].request = function()
			return false
		end
	]])

	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)

	local title = child.lua_get("vim.api.nvim_win_get_config(0).title[1][1]")
	eq(title, " Usages of Format · 4 ")
end

T["references: The first usage is selected and previewed"] = function()
	open_format()

	eq(child.fn.getline("."), "       invoice.go:16")
	local preview = child.lua_get([[
(function()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "gleb-references-preview" then
			return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		end
	end
end)()
]])
	eq(preview[16], "\treturn money.Format(total)")
	eq(child.lua_get([[vim.api.nvim_win_get_cursor(require("gleb.references.view").state.preview_win)]]), { 16, 0 })
end

T["references: View reflows when the editor resizes"] = function()
	child.o.lines, child.o.columns = 30, 100
	open_format()
	eq(child.lua_get([[vim.api.nvim_win_get_width(require("gleb.references.view").state.tree_win)]]), 42)

	child.o.columns = 140
	child.cmd("doautocmd VimResized")
	eq(child.lua_get([[vim.api.nvim_win_get_width(require("gleb.references.view").state.tree_win)]]), 60)
	eq(child.lua_get([[vim.api.nvim_win_get_config(require("gleb.references.view").state.tree_win).col]]), 2)

	child.o.columns = 70
	child.cmd("doautocmd VimResized")
	eq(child.lua_get([[require("gleb.references.view").state.preview_win == nil]]), true)
	eq(child.lua_get([[vim.api.nvim_win_get_config(require("gleb.references.view").state.tree_win).col]]), 18)
end

return T
