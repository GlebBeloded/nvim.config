## Why

Kind: bug
Adopt: loop/fix-child-wait-nil

`child.wait` in `tests/helpers.lua` returns true at once when the awaited expression is nil: mini.test's
`child.lua_get` returns `vim.NIL` for a Lua nil, and `vim.NIL and true or false` is `true`. Every wait whose
expression yields nil while not ready (`row and row.action and …`, `vim.g.flag`) passes without waiting.

With the fix applied, one case that passed vacuously fails: `file-tree: Project tree keys come from the keymap file`
(`tests/integration/file-tree/test_project_tree.lua:774`, "Project Open action did not match").

## Evidence

Probe in a bare child: `child.lua_get("vim.g.never_set")` is userdata equal to `vim.NIL`, and
`child.wait("vim.g.never_set", 200)` returns true.

Probe of the failing case 1.5 s after `child.type_keys("project open")` in the Find Action picker:
`MiniPick.get_picker_matches()` has no `current_ind`, and the palette still lists all 66 rows unfiltered
(`recently used`, `find_action.open`, `other actions`, `view.soft_wrap`, …): the typed query does not reach or
filter the picker, so `file_tree.open` is never the current match.

Full `make check` with only the helper fix (loop round104, 2026-10-18): that is the only product case that fails.

## What Changes

- `tests/helpers.lua` `child.wait`: treat nil, `vim.NIL` and false as not ready:

```lua
	--- Waits until `expr` is truthy in the child. nil comes back over RPC as vim.NIL (truthy here), so it counts as false.
	function child.wait(expr, timeout)
		local ok = vim.wait(timeout or 2000, function()
			local value = child.lua_get(expr)
			return value ~= nil and value ~= vim.NIL and value ~= false
		end, 20)
		return ok
	end
```

- Find why the typed query does not select `file_tree.open` in that case (the test's keys, the picker's input
  handling, or the palette's matching) and fix the cause. The case's assertions stay as they are.

## Impact

- tests/helpers.lua; the Find Action palette or the case's input path, whichever the probe shows.
- `file-tree: Project tree keys come from the keymap file` still holds, now with a real wait.
- `file-tree: Requirement: Project tree open and close keys` still holds because the wait fix changes only test
  readiness handling, not any project-tree open or close action.
- `file-tree: Requirement: File tree nest actions` still holds because the wait fix changes only test readiness
  handling, not any nest action.
- Every case using `child.wait` keeps passing with the real wait; a case that newly fails is fixed at its cause,
  never by loosening the wait or the assertion.

## Decision (auditor, 2026-10-18, review pass 1)

- A multi-word Find Action query also matches an action's category and title together (`project open` finds
  `Project: Open`): the palette shows rows as `<Category>: <Title>` and the existing case already types that query.
  Single-word matching is unchanged.
- This is a find-action behaviour change: add a `find-action` spec delta (MODIFIED requirement of the matching rule at
  `openspec/specs/find-action/spec.md:43`, restated in full, with a scenario for the multi-word query) and set
  `skip_specs: false`. Cover it with a unit case on the matcher (multi-word hit, a word order that should still
  match or not per the requirement, single-word unchanged) named after that scenario.
- (pass 4) This Decision supersedes review pass 1's `[must-fix]` on `lua/gleb/find_action/items.lua`: keep the multi-word
  category+title matching from 71f79eae with its find-action delta and unit cases (5d819b20 removed them; restore them).
  `file-tree: Project tree keys come from the keymap file` types `project open` as before; replacing it with `open`
  plus `<C-n><C-n>` changes the case's input and is a weakened test.

## Rejected run
Run on `loop/fix-child-wait-nil` was rejected by the judge:
- blocked: tasks.md: ## Blocked

- Should combined `Category Title` matching become a Find Action requirement? Option 1: add that requirement with its own scenario and regression test so `project open` selects `file_tree.open`. Option 2: keep title, category, and aliases as separate fields and choose another product-level way to make `file_tree.open` current. Recommend option 1 because no query matching only `file_tree.open`'s title (`Open`), category (`Project`), or absent aliases can exclude the earlier `Open ...` actions.
- test added then removed during build: find-action: Multi-word query spans category and title
- note: loop: FAIL in tests/unit/loop/test_judge_renames.lua | loop: Judge notes a scenario removal a rename does not cover:
