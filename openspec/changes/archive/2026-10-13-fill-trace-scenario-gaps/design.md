## Context

See proposal.md (Why, What Changes). Root cause: `tests/trace.lua` reports `missing` as a count but exits 0 for it, so specs were written (and later modified by queued changes) without a test, and `make check` never turned red. `make trace VERBOSE=1` on 2026-10-12 still lists the same 70 scenarios (total is now 191 because `loop` was added, fully traced).

State of the test harness that shapes the work:
- No test creates a git repository; the only git-backed tests diff files of this checkout (`tests/integration/file-tree/test_diff_preview.lua`). `git` has no test directory at all.
- `child.start_config()` calls `H.isolate()`, which gives every start fresh `XDG_DATA_HOME`/`XDG_STATE_HOME`. Session-restore scenarios need a second start that sees the first one's state.
- External processes in the code under test: `vim.fn.system` (`git add/reset/commit` in `lua/gleb/file_tree/init.lua`, `git diff --cached` in `lua/gleb/git/ai_commit.lua`) and `vim.fn.jobstart` (`git push`, `ollama run`).
- `copilot.lua` is disabled in full-config children; the Copilot component already has a unit file with stubs (`tests/unit/statusline/test_copilot.lua`).
- No visible UI changes: this change adds tests only, so there are no renders.

## Goals / Non-Goals

**Goals:**
- Every listed scenario gets one case named `<capability>: <scenario title>` that asserts the scenario's THEN as written.
- Tests are hermetic: temp git repos, no network, no real `git push`, no real `ollama`.
- After the last case, `missing` makes `make trace` exit non-zero.

**Non-Goals:**
- Changing `lua/` or any spec text. A test that fails because the code does not do what the spec says is wrapped in `H.xfail("<change id>: …")` naming an existing or newly queued change.
- Screenshot references: no missing scenario is visual-only (statusline/gutter ones assert text, not layout).

## Decisions

### D1. Layer per scenario
Follow `docs/testing.md` "Adding a test": unit when the module runs alone with stubs, integration when the scenario needs the real config.

| Capability | Layer and file | Why |
|---|---|---|
| `ai` | integration `tests/integration/ai/test_prompt_keys.lua` | keys are mapped by the real config; the 99 prompt buffer and the `99> [s]earch [v]ibe: ` getchar prompt need the plugin loaded. The menu is driven with `child.type_keys` and the message area read with `H.screen_rows(child, -1)`. |
| `file-tree` | integration `test_tree.lua` (tree, mappings, `c`/`P`, Space), `test_diff_preview.lua` (`j`/`k`, deleted file, debounce, reuse, focus guard, `q`, Enter) | all need neo-tree with the config's mappings. |
| `git` | unit `tests/unit/git/test_modules.lua` (optional plugins tolerated), `tests/unit/git/test_ai_commit.lua` (popup, generation, result, actions; bare child, temp repo, stubbed `jobstart`); integration `tests/integration/git/test_git.lua` (commands, gitsigns, Differ, Diffview, vscode-diff load, Gitlink) | `ai_commit` has no plugin deps; viewers and gitlinker need the real config. |
| `keymaps` | integration `test_keymaps.lua` (existing) | real mappings. |
| `session` | integration `test_session.lua` (existing) | real resession + autocmds across two starts (D3). |
| `statusline` | unit `test_copilot.lua` (existing, Copilot states stubbed); integration `test_statusline.lua` (narrow diff, navic) | Copilot is disabled in config children; navic location is stubbed via `require("nvim-navic").get_location`/`is_available` in the child. |

Alternative: screen tests for statusline/gutter. Rejected: the THENs are text assertions; screenshots would also assert unrelated layout.

### D2. Temp git repository helper
Add `H.git_repo(files, opts)` to `tests/helpers.lua`: creates a temp dir, `git init -b main`, sets a local `user.name`/`user.email`, writes and commits `files`, optionally adds a remote URL (`opts.remote`), and returns the path. It runs on the host (the child inherits nothing but the path), so it never depends on the child's state. Cases `cd` the child into it.

Alternative: diff files of this checkout like `test_diff_preview.lua`. Rejected for new cases: staging, committing and conflicts would mutate the worktree, and results depend on its dirty state. Existing cases are left as they are.

### D3. Second start with kept state
Add `child.restart_config(args, opts)` (or an `opts.keep_state` on `start_config`) that skips `fresh_state()` and passes extra args (file argument, env for the zellij pane id). Session cases: start, edit `a.txt`, `:qall` (child exits; assert the session file on disk from the host), then restart with kept state and assert the restored buffer.

Alternative: write the session file by hand. Rejected: the scenario requires the session that the config saves.

### D4. Stubbing external processes in the child
Before the action, the case replaces `vim.fn.jobstart` in the child with a recorder that stores `cmd` and the stdin sent with `chansend`, and invokes `on_stdout`/`on_exit` with scripted data on `vim.schedule`. `git diff --cached` is real (the bare child `cd`s into a temp repo, D2), so the prompt is checked against real output. `git push` is stubbed the same way; notifications are captured by replacing `vim.notify` with a recorder. Real local `git commit` and `git add/reset` run against the temp repo, so "c commits confirmed message" asserts `git log -1 --format=%s`.

Alternative: a fake `ollama`/`git` on `PATH`. Rejected: slower, platform shell scripts, and the THEN is about the spawned command and its stdin, which the recorder sees directly.

### D5. Interaction with queued changes
- Scenarios in requirements modified by `fix-diff-preview-stale-tab`, `fix-neotree-commit-check`, `fix-session-fallback-match`, `fix-session-save-guards`: at implementation time, test the text in `openspec/specs/` if that change is not archived yet, else the modified text (proposal rule). The task notes which.
- Cases needing a working codediff view use the existing `CODEDIFF_CRASH` xfail reason in `test_diff_preview.lua`.
- Copilot "shown when disabled/on warning" assert `""` as specified; `fix-empty-nerd-font-glyphs` updates them.

### D6. Making `missing` fatal
Last task: `tests/trace.lua` exits non-zero when `missing > 0` and the header comment says so; `docs/testing.md` "Naming rule = traceability" and the Static `make trace` row are updated to "fails on orphan or missing tests". From then on, a new scenario without a test fails `make quick`/`make check`, which is the fix for the root cause.

## Risks / Trade-offs

- [A test fails because the code is buggy] → `H.xfail` with a queued change in `openspec/changes/` (new `fix-*` proposal if none exists); never weaken the assertion. Out of scope to fix.
- [Async plugins (gitsigns, diffview, neo-tree, telescope) make cases flaky] → `child.wait(expr, ms)` on observable state, never fixed sleeps except where the spec names a delay (blame 300 ms).
- [Diffview/Differ/Telescope cases are slow and push `make test` time up] → one child per case as elsewhere; `tests/parallel.lua` balances by timing. Accept.
- [Making `missing` fatal blocks queued spec changes that add scenarios before tests] → the loop already writes the test with the scenario (tasks rule "first step is a failing test"); a change that adds a scenario adds its test in the same branch.
- [Concurrent changes touch the same test files (stale-tab, commit-check, session fixes)] → each merges via `auto`; conflicts are additive (new cases).

## Migration Plan

Not applicable (tests only). Rollback is reverting the branch.
