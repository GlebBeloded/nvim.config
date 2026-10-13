# Tasks

**Goal:** generated fixture repos and two real e2e workflows (Go references through gopls, differ review) run in the sandbox VM.

**Architecture:** `tests/fixtures/build.sh` builds cached fixtures with a manifest; `tests/fixtures.lua` copies one into the stack's temp dir; `stack.lua` gets `cwd`/`env`/`layout`/size options. Tests press real keys (`tests/e2e/alacritty.lua` `press`) and read state over RPC (`stack:lua`). Picked option: design.md, Proposed A.

**Spec:** `specs/lsp/spec.md`, `specs/git/spec.md`, `design.md` (decisions 1-8).

## Global constraints

- No change under `lua/`. A config fault found by a test becomes a queued `fix-*` change and the case is wrapped in `H.xfail("<change id>", fn)`.
- Tests carry no line or column literals: values come from `manifest.json`.
- Waits are `S.wait_for` predicates (10 s cap unless noted); no sleeps.
- Workflow stacks: `layout = "nvim"`, 100x30. The shortcuts file keeps today's defaults (160x45, two panes, checkout cwd).
- Hermetic git in the builder: `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`, fixed `GIT_AUTHOR_*`/`GIT_COMMITTER_*` name, email and date, `-c init.defaultBranch=main`.
- Go env (decision 7): `GOCACHE`, `GOMODCACHE`, `GOPLSCACHE` under `<root>/.tests/go/`, `GOTOOLCHAIN=local`, `GOPROXY=off`, `GOFLAGS=-mod=mod`, `GOTELEMETRY=off`.
- Guest pins: `GO_VERSION=1.27.1`, `GOPLS_VERSION=0.21.1` (the host's), next to `NVIM_VERSION`; `PROVISION_REV=4`.
- Warm `make e2e` within ~23 s (today ~13 s, +10 s budget).
- New Lua is LuaCATS-typed, small named functions (docs/architecture.md, Conventions).

## Review focus

- macOS `/tmp` is `/private/tmp`: compare buffer names and cwd via `vim.uv.fs_realpath` on both sides (task 2.1).
- Cache dir written half by a killed build: build into `<dir>.tmp`, then `mv`; a dir without `manifest.json` is a miss (task 1.3).
- `manifest.json` must sit outside the repo (`<cache>/manifest.json`, repo in `<cache>/repo/`), or `dirty` gets an extra untracked file (task 3.3).
- gopls missing from `PATH` or not attaching must fail with a named cause, not a 10 s timeout on the picker (task 1.1 asserts `executable("gopls")` and the client first).
- `d.txt` has two panel entries (staged and unstaged): the `]f` walk asserts the panel's entry order, not unique paths (task 4.1).

## 1. Go references list call sites across packages

Scenarios: `lsp: References of a Go function list call sites across packages`

**Files:** create `tests/fixtures/build.sh`, `tests/fixtures.lua`, `tests/e2e/lsp/test_go_references.lua`, `openspec/specs/lsp/spec.md`; modify `tests/shortcuts/stack.lua`, `tests/e2e/alacritty.lua`, `tests/e2e/shortcuts/test_e2e.lua`, `tests/sandbox/sandbox.sh`, `tests/quick.sh`.

**Interfaces (produced):**
- `tests/fixtures/build.sh <name>`: prints the cache dir `.tests/fixtures/<name>-<hash>/` holding `repo/` and `manifest.json`.
- `tests/fixtures.lua`: `M.go_env() -> table<string, string>`; `M.copy(name: string, dest: string) -> string root, fixtures.Manifest`.
- `---@class fixtures.Location { path: string, line: integer, col: integer }` (repo-relative path, 1-based line and byte column of the identifier).
- `---@class fixtures.Entry { path: string, staged: boolean, untracked: boolean }`.
- `---@class fixtures.Manifest { references?: table<string, fixtures.Location[]>, files?: fixtures.Entry[], hunks?: table<string, integer[]> }`.
- `---@class shortcuts.StackOpts { cwd?: string|fun(dir: string): string, env?: table<string, string>, layout?: "default"|"nvim", columns?: integer, lines?: integer }`; `S.start(frontend?, opts?)` stores it as `stack.opts`. A function `cwd` gets the stack's temp dir, so `stop()` removes the copy.
- `E.start(opts?: shortcuts.StackOpts)`; `E.start_or_skip(opts?) -> e2e.Stack?, string? reason` (preflight, start, "needs focus without E2E=1" skip; the logic now local to `test_e2e.lua`).

- [x] 1.1 Failing test: `T["lsp: References of a Go function list call sites across packages"]` in `tests/e2e/lsp/test_go_references.lua`. `pre_once`: `E.start_or_skip({ cwd = copy_gomod, env = F.go_env(), layout = "nvim", columns = 100, lines = 30 })`, `copy_gomod(dir)` = `F.copy("gomod", dir .. "/work")`; `post_once` stops. Case: over RPC `:edit internal/money/money.go`, cursor on the `Format` declaration (`manifest.references.Format[1]`); assert `vim.fn.executable("gopls") == 1`, wait for a `gopls` client on the buffer, then for a non-empty `textDocument/references` reply (`client:request_sync`); press `g`, `r`; wait until `&filetype == "TelescopePrompt"` and the picker's `manager:num_results()` equals `#manifest.references.Format`; assert the picker entries `{ path relative to the realpath'd root, lnum, col }` as a set equal the manifest locations, and the manifest's path multiset equals `internal/money/money.go`, `internal/money/money_test.go`, `billing/invoice.go` x2, `report/summary.go`.
- [x] 1.2 Copy `specs/lsp/spec.md` to `openspec/specs/lsp/spec.md` (Purpose kept, `ADDED Requirements` → `Requirements`) so `make trace` links the case. Run `make e2e CASE="lsp: References"`: fails (no `tests.fixtures` module).
- [x] 1.3 `tests/fixtures/build.sh` (POSIX sh, style of `tests/e2e/build.sh`): one function per fixture, here `gomod` (module `example.com/fixture`, stdlib only: `internal/money/money.go` declares `Format(cents int) string`, called once in `internal/money/money_test.go`, twice in `billing/invoice.go`, once in `report/summary.go`, as in the design render). Key = `shasum` of the script + `go version`; old `<name>-*` dirs removed; built in `<dir>.tmp` then `mv`; runs `go build ./...` with the Go env; writes `manifest.json` `references.Format` from the sources (`grep -n` + `awk` for the column). Hermetic git and an initial commit.
- [x] 1.4 `tests/fixtures.lua`: `go_env()` (decision 7 values, absolute `.tests/go/` paths under `H.root`), `copy()` runs the builder with `go_env()` merged into the env, `cp -R <cache>/repo <dest>`, decodes the manifest.
- [x] 1.5 `stack.lua`: `StackOpts`; `opts.env` merged into `self.env`; `cwd` set on the layout's pane(s) (`cwd="…"`); `layout = "nvim"` writes the Neovim pane only. `alacritty.lua`: `columns`/`lines` from `self.opts` (default `M.COLUMNS`/`M.LINES`), `start(opts)`, `start_or_skip(opts)`; `test_e2e.lua` uses `start_or_skip()`.
- [x] 1.6 `sandbox.sh` provision: Go from the go.dev tarball (`go$GO_VERSION.darwin-arm64.tar.gz`) into `~/opt/go`, `~/bin/go` link, `GOBIN=~/bin ~/bin/go install golang.org/x/tools/gopls@v$GOPLS_VERSION`, each skipped when the installed version matches; `PROVISION_REV=4`. Run `make sandbox-provision`.
- [x] 1.7 `quick.sh`: `tests/fixtures/* | tests/fixtures.lua | lua/gleb/lsp/* | lua/gleb/git/*` add e2e (the existing capability mapping stays); header comment updated.
- [ ] 1.8 Run `make e2e CASE="lsp: References"` (passes), `make e2e CASE="shortcuts:"` (still green), `make stack`, `make lint types trace` (green, case listed as tested, no orphans), `make quick` (target line lists `e2e` while the VM runs).
- [ ] 1.9 Commit: `feat(tests): gomod fixture and Go references e2e`.

## 2. Selecting a reference opens its file

Scenarios: `lsp: Selecting a reference opens its file at the call site`

**Interfaces (consumed):** task 1's stack, `F.copy`, the open picker. Cases share the file's stack and run in order.

- [ ] 2.1 Failing test: `T["lsp: Selecting a reference opens its file at the call site"]`. If no picker is open, repeat task 1.1's setup up to the open picker (one named local function shared by both cases). Press `s u m m a r y`, wait for `num_results() == 1`, press `return`; wait until `&filetype ~= "TelescopePrompt"`; assert `vim.uv.fs_realpath(bufname)` equals the realpath of `<root>/report/summary.go` and the cursor (`nvim_win_get_cursor`, col + 1) equals the manifest location of `report/summary.go`. Run `make e2e CASE="lsp: Selecting"`: fails or passes on first run; if it passes, break the expected column by one locally to see it fail, then revert.
- [ ] 2.2 Make it pass with harness changes only. Run `make e2e CASE="lsp:"` (both green) and `make trace`.
- [ ] 2.3 Commit: `test(e2e): Go reference selection opens the call site`.

## 3. Cmd+G opens differ on a dirty repo

Scenarios: `git: Cmd+G opens differ listing every change of a dirty repo`

**Interfaces (consumed):** `F.copy`, `E.start_or_skip`, `StackOpts` (task 1). **Produced:** the `dirty` fixture; manifest `files` (one entry per panel entry: `d.txt` twice) and `hunks["b.txt"]` = worktree start lines of its unstaged hunks (`git diff -U0`).

- [ ] 3.1 Failing test: `T["git: Cmd+G opens differ listing every change of a dirty repo"]` in `tests/e2e/git/test_differ_review.lua` (`cwd` = `F.copy("dirty", dir .. "/work")`, `layout = "nvim"`, 100x30). Press `cmd+g`; wait for `require("differ.panel").current()` with sections; assert `vim.fn.win_screenpos(panel.winid)[2] == 1`; map every `differ.FileEntry` to `{ path, staged = entry.staged == true, untracked = entry.status == "?" }` and assert the set equals `manifest.files`, and the manifest's paths are `a.txt`, `b.txt`, `d.txt` x2, `lib/c.lua`, `new.txt`.
- [ ] 3.2 Append the delta's "Differ review workflow" requirement to `openspec/specs/git/spec.md`. Run `make e2e CASE="git: Cmd+G"`: fails (unknown fixture `dirty`).
- [ ] 3.3 `build.sh` `dirty`: three commits (`a.txt`, `b.txt` of 19 lines `alpha`..`tau`, `lib/c.lua`, `d.txt`), then stage one added line in `a.txt`; unstaged edits on `b.txt` lines 2 and 17; one unstaged line in `lib/c.lua`; `d.txt` one staged and one unstaged change; untracked `new.txt` (3 lines). Manifest `files` from `git diff --cached --name-only`, `git diff --name-only`, `git ls-files --others --exclude-standard`; `hunks` from `git diff -U0 b.txt` (`+start` of each `@@`).
- [ ] 3.4 Run `make e2e CASE="git: Cmd+G"` (green) and `make trace`.
- [ ] 3.5 Commit: `feat(tests): dirty fixture and differ e2e`.

## 4. `]f` and `]c` in differ

Scenarios: `git: ]f steps to the next changed file in differ`, `git: ]c steps to the next hunk in differ`

**Interfaces (consumed):** task 3's stack (differ open), `require("differ").active_view()` (`.model.path`, `.columns[i].winid`, `.columns[i].map.from_new`), panel entries in section order.

- [ ] 4.1 Failing tests in `tests/e2e/git/test_differ_review.lua`:
  - `T["git: ]f steps to the next changed file in differ"]`: over RPC focus the diff window of the last column of `active_view()`; record `active_view().model.path`; then for each following panel entry press `]`, `f` and wait until the path equals that entry's path; assert the visited list equals the panel's entry paths in order and its set equals the manifest's paths.
  - `T["git: ]c steps to the next hunk in differ"]`: press `]`, `f` until `active_view().model.path == "b.txt"` (at most one press per entry); over RPC put the cursor of the last column on `map.from_new[hunks["b.txt"][1]]`; press `]`, `c`; wait until the cursor line equals `map.from_new[hunks["b.txt"][2]]`; assert `nvim_eval_statusline(vim.wo[win].winbar, { winid = win, use_winbar = true }).str` contains `hunk 2/2`.
  Run `make e2e CASE="git: ]"`: fail or pass on first run; a pass is checked by breaking an expectation locally, then reverted.
- [ ] 4.2 Make them pass with harness changes only. Run `make e2e CASE="git:"` (three green), `make trace` (all five scenarios tested, no orphans).
- [ ] 4.3 `docs/testing.md`: `fixtures/` and `fixtures.lua` in the layout block; one paragraph "Adding a fixture" (a function in `build.sh`, its manifest keys, `F.copy` from a stack's `cwd`); the e2e row and the Sandbox VM paragraph get the measured warm time and the Go/gopls pins in the provision row; the `make quick` e2e trigger list adds fixtures, `lua/gleb/lsp/`, `lua/gleb/git/`.
- [ ] 4.4 Run `make check E2E=1`: green; warm `make e2e` within ~23 s.
- [ ] 4.5 Commit: `test(e2e): differ file and hunk navigation; docs`.

## Blocked

- **1.8, spec vs config: `gr` on the declaration lists 4 entries, not 5.** `make e2e CASE="lsp: References"` (sandbox VM) shows the picker with the 4 call sites only: `telescope.builtin.lsp_references` defaults to `include_current_line = false` (telescope `builtin/__lsp.lua`), so the declaration under the cursor is filtered out even though `include_declaration` is true. The scenario "References of a Go function list call sites across packages" (and design render 1, `5 / 5`) assumes 5. Needs a user decision:
  1. Spec change: the picker lists every reference except those on the cursor's line (manifest compare drops the declaration); no config change.
  2. Config change (core keymap `gr`): `lsp_references({ include_current_line = true })`, as a queued `fix-*` change; the case is wrapped in `H.xfail` until it lands.
  Tasks 1.8 to 4.5 wait for that decision; the harness (fixtures, stack options, provision, quick) is in place and committed.
- Notes for the reviewer:
  - `GOPLS_VERSION=0.23.0`, not 0.21.1: the host's gopls is v0.23.0 (`gopls version`), and the rule is "pinned to the host's versions".
  - Harness fixes found on the way: null-ls's `golangci_lint` source is disabled over RPC in the test (golangci-lint is not in the sandbox; its "not executable" message hit a hit-enter prompt under `cmdheight=0` and blocked Neovim); `E.alive` now probes RPC with `nvim_get_mode`, so Neovim waiting on `timeoutlen` (`gr` vs the built-in `grr`/`gra`) is not reported as a dead stack.
  - The shared VM: parallel worktrees rsync into the same guest path (`/Users/lume/nvim`, with `--delete`) and reset `~/.nvim-e2e-provisioned` to their own `PROVISION_REV`; the runs above used a private guest dir. The queued VM lock fix covers the first; the rev ping-pong stays until every branch has rev 4.
