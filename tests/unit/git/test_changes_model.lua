local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality

local model = require("gleb.git.changes.model")
local settings = require("gleb.file_tree.settings")

local function status_record(xy, path, sub)
	return ("1 %s %s 100644 100644 100644 abcdef1 abcdef2 %s"):format(xy, sub or "N...", path)
end

local function records(items)
	return table.concat(items, "\0") .. "\0"
end

local function default_nesting_rules()
	settings.setup({ path = vim.fs.joinpath(H.root, "settings", "file_tree.json") })
	return settings.load().nesting.rules
end

local function summaries(rows)
	return vim.tbl_map(function(row)
		return { row.kind, row.label, row.depth, row.path, row.count }
	end, rows)
end

local function row_with_path(rows, path)
	for _, row in ipairs(rows) do
		if row.path == path then
			return row
		end
	end
end

local T = MiniTest.new_set()

T["git: Changes panel lists the dirty fixture"] = MiniTest.new_set()

T["git: Changes panel lists the dirty fixture"]["groups populated tracked and untracked records"] = function()
	local output = records({
		status_record("M.", "a.txt"),
		status_record(".M", "b.txt"),
		status_record(".M", "lib/c.lua"),
		status_record("MM", "d.txt"),
		"? new.txt",
	})

	eq(summaries(model.rows(output, default_nesting_rules())), {
		{ "root", "Changes", 0, nil, 4 },
		{ "directory", "lib", 1, "lib", 1 },
		{ "file", "c.lua", 2, "lib/c.lua", nil },
		{ "file", "a.txt", 1, "a.txt", nil },
		{ "file", "b.txt", 1, "b.txt", nil },
		{ "file", "d.txt", 1, "d.txt", nil },
		{ "root", "Unversioned Files", 0, nil, 1 },
		{ "file", "new.txt", 1, "new.txt", nil },
	})
end

T["git: Changes panel compacts single-child directories"] = MiniTest.new_set()

T["git: Changes panel compacts single-child directories"]["uses one row for the directory chain"] = function()
	local output = records({ status_record(".M", "internal/billing/invoice.go") })

	eq(summaries(model.rows(output, default_nesting_rules())), {
		{ "root", "Changes", 0, nil, 1 },
		{ "directory", "internal/billing", 1, "internal/billing", 1 },
		{ "file", "invoice.go", 2, "internal/billing/invoice.go", nil },
	})
end

T["git: Changes panel hides an empty Unversioned Files root"] = MiniTest.new_set()

T["git: Changes panel hides an empty Unversioned Files root"]["returns only the populated root"] = function()
	local output = records({ status_record(".M", "invoice.go") })

	eq(
		vim.tbl_map(function(row)
			return row.label
		end, model.rows(output, default_nesting_rules())),
		{ "Changes", "invoice.go" }
	)
end

T["git: Changes panel keeps one path in both roots"] = MiniTest.new_set()

T["git: Changes panel keeps one path in both roots"]["does not deduplicate records across roots"] = function()
	local output = records({ status_record(".M", "shared.txt"), "? shared.txt" })
	local rows = model.rows(output, default_nesting_rules())

	eq({ rows[2].root, rows[4].root }, { "changes", "unversioned" })
	eq({ rows[2].path, rows[4].path }, { "shared.txt", "shared.txt" })
end

T["git: Changes panel lists directory and submodule records"] = MiniTest.new_set()

T["git: Changes panel lists directory and submodule records"]["keeps both as non-diff leaves"] = function()
	local output = records({
		status_record(".M", "vendor/library", "S.M."),
		"? scratch/",
	})
	local rows = model.rows(output, default_nesting_rules())
	local submodule = row_with_path(rows, "vendor/library")
	local directory = row_with_path(rows, "scratch/")

	eq({ submodule.kind, submodule.path, submodule.submodule, submodule.diffable }, {
		"file",
		"vendor/library",
		true,
		false,
	})
	eq({ directory.kind, directory.path, directory.directory_record, directory.diffable }, {
		"file",
		"scratch/",
		true,
		false,
	})
end

T["git: Changes panel caps rows"] = MiniTest.new_set()

T["git: Changes panel caps rows"]["stops at the project tree row limit"] = function()
	local items = {}
	for index = 1, 5001 do
		items[index] = status_record(".M", ("file-%04d.txt"):format(index))
	end

	local rows, capped = model.rows(records(items), default_nesting_rules())

	eq(#rows, 5000)
	eq(capped, true)
end

T["git: Changes panel checkboxes follow the index"] = MiniTest.new_set()

T["git: Changes panel checkboxes follow the index"]["derives file and root states from porcelain columns"] = function()
	local output = records({
		status_record("M.", "a.txt"),
		status_record(".M", "b.txt"),
		status_record(".M", "lib/c.lua"),
		status_record("MM", "d.txt"),
		"? new.txt",
	})
	local rows = model.rows(output, default_nesting_rules())

	eq(row_with_path(rows, "a.txt").checkbox, "󰄲")
	eq(row_with_path(rows, "b.txt").checkbox, "󰄱")
	eq(row_with_path(rows, "lib/c.lua").checkbox, "󰄱")
	eq(row_with_path(rows, "d.txt").checkbox, "󰡖")
	eq(row_with_path(rows, "new.txt").checkbox, "󰄱")
	eq({ rows[1].kind, rows[1].checkbox }, { "root", "󰡖" })
	eq({ rows[7].kind, rows[7].checkbox }, { "root", "󰄱" })
end

T["git: Changes panel shows line stats"] = MiniTest.new_set()

T["git: Changes panel shows line stats"]["joins populated numstat records to tracked files"] = function()
	local output = records({
		status_record(".M", "internal/billing/invoice.go"),
		status_record(".M", "internal/billing/invoice_test.go"),
		status_record("A.", "internal/billing/tax.go"),
		status_record("A.", "internal/billing/tax_test.go"),
		status_record(".M", "web/src/price.ts"),
		"? notes.md",
	})
	local numstat = table.concat({
		"12\t3\tinternal/billing/invoice.go",
		"20\t1\tinternal/billing/invoice_test.go",
		"41\t0\tinternal/billing/tax.go",
		"33\t0\tinternal/billing/tax_test.go",
		"4\t4\tweb/src/price.ts",
	}, "\0") .. "\0"
	local rows = model.rows(output, default_nesting_rules(), numstat)

	eq({
		row_with_path(rows, "internal/billing/invoice.go").added,
		row_with_path(rows, "internal/billing/invoice.go").removed,
	}, { 12, 3 })
	eq({
		row_with_path(rows, "internal/billing/invoice_test.go").added,
		row_with_path(rows, "internal/billing/invoice_test.go").removed,
	}, { 20, 1 })
	eq(
		{ row_with_path(rows, "internal/billing/tax.go").added, row_with_path(rows, "internal/billing/tax.go").removed },
		{ 41, 0 }
	)
	eq({
		row_with_path(rows, "internal/billing/tax_test.go").added,
		row_with_path(rows, "internal/billing/tax_test.go").removed,
	}, { 33, 0 })
	eq({ row_with_path(rows, "web/src/price.ts").added, row_with_path(rows, "web/src/price.ts").removed }, { 4, 4 })
	eq(row_with_path(rows, "notes.md").added, nil)
end

T["git: Changes panel shows line stats"]["keys rename stats by destination and origin"] = function()
	local output = records({
		"2 R. N... 100644 100644 100644 abcdef1 abcdef2 R100 new.txt",
		"old.txt",
	})
	local numstat = "5\t2\t\0old.txt\0new.txt\0"
	local renamed = row_with_path(model.rows(output, default_nesting_rules(), numstat), "new.txt")

	eq({ renamed.orig, renamed.added, renamed.removed }, { "old.txt", 5, 2 })
end

T["git: Changes panel omits unmatched numstat"] = MiniTest.new_set()

T["git: Changes panel omits unmatched numstat"]["leaves missing and binary records without stats"] = function()
	local output = records({
		status_record(".M", "a.txt"),
		status_record(".M", "b.txt"),
		status_record(".M", "image.png"),
	})
	local rows = model.rows(output, default_nesting_rules(), "2\t1\ta.txt\0-\t-\timage.png\0")

	eq({ row_with_path(rows, "a.txt").added, row_with_path(rows, "a.txt").removed }, { 2, 1 })
	eq(row_with_path(rows, "b.txt").added, nil)
	eq(row_with_path(rows, "image.png").added, nil)
end

T["git: Changes panel on unborn HEAD has no stats"] = MiniTest.new_set()

T["git: Changes panel on unborn HEAD has no stats"]["accepts skipped numstat output"] = function()
	local rows = model.rows(records({ status_record("A.", "a.txt") }), default_nesting_rules(), nil)

	eq({ row_with_path(rows, "a.txt").added, row_with_path(rows, "a.txt").removed }, { nil, nil })
end

return T
