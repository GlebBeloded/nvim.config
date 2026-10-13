# Fix Keymaps Visual Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Visual-mode editing helpers unchanged while restoring Neovim's built-in behavior for typed characters in Select mode.

**Architecture:** Use Neovim's built-in map-mode scoping: define every Visual helper once with mode `x`, which excludes Select mode, instead of pairing `v` maps with `sunmap`. Pin both the mapping table and the user-visible Select-mode behavior in the existing full-config integration suite; no new module or plugin is needed.

**Tech Stack:** Lua, Neovim built-in `vim.keymap.set`, mini.test full-config child Neovim, OpenSpec.

**Spec:** `openspec/changes/fix-keymaps-visual-modes/specs/keymaps/spec.md` (with the approval decision in `openspec/changes/fix-keymaps-visual-modes/proposal.md`)

## Global Constraints

- Enter Select mode in the behavior scenario with `v`, then `<C-g>`, then `p`; do not remap mini.diff's normal-mode `gh`.
- Assert the Select-mode result exactly as `{ { "foo", "par baz" }, "i" }`; replacement of the unnamed register by built-in Select-mode typing is out of scope.
- Map `<`, `>`, `p`, `<A-j>`, `<A-k>`, and `<C-CR>` once in mode `x`; do not add matching `sunmap` calls.
- Preserve every existing Visual-mode right-hand side and the normal-mode `<C-CR>` callback; remove only the duplicate `v` mappings, including the Select-only `:m .+1<CR>==` and `:m .-2<CR>==` variants.
- Add, remove, or upgrade no plugin dependency. Keep `tests/shortcuts/stack.lua` identical to `auto`, including `query_focused_pane()` plus `retry_cli`.
- Do not include the separate `desc` and `<Cmd>` cleanup queued as `cleanup-keymaps`.

## Review Focus

- Any of the six helper keys still resolves in Select mode: pinned by `keymaps: Visual helpers are not mapped in select mode` in Task 1, Steps 1 and 6.
- Printable `p` invokes a mapping or leaves the editor outside Insert mode: pinned by `keymaps: Typing p in select mode inserts p` in Task 1, Steps 1 and 6.
- Changing `p` to `x` breaks register-preserving Visual paste: pinned by `keymaps: Paste over selection keeps register` in Task 1, Step 7.
- Deduplicating the move and indent maps changes their direction, reindent, or reselection behavior: pinned by the six Visual editing regression scenarios in Task 1, Step 7.
- Removing the duplicate code-action map also removes normal or Visual code actions: pinned by `keymaps: LSP mappings bound to vim.lsp.buf` and `keymaps: Code action in visual mode` in Task 1, Step 7.

---

### Task 1: Scope editing helpers to Visual mode

Scenarios: `keymaps: Visual helpers are not mapped in select mode`, `keymaps: Typing p in select mode inserts p`.

Regression scenarios: `keymaps: Indent keeps selection`, `keymaps: Outdent keeps selection`, `keymaps: Paste over selection keeps register`, `keymaps: Move selected lines down`, `keymaps: Move selected lines up`, `keymaps: Alt-j moves selected lines down`, `keymaps: Alt-k moves selected lines up`, `keymaps: LSP mappings bound to vim.lsp.buf`, `keymaps: Code action in visual mode`.

**Files:**
- Modify: `tests/integration/keymaps/test_keymaps.lua:292`
- Modify: `lua/gleb/keymaps.lua:37-50,95-98`
- Modify: `openspec/specs/keymaps/spec.md:100-129,168-177`
- Preserve unchanged: `tests/shortcuts/stack.lua`

**Interfaces:**
- Consumes: the existing `T` mini.test set, full-config `child`, `set_lines(lines: string[])`, and `get_lines(): string[]` in `tests/integration/keymaps/test_keymaps.lua`.
- Produces: no new Lua API; the global mappings for `<`, `>`, `p`, `J`, `K`, `<A-j>`, `<A-k>`, and visual `<C-CR>` are each defined only in mode `x`.

- [x] **Step 1: Write the failing mini.test cases**

Add both cases after the existing Visual helper cases in `tests/integration/keymaps/test_keymaps.lua`; their names must remain exact for traceability.

```lua
T["keymaps: Visual helpers are not mapped in select mode"] = function()
	local lhs = { "<", ">", "p", "<A-j>", "<A-k>", "<C-CR>" }
	local select_maps = vim.tbl_map(function(key)
		return child.fn.maparg(key, "s")
	end, lhs)

	eq(select_maps, { "", "", "", "", "", "" })
end

T["keymaps: Typing p in select mode inserts p"] = function()
	-- Yank because clipboard=unnamedplus makes direct setreg setup misleading.
	set_lines({ "foo", "bar baz" })
	child.type_keys("gg", "yiw", "j", "0", "v", "<C-g>", "p")

	eq({ get_lines(), child.fn.mode() }, { { "foo", "par baz" }, "i" })
end
```

- [x] **Step 2: Run each new case and verify the expected failures**

Run:

```bash
make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="keymaps: Visual helpers are not mapped in select mode"
make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="keymaps: Typing p in select mode inserts p"
```

Expected: the first case fails because the existing `v` maps appear in mode `s`; the second fails with the mapped-paste result (`fooar baz` in Normal mode), not with test setup or startup errors.

- [x] **Step 3: Sync the approved requirements into the main keymaps spec**

In `openspec/specs/keymaps/spec.md`, replace the two affected requirement texts with the change delta, add the two new scenarios verbatim, and retain every existing scenario. The Visual helper requirement must say the helpers are mapped once in `x` only; the LSP requirement must say `<C-CR>` is normal plus Visual `x` only.

- [x] **Step 4: Implement the minimal mode-scope change**

In `lua/gleb/keymaps.lua`, change the `<`, `>`, and `p` maps from `v` to `x`; delete the `v` `<A-j>` and `<A-k>` maps so their existing `x` maps are the sole definitions; delete only the `v` `<C-CR>` map while retaining its normal and `x` maps. Keep all surviving right-hand sides byte-for-byte unchanged.

- [x] **Step 5: Verify both new cases pass**

Run the two commands from Step 2 again.

Expected: PASS for both exact scenario names.

- [x] **Step 6: Verify the Select-mode assertions together**

Run: `make test FILE=tests/integration/keymaps/test_keymaps.lua CASE="select mode"`

Expected: both new cases PASS; all six `maparg(lhs, "s")` results are empty, and typing `p` yields lines `{ "foo", "par baz" }` in mode `i`.

- [x] **Step 7: Run the complete keymaps integration file**

Run: `make test FILE=tests/integration/keymaps/test_keymaps.lua`

Expected: every case passes, including all nine regression scenarios listed above.

- [x] **Step 8: Verify traceability, focused checks, and stack preservation**

Run:

```bash
VERBOSE=1 make trace
make quick
git diff --exit-code auto -- tests/shortcuts/stack.lua
```

Expected: both new scenarios are `tested` with no orphan, the focused gate is green, and the stack harness has no diff from `auto`.

- [x] **Step 9: Full merge gate handoff — deferred to the invoking user's next workflow gate**

Not run here by explicit controlling ruling. The invoking user's next workflow gate will run `make check E2E=1` once.

- [x] **Step 10: Commit the implementation**

```bash
git add lua/gleb/keymaps.lua tests/integration/keymaps/test_keymaps.lua openspec/specs/keymaps/spec.md
git commit -m "fix(keymaps): keep visual maps out of select mode"
```

## Workflow Follow-up

After implementation review and verification, archive `fix-keymaps-visual-modes`; confirm the archived delta keeps the approved `v`, `<C-g>`, `p` scenario in the synced `keymaps` spec.
