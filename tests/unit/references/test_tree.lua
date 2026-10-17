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
	local actual = build([[{ tests = "grouped", folders = true }]])

	eq(actual.count, 4)
	eq(actual.nodes, {
		{ id = "scope:production", kind = "scope", label = "Production", count = 3, depth = 0 },
		{
			id = "folder:production:billing",
			kind = "folder",
			label = "billing",
			count = 2,
			depth = 1,
			parent_id = "scope:production",
		},
		{
			id = "usage:file:///repo/billing/invoice.go:16:11",
			kind = "usage",
			label = "invoice.go:16",
			depth = 2,
			parent_id = "folder:production:billing",
			uri = "file:///repo/billing/invoice.go",
			path = "billing/invoice.go",
			lnum = 16,
			col = 11,
			test = false,
		},
		{
			id = "usage:file:///repo/billing/invoice.go:23:11",
			kind = "usage",
			label = "invoice.go:23",
			depth = 2,
			parent_id = "folder:production:billing",
			uri = "file:///repo/billing/invoice.go",
			path = "billing/invoice.go",
			lnum = 23,
			col = 11,
			test = false,
		},
		{
			id = "folder:production:report",
			kind = "folder",
			label = "report",
			count = 1,
			depth = 1,
			parent_id = "scope:production",
		},
		{
			id = "usage:file:///repo/report/summary.go:7:8",
			kind = "usage",
			label = "summary.go:7",
			depth = 2,
			parent_id = "folder:production:report",
			uri = "file:///repo/report/summary.go",
			path = "report/summary.go",
			lnum = 7,
			col = 8,
			test = false,
		},
		{ id = "scope:test", kind = "scope", label = "Test", count = 1, depth = 0 },
		{
			id = "folder:test:internal/money",
			kind = "folder",
			label = "internal/money",
			count = 1,
			depth = 1,
			parent_id = "scope:test",
		},
		{
			id = "usage:file:///repo/internal/money/money_test.go:6:4",
			kind = "usage",
			label = "money_test.go:6",
			depth = 2,
			parent_id = "folder:test:internal/money",
			uri = "file:///repo/internal/money/money_test.go",
			path = "internal/money/money_test.go",
			lnum = 6,
			col = 4,
			test = true,
		},
	})
	eq(actual.selected_id, "usage:file:///repo/billing/invoice.go:16:11")

	local hidden = build([[{ tests = "hidden", folders = true }]])
	eq(hidden.count, 3)
	eq(
		vim.tbl_map(function(node)
			return node.label
		end, hidden.nodes),
		{ "Production", "billing", "invoice.go:16", "invoice.go:23", "report", "summary.go:7" }
	)

	local mixed = build([[{ tests = "mixed", folders = true }]])
	eq(mixed.count, 4)
	eq(
		vim.tbl_map(function(node)
			return { node.kind, node.label, node.test_tag }
		end, mixed.nodes),
		{
			{ "folder", "billing" },
			{ "usage", "invoice.go:16", false },
			{ "usage", "invoice.go:23", false },
			{ "folder", "internal/money" },
			{ "usage", "money_test.go:6", true },
			{ "folder", "report" },
			{ "usage", "summary.go:7", false },
		}
	)

	local folderless = build([[{ tests = "mixed", folders = false }]])
	eq(
		vim.tbl_map(function(node)
			return { node.label, node.depth, node.test_tag }
		end, folderless.nodes),
		{
			{ "billing/invoice.go:16", 0, false },
			{ "billing/invoice.go:23", 0, false },
			{ "internal/money/money_test.go:6", 0, true },
			{ "report/summary.go:7", 0, false },
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
	eq(flat.nodes[4].label, "report/summary.go:7")
end

local kinds_scenario = "references: Function usages have no read/write level or hint"
T[kinds_scenario] = MiniTest.new_set()

T[kinds_scenario]["omits the level when every usage is other"] = function()
	child.lua([[
		for _, usage in ipairs(UsageFixture) do usage.kind = "other" end
	]])

	local actual = build([[{ tests = "grouped", folders = true, read_write = true }]])
	eq(
		vim.tbl_filter(function(node)
			return node.kind == "kind"
		end, actual.nodes),
		{}
	)
end

T[kinds_scenario]["groups kinds or adds row tags according to the toggle"] = function()
	child.lua([[
		UsageFixture[1].kind = "other"
		UsageFixture[2].kind = "read"
		UsageFixture[3].kind = "write"
		UsageFixture[4].kind = "write"
	]])

	local grouped = build([[{ tests = "mixed", folders = false, read_write = true }]])
	eq(
		vim.tbl_map(function(node)
			return { node.kind, node.label, node.count, node.depth, node.usage_kind }
		end, grouped.nodes),
		{
			{ "kind", "Value write", 2, 0, "write" },
			{ "usage", "billing/invoice.go:16", nil, 1, "write" },
			{ "usage", "billing/invoice.go:23", nil, 1, "write" },
			{ "kind", "Value read", 1, 0, "read" },
			{ "usage", "internal/money/money_test.go:6", nil, 1, "read" },
			{ "kind", "Usage", 1, 0, "other" },
			{ "usage", "report/summary.go:7", nil, 1, "other" },
		}
	)

	local tagged = build([[{ tests = "mixed", folders = false, read_write = false }]])
	eq(
		vim.tbl_map(function(node)
			return { node.label, node.kind_tag }
		end, tagged.nodes),
		{
			{ "billing/invoice.go:16", "write" },
			{ "billing/invoice.go:23", "write" },
			{ "internal/money/money_test.go:6", "read" },
			{ "report/summary.go:7" },
		}
	)
end

return T
