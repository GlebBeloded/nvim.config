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

return T
