# Design

## Context

See proposal.md - Why. Root cause, confirmed against the pinned plugin source:

- `lua/gleb/file_tree/diff_preview.lua` builds a `SessionConfig` with `original_path` / `modified_path`
  strings and passes it to `require("codediff.ui.view").create`.
- The pinned vscode-diff.nvim declares `SessionConfig.original` / `.modified` as `Path` refs
  (`{ relative, absolute }`); `ui/view/helpers.lua` `prepare_buffer` indexes `ref.relative`, so the
  missing field is `nil` and the scheduled callback errors before a tab is kept and before
  `Neotree git_status` runs.
- The plugin's own `:CodeDiff` command (`codediff/commands.lua`) builds the refs with
  `require("codediff.core.path").make_ref(relative_path, git_root)`.

The callers in `lua/gleb/file_tree/init.lua` (git_status navigation) are unaffected: they only call
`diff_preview.open_diff(node.path)`.

## Goals / Non-Goals

**Goals:**
- `open_diff` produces the same session shape the plugin's own command does, so the diff tab and the
  neo-tree git_status window appear as the existing file-tree scenarios describe.
- The `---@type SessionConfig` annotation type-checks without suppression.

**Non-Goals:**
- No change to tab bookkeeping, debounce or focus guard (fix-diff-preview-stale-tab owns those).
- No reference screenshot: the file-tree spec has no screen scenario for the diff tab and this change
  adds no spec delta; the renders below document the visible effect only.

## Decisions

- **Use `codediff.core.path.make_ref` for both sides** with the repo-relative path and `git_root`.
  Alternatives: build `{ relative, absolute }` tables by hand (duplicates plugin path normalisation,
  breaks if `Path` gains fields); call `:CodeDiff file HEAD` instead of the internal API (changes the
  tab/neo-tree flow the module relies on and is a larger behaviour change). `make_ref` is the
  plugin's public constructor for this type and keeps the fix to two fields.
- **Pass the repo-relative path** (already computed via `git.get_relative_path`) so `ref.relative`
  is correct for the `codediff://` HEAD buffer and `ref.absolute` resolves to the working file.

## Visible behaviour

**Current**: `100x12`, excerpt: top rows + cmdline, Normal mode, neo-tree git_status focused, `j` on
`diff_preview.lua` (modified); one tab page, error after the debounce

```text
 Git                         │
  ▾ ■ lua/gleb/file_tree      │~
    ~ ◆ diff_preview.lua█      │~
  ▾ ■ tests/integration/fil… │~
    ~ ◆ test_diff_preview.lua│~
                             │~
                             │~
                             │~
                             │~
─────────────────────────────┴──────────────────────────────────────────────────────────────────────
Error executing vim.schedule lua callback: ...codediff/ui/view/helpers.lua:34: attempt to index loca
l 'ref' (a nil value)
```

**Proposed**: `100x12`, excerpt: top rows, Normal mode, current tab page is the new diff tab (tab 2);
neo-tree git_status focused on `diff_preview.lua`, HEAD on the left, working tree on the right

```text
 Git                         │ 59                                 │ 59
  ▾ ■ lua/gleb/file_tree      │ 60     ---@type SessionConfig      │ 60     ---@type SessionConfig
    ~ ◆ diff_preview.lua█      │ 61     local session_config = {    │ 61     local session_config = {
  ▾ ■ tests/integration/fil… │ 62       mode = "standalone",      │ 62       mode = "standalone",
    ~ ◆ test_diff_preview.lua│ 63       git_root = git_root,      │ 63       git_root = git_root,
                             │ 64 -     original_path = relative_…│ 64 +     original = path.make_ref(…
                             │ 65 -     modified_path = relative_…│ 65 +     modified = path.make_ref(…
                             │ 66       original_revision = comm… │ 66       original_revision = comm…
                             │ 67       modified_revision = "WORK…│ 67       modified_revision = "WORK…
─────────────────────────────┴────────────────────────────────────┴─────────────────────────────────
```

Only Proposed exists as an option: the fix restores the intended view, it does not redesign it.

## Risks / Trade-offs

- [`codediff.core.path` is an internal module of the pinned plugin] → It is the same constructor the
  plugin's command uses; the integration tests "Diff tab is created" and "Neo-tree is opened and
  focused in diff tab" fail loudly if a future pin changes it.
- [Other `SessionConfig` fields may have drifted too] → The un-xfailed tests exercise the full
  `view.create` path; the LuaCATS check (`make check`) flags remaining field mismatches against the
  plugin's `---@class SessionConfig`.
