## Why

Kind: bug

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

- Make Find Action multi-word matching also match the category followed by the title as one searchable value, so
  `project open` selects `file_tree.open`. Single-word matching and the case's assertions stay as they are.

## Impact

- tests/helpers.lua and the Find Action palette's matcher.
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
