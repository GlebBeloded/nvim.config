-- Approved project-operation prompts are exercised through the populated tree and real mappings.
local F = require("tests.fixtures")
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality
local root

local PROMPT_LEGEND = {
	a = "DevIconGo",
	b = "FileTreeFolderName",
	c = "FileTreeExpander",
	d = "FileTreeGitAdded",
	e = "MiniPickNormal",
	f = "MiniPickMatchCurrent",
	g = "@keyword",
	h = "PickerBorder",
	i = "PickerCategory",
}

local PROMPT_STYLES = {
	["0;38;2;0;173;216;48;2;40;40;40"] = "a",
	["0;38;2;125;174;163;48;2;40;40;40"] = "b",
	["0;38;2;146;131;116;48;2;40;40;40"] = "c",
	["0;38;2;169;182;101;48;2;40;40;40"] = "d",
	["0;38;2;212;190;152;48;2;40;40;40"] = ".",
	["0;38;2;221;199;161;48;2;40;40;40"] = "e",
	["0;38;2;221;199;161;48;2;50;48;47"] = "f",
	["0;38;2;234;105;98;48;2;40;40;40"] = "g",
	["0;38;2;69;64;61;48;2;40;40;40"] = "h",
	["0;38;2;90;82;76;48;2;40;40;40"] = "i",
	["0;38;2;90;82;76;48;2;50;48;47"] = "i",
}

local function artifact_lines()
	local path = vim.fs.joinpath(H.root, "openspec/changes/file-tree-ops/renders/g1_proposed.ansi")
	return vim.fn.readfile(path)
end

---@param line string
---@return string
local function plain_line(line)
	return (line:gsub("\27%[[0-9;]*m", ""))
end

---@param line string
---@return string
local function color_mask(line)
	local mask = {}
	local style = "."
	local index = 1
	while index <= #line do
		local first, last, code = line:find("\27%[([0-9;]*)m", index)
		local text = first and line:sub(index, first - 1) or line:sub(index)
		for _, character in ipairs(vim.fn.split(text, [[\zs]])) do
			for _ = 1, vim.fn.strdisplaywidth(character) do
				table.insert(mask, style)
			end
		end
		if not first then
			break
		end
		style = code == "0" and "." or assert(PROMPT_STYLES[code], "unmapped approved style: " .. code)
		index = last + 1
	end
	return table.concat(mask)
end

local function run_toggle()
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
end

---@param name string
local function open_row(name)
	local found = child.lua_get(
		[[(function(needle)
			for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
				if line:find(needle, 1, true) then
					vim.api.nvim_win_set_cursor(0, { row, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ name }
	)
	assert(found, "tree row not found: " .. name)
	child.type_keys("<CR>")
end

local function start()
	local home = vim.fn.tempname()
	root = F.copy("treeproj", vim.fs.joinpath(home, "work", "billing"))
	vim.fn.delete(vim.fs.joinpath(root, "bin"), "rf")
	vim.fn.delete(vim.fs.joinpath(root, "web", "node_modules"), "rf")
	vim.fn.delete(vim.fs.joinpath(root, ".env"))

	child.start_config()
	child.o.lines = 30
	child.o.columns = 100
	child.wait_very_lazy()
	child.lua(
		[[
		vim.env.HOME = ...
		vim.lsp.enable("gopls", false)
		require("null-ls").disable({})
		vim.diagnostic.enable(false)
	]],
		{ home }
	)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	assert(child.wait([[vim.b.gitsigns_head == "main"]], 5000), "gitsigns branch did not load")
	run_toggle()
	assert(child.wait([[
(function()
	local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
	return view and next(require("gleb.file_tree.git").status(view.root)) ~= nil
end)()
]], 5000), "git status did not load")
	open_row("cmd/server")
	open_row("web")
	open_row("src")
	child.lua([[vim.fn.search("invoice.go", "w")]])
	child.type_keys("a")
	assert(child.wait([[MiniPick.is_picker_active()]]), "add prompt did not open")
	child.type_keys("tax_rate.go")
	assert(child.wait([[table.concat(MiniPick.get_picker_query()) == "tax_rate.go"]]), "query was not rendered")
	child.cmd("redraw")
end

local T = H.child_set(child, start)

T["file-tree: Project tree add prompt matches the approved render"] = function()
	local artifact = artifact_lines()
	local expected = vim.tbl_map(plain_line, artifact)
	local actual = vim.tbl_map(table.concat, child.get_screenshot().text)
	eq(actual, expected)

	local groups = child.lua_get([[
(function()
	local state = MiniPick.get_picker_state()
	local marks = vim.api.nvim_buf_get_extmarks(state.buffers.main, -1, 0, -1, { details = true })
	return vim.iter(marks):fold({}, function(result, mark)
		local group = mark[4].hl_group
		if group then result[group] = true end
		return result
	end)
end)()
]])
	eq(groups.PickerCategory, true)

	local mask = {}
	for row = 11, 15 do
		table.insert(mask, color_mask(artifact[row]))
	end
	H.expect_screen_colors(child, 11, mask, PROMPT_LEGEND)
end

return T
