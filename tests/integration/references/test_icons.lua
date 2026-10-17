local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare({ "nvim-web-devicons" })
	child.lua([[
		Icons = require("gleb.references.icons")
		Icons.setup()
		Tree = require("gleb.references.tree").build({
			{ uri = "file:///repo/billing/invoice.go", path = "billing/invoice.go", lnum = 16, col = 11 },
			{
				uri = "file:///repo/internal/money/money_test.go",
				path = "internal/money/money_test.go",
				lnum = 6,
				col = 4,
			},
		}, { tests = "grouped", folders = true })
	]])
end

local T = H.child_set(child, start)

local function icon_for(kind, label)
	return child.lua_get(string.format(
		[[
		(function()
			for _, node in ipairs(Tree.nodes) do
				if node.kind == %q and node.label == %q then
					return Icons.for_node(node)
				end
			end
		end)()
	]],
		kind,
		label
	))
end

local function foreground(group)
	return child.lua_get(string.format([[vim.api.nvim_get_hl(0, { name = %q }).fg]], group))
end

T["references: Usage type icons and label shades match the palette"] = function()
	local actual = child.lua_get([[
(function()
	local root = vim.fn.tempname()
	vim.fn.mkdir(root, "p")
	for _, name in ipairs({ "a.go", "b.go", "c.go", "d.go", "e.go" }) do
		vim.fn.writefile({ "package fixture" }, vim.fs.joinpath(root, name))
	end
	local function usage(name, kind)
		local path = vim.fs.joinpath(root, name)
		return { uri = vim.uri_from_fname(path), path = path, lnum = 1, col = 1, kind = kind }
	end
	local usages = {
		usage("a.go", "field_declaration"),
		usage("b.go", "field_declaration"),
		usage("c.go", "receiver"),
		usage("d.go", "receiver"),
		usage("e.go", "struct_initialization"),
	}
	local state = require("gleb.references.state")
	state.save({ tests = "mixed", folders = false, usage_type = true })
	local view = require("gleb.references.view")
	view.open("Invoice", usages)
	local result = {}
	for row, line in ipairs(vim.api.nvim_buf_get_lines(view.state.tree_buf, 0, -1, false)) do
		for _, label in ipairs({ "Field declaration", "Receiver", "Struct initialization" }) do
			if line:find(label, 1, true) then
				local marks = vim.api.nvim_buf_get_extmarks(
					view.state.tree_buf,
					-1,
					{ row - 1, 0 },
					{ row - 1, -1 },
					{ details = true }
				)
				result[label] = vim.tbl_map(function(mark) return mark[4].hl_group end, marks)
			end
		end
	end
	return result
end)()
]])
	local expected = {
		["Field declaration"] = "FieldDeclaration",
		Receiver = "Receiver",
		["Struct initialization"] = "StructInitialization",
	}
	for label, suffix in pairs(expected) do
		local icon_group = "ReferencesUsageType" .. suffix
		local label_group = icon_group .. "Label"
		eq(actual[label] and vim.tbl_contains(actual[label], icon_group), true)
		eq(actual[label] and vim.tbl_contains(actual[label], label_group), true)
		local colour = label == "Struct initialization" and 0xD3869B or 0x89B482
		eq(foreground(icon_group), colour)
		eq(
			foreground(label_group),
			child.lua_get(
				string.format(
					[[tonumber(require("gleb.references.icons").label_color("#%06x", "#ddc7a1"):sub(2), 16)]],
					colour
				)
			)
		)
	end
end

T["references: Icons and label shades match the palette"] = function()
	local production = icon_for("scope", "Production")
	local test = icon_for("scope", "Test")
	local folder = icon_for("folder", "billing")
	local file = icon_for("usage", "invoice.go:16")

	eq(production, { icon = "", icon_group = "ReferencesProduction", label_group = "ReferencesProductionLabel" })
	eq(test, { icon = "", icon_group = "ReferencesTest", label_group = "ReferencesTestLabel" })
	eq(folder, { icon = "󰉖", icon_group = "ReferencesFolder", label_group = "ReferencesFolderLabel" })
	eq(file, { icon = "", icon_group = "DevIconGo", label_group = "ReferencesFileLabelDevIconGo" })

	eq(foreground(production.icon_group), 0x89B482)
	eq(foreground(production.label_group), 0xC3C197)
	eq(foreground(test.icon_group), 0xD8A657)
	eq(foreground(test.label_group), 0xDBBD8A)
	eq(foreground(folder.icon_group), 0x5A524C)
	eq(foreground(folder.label_group), 0xB5A387)
	eq(foreground(file.icon_group), 0x00ADD8)
	eq(foreground(file.label_group), 0x9ABFB1)

	child.lua([[
		vim.api.nvim_set_hl(0, "ReferencesProductionLabel", { fg = "#000000" })
		vim.api.nvim_exec_autocmds("ColorScheme", {})
	]])
	eq(foreground(production.label_group), 0xC3C197)

	child.lua([[
		vim.api.nvim_set_hl(0, "DevIconGo", { fg = "#000000" })
		Icons.setup()
	]])
	eq(foreground(file.label_group), 0x9A8B70)
end

return T
