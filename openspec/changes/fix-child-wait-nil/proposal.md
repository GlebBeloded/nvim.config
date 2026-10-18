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
