local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		UsageFixture = {
			{ uri = "file:///repo/report/summary.go", path = "report/summary.go", lnum = 7, col = 8 },
			{ uri = "file:///repo/internal/money/money_test.go", path = "internal/money/money_test.go", lnum = 6, col = 4 },
			{ uri = "file:///repo/billing/invoice.go", path = "billing/invoice.go", lnum = 23, col = 11 },
			{ uri = "file:///repo/billing/invoice.go", path = "billing/invoice.go", lnum = 16, col = 11 },
		}
	]])
end

local T = H.child_set(child, start)

local function build(options, selected)
	return child.lua_get(string.format(
		[[(function()
			local tree = require("gleb.references.tree")
			return tree.build(UsageFixture, %s, %s)
		end)()]],
		options,
		selected or "nil"
	))
end

T["references: Go usages are grouped by scope and folder"] = function()
	child.lua([[for _, usage in ipairs(UsageFixture) do usage.kind = "call" end]])
	local actual = build([[{ tests = "grouped", folders = true, usage_type = true }]])

	eq(actual.count, 4)
	eq(actual.nodes, {
		{ id = "scope:production", kind = "scope", label = "Production", count = 3, depth = 0 },
		{
			id = "type:production:call",
			kind = "type",
			label = "Call",
			count = 3,
			depth = 1,
			parent_id = "scope:production",
			usage_type = "call",
		},
		{
			id = "folder:production:call:billing",
			kind = "folder",
			label = "billing",
			count = 2,
			depth = 2,
			parent_id = "type:production:call",
		},
		{
			id = "usage:file:///repo/billing/invoice.go:16:11",
			kind = "usage",
			label = "invoice.go:16",
			depth = 3,
			parent_id = "folder:production:call:billing",
			uri = "file:///repo/billing/invoice.go",
			path = "billing/invoice.go",
			lnum = 16,
			col = 11,
			test = false,
			usage_type = "call",
		},
		{
			id = "usage:file:///repo/billing/invoice.go:23:11",
			kind = "usage",
			label = "invoice.go:23",
			depth = 3,
			parent_id = "folder:production:call:billing",
			uri = "file:///repo/billing/invoice.go",
			path = "billing/invoice.go",
			lnum = 23,
			col = 11,
			test = false,
			usage_type = "call",
		},
		{
			id = "folder:production:call:report",
			kind = "folder",
			label = "report",
			count = 1,
			depth = 2,
			parent_id = "type:production:call",
		},
		{
			id = "usage:file:///repo/report/summary.go:7:8",
			kind = "usage",
			label = "summary.go:7",
			depth = 3,
			parent_id = "folder:production:call:report",
			uri = "file:///repo/report/summary.go",
			path = "report/summary.go",
			lnum = 7,
			col = 8,
			test = false,
			usage_type = "call",
		},
		{ id = "scope:test", kind = "scope", label = "Test", count = 1, depth = 0 },
		{
			id = "type:test:call",
			kind = "type",
			label = "Call",
			count = 1,
			depth = 1,
			parent_id = "scope:test",
			usage_type = "call",
		},
		{
			id = "folder:test:call:internal/money",
			kind = "folder",
			label = "internal/money",
			count = 1,
			depth = 2,
			parent_id = "type:test:call",
		},
		{
			id = "usage:file:///repo/internal/money/money_test.go:6:4",
			kind = "usage",
			label = "money_test.go:6",
			depth = 3,
			parent_id = "folder:test:call:internal/money",
			uri = "file:///repo/internal/money/money_test.go",
			path = "internal/money/money_test.go",
			lnum = 6,
			col = 4,
			test = true,
			usage_type = "call",
		},
	})
	eq(actual.selected_id, "usage:file:///repo/billing/invoice.go:16:11")

	local hidden = build([[{ tests = "hidden", folders = true, usage_type = true }]])
	eq(hidden.count, 3)
	eq(
		vim.tbl_map(function(node)
			return node.label
		end, hidden.nodes),
		{ "Production", "Call", "billing", "invoice.go:16", "invoice.go:23", "report", "summary.go:7" }
	)

	local mixed = build([[{ tests = "mixed", folders = true, usage_type = true }]])
	eq(mixed.count, 4)
	eq(
		vim.tbl_map(function(node)
			return { node.kind, node.label, node.test_tag }
		end, mixed.nodes),
		{
			{ "type", "Call" },
			{ "folder", "billing" },
			{ "usage", "invoice.go:16", false },
			{ "usage", "invoice.go:23", false },
			{ "folder", "internal/money" },
			{ "usage", "money_test.go:6", true },
			{ "folder", "report" },
			{ "usage", "summary.go:7", false },
		}
	)

	local folderless = build([[{ tests = "mixed", folders = false, usage_type = true }]])
	eq(
		vim.tbl_map(function(node)
			return { node.label, node.depth, node.test_tag }
		end, folderless.nodes),
		{
			{ "Call", 0 },
			{ "billing/invoice.go:16", 1, false },
			{ "billing/invoice.go:23", 1, false },
			{ "internal/money/money_test.go:6", 1, true },
			{ "report/summary.go:7", 1, false },
		}
	)
end

T["references: Nested folders become one row"] = function()
	child.lua([[
		UsageFixture = {
			{
				uri = "file:///repo/internal/provisioner/postgres/provision.go",
				path = "internal/provisioner/postgres/provision.go",
				lnum = 9,
				col = 2,
			},
			{
				uri = "file:///repo/internal/provisioner/postgres/deprovision.go",
				path = "internal/provisioner/postgres/deprovision.go",
				lnum = 4,
				col = 2,
			},
		}
	]])

	local actual = build([[{ tests = "grouped", folders = true }]])
	eq(
		vim.tbl_map(function(node)
			return node.label
		end, actual.nodes),
		{
			"Production",
			"internal/provisioner/postgres",
			"deprovision.go:4",
			"provision.go:9",
		}
	)
	eq(actual.nodes[2].count, 2)
end

T["references: Regrouping keeps the selected usage"] = function()
	local selected = [[{ uri = "file:///repo/report/summary.go", lnum = 7, col = 8 }]]
	local grouped = build([[{ tests = "grouped", folders = true }]], selected)
	local flat = build([[{ tests = "grouped", folders = false }]], selected)

	eq(grouped.selected_id, "usage:file:///repo/report/summary.go:7:8")
	eq(flat.selected_id, grouped.selected_id)
end

T["references: Unclassified usages add no level"] = function()
	child.lua([[
		for _, usage in ipairs(UsageFixture) do usage.kind = "unclassified" end
	]])

	local actual = build([[{ tests = "grouped", folders = true, usage_type = true }]])
	eq(
		vim.tbl_filter(function(node)
			return node.kind == "type"
		end, actual.nodes),
		{}
	)
	eq(actual.has_types, false)
end

local types_scenario = "references: Usage type groups sort by label"
T[types_scenario] = MiniTest.new_set()

T[types_scenario]["orders catalogue labels"] = function()
	child.lua([[
		UsageFixture = {
			{ uri = "file:///repo/a.go", path = "a.go", lnum = 1, col = 1, kind = "write" },
			{ uri = "file:///repo/b.go", path = "b.go", lnum = 1, col = 1, kind = "read" },
			{ uri = "file:///repo/c.go", path = "c.go", lnum = 1, col = 1, kind = "unclassified" },
			{ uri = "file:///repo/d.go", path = "d.go", lnum = 1, col = 1, kind = "call" },
			{ uri = "file:///repo/e.go", path = "e.go", lnum = 1, col = 1, kind = "struct_initialization" },
			{ uri = "file:///repo/f.go", path = "f.go", lnum = 1, col = 1, kind = "field_declaration" },
		}
	]])

	local grouped = build([[{ tests = "mixed", folders = false, usage_type = true }]])
	eq(
		vim.tbl_map(
			function(node)
				return node.label
			end,
			vim.tbl_filter(function(node)
				return node.kind == "type"
			end, grouped.nodes)
		),
		{
			"Call",
			"Field declaration",
			"Struct initialization",
			"Unclassified",
			"Value read",
			"Value write",
		}
	)
	eq(grouped.has_types, true)
end

T[types_scenario]["adds catalogue tags when the level is off"] = function()
	child.lua([[
		UsageFixture[1].kind = "unclassified"
		UsageFixture[2].kind = "read"
		UsageFixture[3].kind = "struct_initialization"
		UsageFixture[4].kind = "field_declaration"
	]])
	local tagged = build([[{ tests = "mixed", folders = false, usage_type = false }]])
	eq(
		vim.tbl_map(function(node)
			return { node.label, node.type_tag }
		end, tagged.nodes),
		{
			{ "billing/invoice.go:16", "field_declaration" },
			{ "billing/invoice.go:23", "struct_initialization" },
			{ "internal/money/money_test.go:6", "read" },
			{ "report/summary.go:7" },
		}
	)
end

return T
