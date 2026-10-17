local MiniTest = require("mini.test")
local F = require("tests.fixtures")

local eq = MiniTest.expect.equality

local model = require("gleb.file_tree.model")
local fs = require("gleb.file_tree.fs")

local function fixture_rows()
	local root = F.copy("treeproj", vim.fn.tempname())
	return model.rows(fs.tree(root), {}, {})
end

local function entry_summaries(rows)
	local summaries = {}
	for index = 2, #rows do
		summaries[#summaries + 1] = { rows[index].kind, rows[index].label }
	end
	return summaries
end

local T = MiniTest.new_set()

T["file-tree: Project tree lists folders first in case-insensitive order"] = MiniTest.new_set()

T["file-tree: Project tree lists folders first in case-insensitive order"]["orders a populated fixture"] = function()
	eq(entry_summaries(fixture_rows()), {
		{ "directory", ".github" },
		{ "directory", "bin" },
		{ "directory", "cmd" },
		{ "directory", "internal" },
		{ "directory", "web" },
		{ "file", ".env" },
		{ "file", ".gitignore" },
		{ "file", "go.mod" },
		{ "file", "go.sum" },
		{ "file", "Makefile" },
		{ "file", "notes.md" },
		{ "file", "README.md" },
	})
end

T["file-tree: Project tree lists folders first in case-insensitive order"]["uses the raw name to break folded ties"] = function()
	local entries = {
		{ name = "alpha", kind = "file", path = "/project/alpha" },
		{ name = "Alpha", kind = "file", path = "/project/Alpha" },
		{ name = "zeta", kind = "directory", path = "/project/zeta" },
	}

	model.sort(entries)

	eq(
		vim.tbl_map(function(entry)
			return entry.name
		end, entries),
		{ "zeta", "Alpha", "alpha" }
	)
end

T["file-tree: Project tree hides the git folder"] = MiniTest.new_set()

T["file-tree: Project tree hides the git folder"]["filters it from a populated fixture"] = function()
	local rows = fixture_rows()
	for _, row in ipairs(rows) do
		eq(row.label == ".git", false)
	end
end

return T
