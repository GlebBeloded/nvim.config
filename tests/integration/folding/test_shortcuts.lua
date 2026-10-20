local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config({ env = F.go_env() })
	child.cmd("edit " .. vim.fn.fnameescape(vim.fn.tempname() .. ".lua"))
	child.wait_very_lazy()
	child.lua([[require("null-ls").disable({ name = "golangci_lint" })]])
	child.lua([[
		vim.wo.foldmethod = "manual"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, {
			"local first = {",
			"  value = 1,",
			"}",
			"local second = {",
			"  value = 2,",
			"}",
		})
		vim.cmd("1,3fold")
		vim.cmd("4,6fold")
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
	]])
end

---@param text string
---@return boolean
local function has_line(text)
	return child.lua_get(
		[[(function(text)
			return vim.iter(vim.api.nvim_buf_get_lines(0, 0, -1, false)):any(function(line)
				return line:find(text, 1, true) ~= nil
			end)
		end)(...)]],
		{ text }
	)
end

---@param text string
local function select_row(text)
	local found = child.lua_get(
		[[(function(text)
			for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
				if line:find(text, 1, true) then
					vim.api.nvim_win_set_cursor(0, { row, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ text }
	)
	assert(found, "Tree row not found: " .. text)
end

local T = H.child_set(child, start)

local function fold_state()
	return child.lua_get([[{ vim.fn.foldclosed(1), vim.fn.foldclosed(4) }]])
end

---@param lhs string
---@param desc string
local function expect_action_mapping(lhs, desc)
	eq(child.lua_get(([[vim.fn.maparg(%q, "n", false, true).desc]]):format(lhs)), desc)
end

local function open_billing_changes()
	local root = F.copy("billing", vim.fn.tempname() .. "/billing")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("enew")
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("changes.toggle"), "changes.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
	assert(
		child.wait(
			[[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view ~= nil and #view.rows > 0
		end)()]],
			3000
		),
		"Changes panel did not draw its initial rows"
	)
end

---@param text string
---@return boolean
local function select_changes_row(text)
	return child.lua_get(
		[[(function(text)
			for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
				if line:find(text, 1, true) then
					vim.api.nvim_win_set_cursor(0, { row, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ text }
	)
end

---@param text string
---@return boolean
local function changes_has(text)
	return child.lua_get(
		[[(function(text)
			return vim.iter(vim.api.nvim_buf_get_lines(0, 0, -1, false)):any(function(line)
				return line:find(text, 1, true) ~= nil
			end)
		end)(...)]],
		{ text }
	)
end

T["folding: Fold keys invoke registered actions"] = function()
	eq(fold_state(), { 1, 4 })

	expect_action_mapping("<M-=>", "Fold: Expand Fold")
	child.type_keys("<M-=>")
	eq(fold_state(), { -1, 4 })

	expect_action_mapping("<M-->", "Fold: Collapse Fold")
	child.type_keys("<M-->")
	eq(fold_state(), { 1, 4 })

	expect_action_mapping("<S-D-=>", "Fold: Expand All Folds")
	child.type_keys("<S-D-=>")
	eq(fold_state(), { -1, -1 })

	expect_action_mapping("<S-D-->", "Fold: Collapse All Folds")
	child.type_keys("<S-D-->")
	eq(fold_state(), { 1, 4 })
end

T["folding: Fold keys without a fold do nothing"] = function()
	child.cmd("normal! zE")
	local lines = child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]])
	local cursor = child.lua_get([[vim.api.nvim_win_get_cursor(0)]])

	for _, lhs in ipairs({ "<M-=>", "<M-->" }) do
		child.lua([[vim.v.errmsg = ""]])
		child.type_keys(lhs)

		eq(child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), lines)
		eq(child.lua_get([[vim.api.nvim_win_get_cursor(0)]]), cursor)
		eq(child.lua_get([[vim.v.errmsg]]), "")
	end
end

T["folding: Collapse Fold key folds the group under the tree cursor"] = function()
	open_billing_changes()
	assert(select_changes_row("web/src 1"), "Changes row not found: web/src 1")
	child.lua([[vim.v.errmsg = ""]])

	local close_ok = pcall(child.type_keys, "<M-->")
	local after_close = { changes_has("price.ts"), close_ok, child.lua_get([[vim.v.errmsg]]) }
	local open_ok = pcall(child.type_keys, "<M-=>")
	local after_open = { changes_has("price.ts"), open_ok, child.lua_get([[vim.v.errmsg]]) }

	eq({ after_close, after_open }, {
		{ false, true, "" },
		{ true, true, "" },
	})
end

T["folding: Expand Fold key unfolds a project tree folder"] = function()
	local root = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit README.md")
	child.type_keys("<M-e>")
	assert(child.wait([[vim.bo.filetype == "gleb-file-tree"]]), "Project tree did not open")
	assert(
		child.wait([[#require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()].rows > 0]]),
		"Project tree did not draw its initial rows"
	)
	select_row("internal")
	if has_line("\xee\x97\xbf billing") then
		child.type_keys("<CR>")
		select_row("internal")
	end

	child.type_keys("<M-=>")
	eq({ has_line("\xee\x97\xbf billing"), has_line("\xee\x97\xbf money") }, { true, true })

	child.type_keys("<M-->")
	eq({ has_line("\xee\x97\xbf billing"), has_line("\xee\x97\xbf money") }, { false, false })
	eq(child.lua_get([[vim.api.nvim_get_current_line():find("internal", 1, true) ~= nil]]), true)
end

T["folding: Collapse All Folds key folds every group of the Find Usages view"] = function()
	local root, manifest = F.copy("gomod", vim.fn.tempname())
	local declaration = manifest.references.Format[1]
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(declaration.path))
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], H.lsp_timeout(10000)), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], H.lsp_timeout(10000)), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], H.lsp_timeout(10000)), true)
	child.lua([[vim.v.errmsg = ""]])

	child.type_keys("<S-D-->")
	local folded = child.api.nvim_buf_get_lines(0, 0, -1, false)
	child.type_keys("<S-D-=>")
	local unfolded = child.api.nvim_buf_get_lines(0, 0, -1, false)

	eq({ #folded, folded[1]:find("Production  3", 1, true) ~= nil, folded[2]:find("Test  1", 1, true) ~= nil }, {
		2,
		true,
		true,
	})
	eq(#unfolded, 11)
	eq(child.lua_get([[vim.v.errmsg]]), "")
end

return T
