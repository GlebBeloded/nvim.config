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
