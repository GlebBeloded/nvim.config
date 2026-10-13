# Design

## Context

See proposal.md (Why). Root cause, three independent defects:
- `get_text()` in `git/ai_commit.lua` treats every non-blank buffer as a message, so the placeholders the module itself writes (`# No staged changes`, `# Error: ...`) pass the `text ~= ""` guard in the `<CR>` map.
- `call_ai`'s `on_exit` calls neither `callback` nor `on_error` when the cleaned response is empty, so nothing retitles the popup.
- `git_commit` in `file_tree/init.lua` ignores the `vim.fn.system` result and always notifies `Committed:`; it also builds a shell string, against convention 6.4.

The popup is the only visible surface; the renders below show the empty-output case at 80x24 (`80% of columns` = 64).

## Goals / Non-Goals

**Goals:**
- A placeholder can never reach `git commit`; a failed commit is never reported as success.
- Every Ollama exit leaves the popup titled ` Commit Message `.

**Non-Goals:**
- Changing the popup layout, keys, footer or the generating state.
- Making `<CR>` show feedback when it refuses (it stays a no-op, as for an empty buffer).

## Decisions

### Comment lines are dropped in `get_text()`
`get_text()` filters lines matching `^#` before trimming, so `<CR>` and `on_commit` see the same text. This matches git's own `commentChar` handling in a `gitcommit` buffer and also covers comments the user types.
Alternative: a `placeholder` flag set wherever the module writes `# ...` and cleared on edit. Rejected: needs a `TextChanged` hook and still lets user comments into the commit.

### Empty output goes through `on_error`
In `on_exit`, an empty cleaned response calls `on_error("Ollama returned an empty message")`. The existing error path already prefixes `# Error: `, retitles and resizes, so no new UI code.
Alternative: a third callback. Rejected: identical behaviour to the error path.

### `git_commit` uses async `vim.system`
`vim.system({ "git", "commit", "-m", msg }, { text = true }, on_commit_exit)`; `on_commit_exit` is a named function that `vim.schedule`s: exit 0 refreshes `git_status` and notifies `Committed: <subject>`; otherwise notifies `Commit failed: <msg>` at ERROR, where `<msg>` is trimmed stderr, falling back to trimmed stdout (git prints "nothing to commit" on stdout) and then to `exit <code>`.
Alternative: `vim.system(...):wait()`. Rejected: a slow `pre-commit` hook would freeze the UI; `P` is already async.

## Renders

Current, excerpt: popup rows 10-14 of 80x24, normal mode, `c` in `git_status` with staged changes, Ollama exited 0 with empty output (title never updates):

```text
         ╭───────────────────── LL Generating... ─────────────────────╮
         │█                                                           │
         │                                                            │
         │                                                            │
         ╰────────────────── <CR> ✓ │ i edit │ q ✗ ───────────────────╯
```

Proposed, excerpt: popup row 12-14 of 80x24, same state, popup resized to width 64 and height 1, cursor on `#`:

```text
       ╭──────────────────────── Commit Message ────────────────────────╮
       │█ Error: Ollama returned an empty message                       │
       ╰──────────────────── <CR> ✓ │ i edit │ q ✗ ─────────────────────╯
```

Colors are unchanged ([Normal] body, [FloatBorder] border, title and footer).

## Testing approach

- `git` scenarios: new `tests/integration/git/test_ai_commit.lua`. The child gets a temp repo with a staged change as cwd and a fake `ollama` script prepended to `PATH` (prints a fixture, or nothing, then exits with a given code), so `jobstart` runs unmodified.
- `file-tree` scenarios: `tests/integration/file-tree/test_tree.lua`. The child stubs `require("gleb.git.ai_commit").show_commit_input` to call `on_commit("feat: x")` directly; the failure case adds a `.git/hooks/pre-commit` that exits 1, then waits for the notification.

## Risks / Trade-offs

- [A real subject starting with `#` (e.g. `#123 fix`) is dropped] → the prompt asks for `<type>(<scope>): ...`, and git itself strips such lines in the editor flow.
- [Async commit: `c` can be confirmed again before the first commit finishes] → the second `git commit` fails on the index lock and is now reported as `Commit failed:`.
