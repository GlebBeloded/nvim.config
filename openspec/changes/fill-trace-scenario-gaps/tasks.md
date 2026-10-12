# Tasks

Every task follows the same steps:
1. Write the failing case(s), each named exactly `<capability>: <scenario title>`, asserting the scenario's THEN as written; run `make test FILE=<file> CASE="<title>"` and see it red.
2. Make it green without touching `lua/`: add only the harness support the task names. A case that stays red because `lua/` does not do what the spec says is wrapped in `H.xfail("<change id>: …")` naming a queued change (write a new `fix-*` proposal if none exists); never weaken it. A case that reaches codediff's `open_diff` uses the existing `CODEDIFF_CRASH` reason.
3. Verify: `make test CAPS=<cap>` green (xfails allowed), `make trace VERBOSE=1` shows the titles `tested`, `make quick` green.

(M:<change>) marks a scenario in a requirement modified by a queued change: test the text in `openspec/specs/` unless that change is archived by then, in which case test its modified text (design D5). Reuse built-ins and the harness: `child.wait`, `H.screen_rows`, `child.type_keys`; no new test dependencies.

## 1. Harness helpers

- [x] 1.1 Temp git repo (design D2). Scenarios: Git commands are available after startup (first user of the helper).
  1. Failing case `git: Git commands are available after startup` in `tests/integration/git/test_git.lua` that calls `H.git_repo({ ["a.txt"] = "a\n" })` and `cd`s the child into it.
  2. Add `H.git_repo(files, opts)` to `tests/helpers.lua` (temp dir, `git init -b main`, local `user.name`/`user.email`, commit `files`, optional `opts.remote` as `origin`; LuaCATS-typed, small named functions).
  3. Verify the case and `make lint types`.
- [x] 1.2 Restart with kept state (design D3). Scenarios: quitting saves the session (M:fix-session-save-guards).
  1. Failing case `session: quitting saves the session` in `tests/integration/session/test_session.lua`: start, edit a file, `:qall`, assert the session file exists on the host.
  2. Add `child.restart_config(args, opts)` to `tests/helpers.lua`: reuses the previous start's `XDG_DATA_HOME`/`XDG_STATE_HOME` (skips `fresh_state()`), extra args and env (zellij pane id); document it in the `---@field` list.
  3. Verify the case and `make lint types`.

## 2. ai (integration, `tests/integration/ai/test_prompt_keys.lua`)

`refactor-ai-99-config` may later move these to unit; until then the menu lives in the lazy spec and needs the real config.

- [ ] 2.1 Scenarios: Menu shows prompt, Menu s opens search prompt, Menu v opens vibe prompt, Menu ignores other keys.
  1. Failing cases: press the menu key with `child.type_keys`, read the message row with `H.screen_rows(child, -1)`; assert the 99 prompt buffer for `s`/`v`, nothing for another key.
  2. No harness change expected (plugin loaded after `child.wait_very_lazy()`).
  3. Verify (ai).
- [ ] 2.2 Scenarios: Shift-Enter opens vibe prompt, Visual Alt-9 opens visual prompt, Visual Shift-Enter opens visual prompt.
  1. Failing cases: normal-mode `<S-CR>`, visual `<M-9>` and `<S-CR>` over a selection; assert the prompt buffer opens with the selection as context.
  2. No harness change expected.
  3. Verify (ai 15/15).

## 3. git

- [ ] 3.1 Scenarios: Missing optional git plugins are tolerated (unit `tests/unit/git/test_modules.lua`, bare child without the plugins), vscode-diff setup runs on plugin load (integration `test_git.lua`).
  1. Failing cases: require the git modules in a bare child and assert no error; load vscode-diff and assert its setup ran (its command exists).
  2. No harness change expected.
  3. Verify (git).
- [ ] 3.2 Scenarios: Added line shows bar sign, Blame is off by default (integration, temp repo).
  1. Failing cases: add a line to a committed file, `child.wait` for the gitsigns sign and assert its text; assert no blame virtual text after the 300 ms the spec names.
  2. None.
  3. Verify (git).
- [ ] 3.3 Scenarios: Differ opens panel on the left, Diffview file panel on the left, tab moves to next entry, s stages entry from file panel, q closes diffview from file panel, dx drops both conflict sides (integration, temp repo; a merge conflict built with `H.git_repo` plus a host-side branch merge for `dx`).
  1. Failing cases asserting window layout, cursor entry, `git diff --cached --name-only` on the host, closed tab, and conflict markers gone.
  2. If building the conflict is not one-line, add `opts.conflict` to `H.git_repo` (small named function).
  3. Verify (git).
- [ ] 3.4 Scenarios: Gitlink copies current line URL, Gitlink copies range URL, pgw.dev remote uses GitHub URL format (integration, temp repo with `opts.remote`).
  1. Failing cases: run the Gitlink mapping in normal and visual mode; assert the `+` register (in-memory clipboard) URL with `#L<n>` / `#L<a>-L<b>`.
  2. None.
  3. Verify (git).
- [ ] 3.5 Scenarios: No staged changes, Ollama is spawned with staged diff, Long diff is truncated (unit `tests/unit/git/test_ai_commit.lua`, bare child in a temp repo).
  1. Failing cases: call `gleb.git.ai_commit` with nothing staged (assert the notification), with a staged file and with a staged diff over the limit; assert the recorded `ollama run` command and stdin.
  2. Add the `jobstart`/`chansend` and `vim.notify` recorders as named local functions in the file (design D4); move them to `tests/helpers.lua` only when 4.4 reuses them.
  3. Verify (git).
- [ ] 3.6 Scenarios: Generated message fills popup (M:fix-neotree-commit-check), Popup resizes to content (M), Ollama failure is shown (M).
  1. Failing cases: scripted `on_stdout`/`on_exit`; assert popup buffer lines, window height, and the error shown.
  2. None.
  3. Verify (git).
- [ ] 3.7 Scenarios: Enter confirms message (M), Enter on empty buffer does nothing (M), q discards popup (M), Leaving popup closes it (M).
  1. Failing cases: assert the confirm callback receives the message (or is not called), popup closed on `q` and on `WinLeave`.
  2. None.
  3. Verify (git 24/24).

## 4. file-tree (integration)

- [ ] 4.1 `test_tree.lua`. Scenarios: Tree closes with last window, Directory argument opens tree in current window, Current file is followed, Dotfiles and gitignored files are listed, Git status tree opens on the left at width 35, Next source switches tree source.
  1. Failing cases; the directory argument uses `child.restart_config({ dir })` from 1.2, gitignored files a temp repo with `.gitignore`.
  2. None.
  3. Verify (file-tree).
- [ ] 4.2 `test_tree.lua` (temp dir). Scenarios: a creates a file, r renames a file, t opens file in new tab, v opens file in vertical split.
  1. Failing cases driving neo-tree input prompts with `child.type_keys`; assert the file on disk / tab and window layout.
  2. None.
  3. Verify (file-tree).
- [ ] 4.3 `test_tree.lua` (temp repo). Scenarios: Space stages an unstaged file (M:fix-diff-preview-stale-tab), Space unstages a staged file (M).
  1. Failing cases asserting `git diff --cached --name-only` on the host.
  2. None. (`fix-neotree-stage-toggle` adds its own scenarios; not covered here.)
  3. Verify (file-tree).
- [ ] 4.4 `test_tree.lua` (temp repo). Scenarios: c commits confirmed message (M:fix-neotree-commit-check), P pushes successfully (M), P reports push failure (M).
  1. Failing cases: `c` with the ollama `jobstart` stubbed, confirm, assert `git log -1 --format=%s`; `P` with `git push` stubbed to exit 0 / 1, assert the command and the notification. If `fix-git-status-map-shadowing` has moved `c` by then, use its key and title.
  2. Move the 3.5 recorders to `tests/helpers.lua` (`H.record_jobstart`, `H.record_notify`, typed).
  3. Verify (file-tree).
- [ ] 4.5 `test_diff_preview.lua`. Scenarios: j skips directories and previews next file, k skips directories and previews previous file, Deleted file is not previewed, Rapid calls are debounced.
  1. Failing cases in a temp repo (D2, not this checkout); assert the previewed path / no preview / one open after rapid calls.
  2. `CODEDIFF_CRASH` xfail only where the assertion needs the diff view.
  3. Verify (file-tree).
- [ ] 4.6 `test_diff_preview.lua`. Scenarios: Diff tab is reused across files, Focus guard pulls focus back during navigation (M:fix-diff-preview-stale-tab), Enter opens file and switches to filesystem tree (M), q closes preview and tree (M).
  1. Failing cases asserting the scenario THENs.
  2. Wrap in `H.xfail(CODEDIFF_CRASH, …)` as long as `fix-diff-preview-codediff-crash` is queued.
  3. Verify (file-tree 38/38).

## 5. keymaps (integration, `test_keymaps.lua`)

- [ ] 5.1 Scenarios: Alt-e reveals current file, Alt-e closes focused filesystem tree, Alt-e on URI buffer focuses filesystem, Alt-G switches tree to git status, Alt-G closes focused git status tree.
  1. Failing cases with `child.type_keys("<M-e>")` / `"<M-G>"`; assert neo-tree source, focus, cursor node and window count.
  2. None.
  3. Verify (keymaps).
- [ ] 5.2 Scenarios: Alt-g opens Differ (temp repo), Alt-F opens live grep.
  1. Failing cases; assert the Differ layout and the Telescope prompt buffer filetype and title.
  2. None.
  3. Verify (keymaps 36/36).

## 6. session (integration, `test_session.lua`, restart from 1.2)

- [x] 6.1 Scenarios: bare nvim restores the pane session (M:fix-session-fallback-match), bare nvim restores a cwd session after pane id change (M), nvim with a file argument does not restore (M).
  1. Failing cases: first start with a pane id saves the session; `child.restart_config` with the same / another pane id / a file argument; assert the restored buffer list or its absence.
  2. None beyond 1.2.
  3. Verify (session 15/15).

## 7. statusline

- [ ] 7.1 Unit `test_copilot.lua`. Scenarios: copilot glyph hidden when healthy, copilot glyph shown when disabled, copilot glyph shown on warning.
  1. Failing cases with the existing Copilot stubs; assert the component output exactly as the spec states (today `""` for both shown cases, design D5).
  2. None.
  3. Verify (statusline).
- [ ] 7.2 Integration `test_statusline.lua`. Scenarios: diff hidden in narrow windows (temp repo), navic breadcrumb shown when available.
  1. Failing cases: modified file in a window narrower than the spec's threshold, assert the diff text is absent from `H.screen_rows(child, -1)`; stub `nvim-navic` `is_available`/`get_location` in the child and assert the breadcrumb text.
  2. None.
  3. Verify (statusline 28/28).

## 8. Make missing fatal (design D6)

- [ ] 8.1 Scenarios: none (harness).
  1. Confirm `make trace` reports `0 missing` (else return to that capability's group). Failing check: add a temporary scenario without a test to a spec and see `make trace` still exit 0.
  2. `tests/trace.lua` exits non-zero when `missing > 0`; update its header comment and `docs/testing.md` (Static `make trace` row, "Naming rule = traceability").
  3. Verify the temporary scenario makes `make trace` fail, remove it, then `make check` green.
