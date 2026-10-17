local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality

local function patch_module()
	local ok, patch = pcall(require, "gleb.diff.patch")
	eq(ok, true, { fail_reason = "gleb.diff.patch should load" })
	return patch
end

local function change(start1, end1, start2, end2)
	return { start1 = start1, end1 = end1, start2 = start2, end2 = end2 }
end

local T = MiniTest.new_set()

T["diff: Diff patch states of a change, an insertion and a deletion"] = MiniTest.new_set()

T["diff: Diff patch states of a change, an insertion and a deletion"]["modified lines have unchecked and checked states"] = function()
	local patch = patch_module()
	local head = { "first", "old", "last" }
	local right = { "first", "new", "last" }
	local current = change(1, 2, 1, 2)

	eq(patch.state(head, head, right, current), "󰄱")
	eq(patch.state(head, right, right, current), "󰄲")
end

T["diff: Diff patch states of a change, an insertion and a deletion"]["insertions and deletions have unchecked and checked states"] = function()
	local patch = patch_module()
	local inserted = { "first", "added", "last" }
	local insertion = change(1, 1, 1, 2)
	local deleted_head = { "first", "removed", "last" }
	local deleted = { "first", "last" }
	local deletion = change(1, 2, 1, 1)

	eq(patch.state({ "first", "last" }, { "first", "last" }, inserted, insertion), "󰄱")
	eq(patch.state({ "first", "last" }, inserted, inserted, insertion), "󰄲")
	eq(patch.state(deleted_head, deleted_head, deleted, deletion), "󰄱")
	eq(patch.state(deleted_head, deleted, deleted, deletion), "󰄲")
end

T["diff: Diff patch state of a partly staged change"] = MiniTest.new_set()

T["diff: Diff patch state of a partly staged change"]["a different index edit is mixed"] = function()
	local patch = patch_module()
	local head = { "first", "old", "last" }
	local index = { "first", "other", "last" }
	local right = { "first", "new", "last" }

	eq(patch.state(head, index, right, change(1, 2, 1, 2)), "󰡖")
end

T["diff: Diff patch state of a partly staged change"]["an overlapping staged edit is mixed"] = function()
	local patch = patch_module()
	local head = { "first", "old one", "old two", "last" }
	local index = { "first", "staged one", "staged two", "last" }
	local right = { "first", "new one", "old two", "last" }

	eq(patch.state(head, index, right, change(1, 2, 1, 2)), "󰡖")
end

T["diff: Diff patch stages one change"] = MiniTest.new_set()

T["diff: Diff patch stages one change"]["a changed line stages and unstages"] = function()
	local patch = patch_module()
	local head = { "first", "old", "last" }
	local right = { "first", "new", "last" }
	local current = change(1, 2, 1, 2)

	eq(patch.update_index(head, head, right, current, true), right)
	eq(patch.update_index(head, right, right, current, false), head)
end

T["diff: Diff patch stages one change"]["an earlier staged insertion stays in the index"] = function()
	local patch = patch_module()
	local head = { "first", "old", "last" }
	local index = { "staged before", "first", "old", "last" }
	local right = { "first", "new", "last" }
	local current = change(1, 2, 1, 2)

	eq(patch.update_index(head, index, right, current, true), { "staged before", "first", "new", "last" })
end

T["diff: Diff patch stages one change"]["overlapping staged edits return to HEAD"] = function()
	local patch = patch_module()
	local head = { "first", "old one", "old two", "last" }
	local index = { "first", "staged one", "staged two", "last" }
	local right = { "first", "new one", "old two", "last" }
	local current = change(1, 2, 1, 2)

	eq(patch.update_index(head, index, right, current, true), right)
	eq(patch.update_index(head, index, right, current, false), head)
end

T["diff: Diff patch stages one change"]["a patch preserves a missing final newline"] = function()
	local patch = patch_module()
	local repo = H.git_repo({ ["file.txt"] = "old" })
	local text = patch.make_patch("file.txt", { "old" }, { "new" }, false, false)
	local result = vim.system(
		{ "git", "apply", "--cached", "--check", "--whitespace=nowarn", "-" },
		{ cwd = repo, stdin = text, text = true }
	):wait()

	eq(result.code, 0, { fail_reason = result.stderr })
	eq(vim.tbl_count(vim.fn.split(text, "\\ No newline at end of file", true)), 3)
end

T["diff: Diff patch stages an insertion and a deletion"] = MiniTest.new_set()

T["diff: Diff patch stages an insertion and a deletion"]["an insertion stages and unstages"] = function()
	local patch = patch_module()
	local head = { "first", "last" }
	local right = { "first", "added", "last" }
	local current = change(1, 1, 1, 2)

	eq(patch.update_index(head, head, right, current, true), right)
	eq(patch.update_index(head, right, right, current, false), head)
end

T["diff: Diff patch stages an insertion and a deletion"]["a deletion stages and unstages"] = function()
	local patch = patch_module()
	local head = { "first", "removed", "last" }
	local right = { "first", "last" }
	local current = change(1, 2, 1, 1)

	eq(patch.update_index(head, head, right, current, true), right)
	eq(patch.update_index(head, right, right, current, false), head)
end

return T
