local MiniTest = require("mini.test")
local F = require("tests.fixtures")

local eq = MiniTest.expect.equality

local model = require("gleb.file_tree.model")
local fs = require("gleb.file_tree.fs")

---@param status? table<string, string>
---@return FileTreeRowOptions
local function options(status)
	return { status = status or {}, ignored = {}, ignored_generation = 0, show_ignored = false }
end

local function fixture_rows()
	local root = F.copy("treeproj", vim.fn.tempname())
	return model.rows(fs.tree(root), {}, options())
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
		{ "directory", ".github/workflows" },
		{ "directory", "bin" },
		{ "directory", "cmd/server" },
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

T["file-tree: Single-child folders share one row"] = MiniTest.new_set()

T["file-tree: Single-child folders share one row"]["compacts populated fixture folders"] = function()
	local labels = vim.tbl_map(function(row)
		return row.label
	end, fixture_rows())

	eq(vim.tbl_contains(labels, ".github/workflows"), true)
	eq(vim.tbl_contains(labels, "cmd/server"), true)
	eq(vim.tbl_contains(labels, ".github"), false)
	eq(vim.tbl_contains(labels, "cmd"), false)
end

T["file-tree: Expanding a compact row shows the last folder's entries"] = MiniTest.new_set()

T["file-tree: Expanding a compact row shows the last folder's entries"]["expands the chain tail"] = function()
	local root = F.copy("treeproj", vim.fn.tempname())
	local rows = model.rows(fs.tree(root), { ["cmd/server"] = true }, options())
	local compact_index
	for index, row in ipairs(rows) do
		if row.label == "cmd/server" then
			compact_index = index
			break
		end
	end

	eq(compact_index ~= nil, true)
	eq(rows[compact_index].expanded, true)
	eq({ rows[compact_index + 1].label, rows[compact_index + 1].depth }, { "main.go", 1 })
end

T["file-tree: Project tree hides the git folder"] = MiniTest.new_set()

T["file-tree: Project tree hides the git folder"]["filters it from a populated fixture"] = function()
	local rows = fixture_rows()
	for _, row in ipairs(rows) do
		eq(row.label == ".git", false)
	end
end

T["file-tree: Project tree colours changed files"] = MiniTest.new_set()

T["file-tree: Project tree colours changed files"]["parses tracked and untracked paths"] = function()
	local output = table.concat({
		"1 .M N... 100644 100644 100644 abcdef1 abcdef1 internal/invoice.go",
		"1 A. N... 000000 100644 100644 0000000 abcdef2 internal/tax.go",
		"1 .D N... 100644 100644 000000 abcdef3 abcdef3 old.go",
		"? notes.md",
		"! build/",
	}, "\0") .. "\0"

	local status, ignored = model.parse_status(output, "")
	eq(status, {
		["internal/invoice.go"] = "modified",
		["internal/tax.go"] = "added",
		["old.go"] = "deleted",
		["notes.md"] = "untracked",
	})
	eq(ignored, { ["build/"] = true })
end

T["file-tree: Project tree colours changed files"]["parses rename and unmerged records"] = function()
	local output = table.concat({
		"2 R. N... 100644 100644 100644 abcdef1 abcdef1 R100 new name.md",
		"old name.md",
		"u UU N... 100644 100644 100644 100644 abcdef1 abcdef2 abcdef3 go.mod",
	}, "\0") .. "\0"

	eq(model.parse_status(output, ""), {
		["new name.md"] = "renamed",
		["go.mod"] = "conflict",
	})
end

T["file-tree: Project tree colours changed files"]["keeps only paths below a repository prefix"] = function()
	local output = "1 .M N... 100644 100644 100644 abcdef1 abcdef1 apps/web/src/app.ts\0"

	eq(model.parse_status(output, "apps/web"), { ["src/app.ts"] = "modified" })
end

T["file-tree: Project tree colours changed files"]["uses documented folder precedence"] = function()
	local status = {
		["internal/new.go"] = "added",
		["internal/changed.go"] = "modified",
		["internal/conflict.go"] = "conflict",
		["web/renamed.ts"] = "renamed",
		["scratch/"] = "untracked",
	}

	eq(model.folder_status(status, "internal"), "conflict")
	eq(model.folder_status(status, "web"), "modified")
	eq(model.folder_status(status, "scratch"), "untracked")
	eq(model.folder_status(status, "clean"), nil)
end

T["file-tree: Project tree colours changed files"]["marks files below an untracked folder"] = function()
	local tree = {
		root = "/project",
		scan = function(path)
			if path == "/project" then
				return { { name = "scratch", path = "/project/scratch", kind = "directory" } }
			end
			return { { name = "todo.txt", path = "/project/scratch/todo.txt", kind = "file" } }
		end,
	}
	local rows = model.rows(tree, { scratch = true }, options({ ["scratch/"] = "untracked" }))

	eq({ rows[2].status, rows[3].status }, { "untracked", "untracked" })
end

T["file-tree: Shared parser preserves rename and copy origins"] = MiniTest.new_set()

T["file-tree: Shared parser preserves rename and copy origins"]["consumes each original-path field"] = function()
	local output = table.concat({
		"2 R. N... 100644 100644 100644 abcdef1 abcdef2 R100 new name.md",
		"old name.md",
		"2 C. S.M. 100644 100644 100644 abcdef3 abcdef4 C75 copy.md",
		"source.md",
	}, "\0") .. "\0"

	eq(model.parse_status_records(output), {
		{ kind = "2", xy = "R.", sub = "N...", path = "new name.md", orig = "old name.md" },
		{ kind = "2", xy = "C.", sub = "S.M.", path = "copy.md", orig = "source.md" },
	})
end

T["file-tree: Shared parser classifies added and unmerged records"] = MiniTest.new_set()

T["file-tree: Shared parser classifies added and unmerged records"]["maps worktree additions and conflicts"] = function()
	local output = table.concat({
		"1 .A N... 000000 000000 100644 0000000 1234567 added.lua",
		"u UU N... 100644 100644 100644 100644 abcdef1 abcdef2 abcdef3 conflicted.lua",
	}, "\0") .. "\0"

	local status, ignored = model.parse_status(output, "")
	eq(status, { ["added.lua"] = "added", ["conflicted.lua"] = "conflict" })
	eq(ignored, {})
end

T["file-tree: Shared parser keeps ignored records separate"] = MiniTest.new_set()

T["file-tree: Shared parser keeps ignored records separate"]["keeps ignored paths out of status"] = function()
	local output = table.concat({
		"1 .M N... 100644 100644 100644 abcdef1 abcdef2 tracked.lua",
		"? notes.md",
		"! build/",
	}, "\0") .. "\0"

	local status, ignored = model.parse_status(output, "")
	eq(status, { ["tracked.lua"] = "modified", ["notes.md"] = "untracked" })
	eq(ignored, { ["build/"] = true })
end

return T
