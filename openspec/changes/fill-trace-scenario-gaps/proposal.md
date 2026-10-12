## Why
`make trace` (run 2026-10-12) reports `175 scenarios, 105 tested, 70 missing, 0 orphan`: 70 spec scenarios have no mini.test case named `<capability>: <scenario title>`, so their behaviour is unguarded and `make check` cannot catch a regression there.

Kind: bug

## What Changes
- Add one mini.test case per missing scenario, named exactly `<capability>: <scenario title>`, in the layer `docs/testing.md` prescribes (unit with stubs where the module runs alone, integration for the real config, screen for visual-only). The list from `make trace VERBOSE=1`:
- `ai` (7 missing of 15):
  - Menu ignores other keys
  - Menu s opens search prompt
  - Menu shows prompt
  - Menu v opens vibe prompt
  - Shift-Enter opens vibe prompt
  - Visual Alt-9 opens visual prompt
  - Visual Shift-Enter opens visual prompt
- `file-tree` (23 missing of 38):
  - Current file is followed
  - Deleted file is not previewed
  - Diff tab is reused across files
  - Directory argument opens tree in current window
  - Dotfiles and gitignored files are listed
  - Enter opens file and switches to filesystem tree (in a requirement modified by `fix-diff-preview-stale-tab`)
  - Focus guard pulls focus back during navigation (in a requirement modified by `fix-diff-preview-stale-tab`)
  - Git status tree opens on the left at width 35
  - Next source switches tree source
  - P pushes successfully (in a requirement modified by `fix-neotree-commit-check`)
  - P reports push failure (in a requirement modified by `fix-neotree-commit-check`)
  - Rapid calls are debounced
  - Space stages an unstaged file (in a requirement modified by `fix-diff-preview-stale-tab`)
  - Space unstages a staged file (in a requirement modified by `fix-diff-preview-stale-tab`)
  - Tree closes with last window
  - a creates a file
  - c commits confirmed message (in a requirement modified by `fix-neotree-commit-check`)
  - j skips directories and previews next file
  - k skips directories and previews previous file
  - q closes preview and tree (in a requirement modified by `fix-diff-preview-stale-tab`)
  - r renames a file
  - t opens file in new tab
  - v opens file in vertical split
- `git` (24 missing of 24):
  - Added line shows bar sign
  - Blame is off by default
  - Differ opens panel on the left
  - Diffview file panel on the left
  - Enter confirms message (in a requirement modified by `fix-neotree-commit-check`)
  - Enter on empty buffer does nothing (in a requirement modified by `fix-neotree-commit-check`)
  - Generated message fills popup (in a requirement modified by `fix-neotree-commit-check`)
  - Git commands are available after startup
  - Gitlink copies current line URL
  - Gitlink copies range URL
  - Leaving popup closes it (in a requirement modified by `fix-neotree-commit-check`)
  - Long diff is truncated
  - Missing optional git plugins are tolerated
  - No staged changes
  - Ollama failure is shown (in a requirement modified by `fix-neotree-commit-check`)
  - Ollama is spawned with staged diff
  - Popup resizes to content (in a requirement modified by `fix-neotree-commit-check`)
  - dx drops both conflict sides
  - pgw.dev remote uses GitHub URL format
  - q closes diffview from file panel
  - q discards popup (in a requirement modified by `fix-neotree-commit-check`)
  - s stages entry from file panel
  - tab moves to next entry
  - vscode-diff setup runs on plugin load
- `keymaps` (7 missing of 36):
  - Alt-F opens live grep
  - Alt-G closes focused git status tree
  - Alt-G switches tree to git status
  - Alt-e closes focused filesystem tree
  - Alt-e on URI buffer focuses filesystem
  - Alt-e reveals current file
  - Alt-g opens Differ
- `session` (4 missing of 15):
  - bare nvim restores a cwd session after pane id change (in a requirement modified by `fix-session-fallback-match`)
  - bare nvim restores the pane session (in a requirement modified by `fix-session-fallback-match`)
  - nvim with a file argument does not restore (in a requirement modified by `fix-session-fallback-match`)
  - quitting saves the session (in a requirement modified by `fix-session-save-guards`)
- `statusline` (5 missing of 26):
  - copilot glyph hidden when healthy
  - copilot glyph shown on warning
  - copilot glyph shown when disabled
  - diff hidden in narrow windows
  - navic breadcrumb shown when available
- Scenarios marked "in a requirement modified by `<change>`" are covered by whichever lands first: if that change is archived before this one, test the modified scenario; otherwise test the current text, and that change updates the test.
- The Copilot scenarios "copilot glyph shown when disabled" and "copilot glyph shown on warning" assert `""` today because the glyph is empty; test them as written, `fix-empty-nerd-font-glyphs` changes them.
- Diff-preview scenarios that need a working codediff view (e.g. "Diff tab is reused across files") are marked `H.xfail` like the existing ones until `fix-diff-preview-codediff-crash` lands; they are never deleted or weakened.
- Git scenarios that spawn external tools (`git push`, ollama) stub `vim.system` / `vim.fn.jobstart` in the child and assert the spawned command and the notification.
- When every scenario is tested, make `missing` fatal in `tests/trace.lua` (it is "reported, not fatal yet").

## Capabilities
### Modified Capabilities
- None (`skip_specs: true`: tests for existing scenarios; no spec text changes).

## Impact
- Code: new test files under `tests/unit/<cap>/`, `tests/integration/<cap>/`, `tests/screen/<cap>/`; `tests/trace.lua` (make missing fatal at the end); helpers in `tests/helpers.lua` if needed. No change to `lua/`.
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: fixing bugs the new tests expose (each becomes its own change or uses `H.xfail` naming its queued change), new scenarios, and the `shortcuts` and `nvim-debug-log` capabilities (fully traced).
