Layer: unit (docs/testing.md step 1). The checks only read repo files with `vim.uv` / `vim.fn`, so they
run in the test process itself: `MiniTest.new_set()`, no child Neovim. Paths are relative to the repo root
(the runner's cwd). One new file: `tests/unit/loop/test_agent_rules.lua`.

## 1. AGENTS.md alias

Scenarios: "loop: AGENTS.md resolves to the agent rules".

- [x] 1.1 Failing test: in `tests/unit/loop/test_agent_rules.lua` add the case "loop: AGENTS.md resolves to the agent rules". For each of `CLAUDE.md` and `AGENTS.md`: `vim.uv.fs_readlink(name)` is non-nil (a symlink) and `vim.uv.fs_realpath(name)` equals `vim.uv.fs_realpath("docs/CLAUDE.md")`. Keep the per-file check in a small named, typed helper. Run `make test FILE=tests/unit/loop/test_agent_rules.lua`; it fails on `AGENTS.md` only
- [x] 1.2 Add the root symlink: `ln -s docs/CLAUDE.md AGENTS.md` (relative, same target form as `CLAUDE.md`)
- [x] 1.3 Rerun the file; the case passes

## 2. Agent rules cover operating the loop

Scenarios: "loop: Agent rules cover how to operate the loop".

- [ ] 2.1 Failing test: add the case "loop: Agent rules cover how to operate the loop" to the same file. Read `docs/CLAUDE.md` with `vim.fn.readfile` joined by `"\n"`, and expect each plain-text needle (`string.find(text, needle, 1, true)`) from a named list: `make fix`, `make feature`, `make queue`, `make update`, `make console`, `` `auto` ``, `make quick`, `make check`, `make e2e`, `sandbox VM`, `never posted on the host`, `openspec/changes/*/proposal.md`, `Decision`. Report the missing needles in one `eq(missing, {})` so a failure lists them all. Run the file; it fails listing the loop/test/e2e/decision needles
- [ ] 2.2 Extend `docs/CLAUDE.md` with short bullets (how to operate, rule 10.1: point to `docs/workflow.md` / `docs/testing.md`, no restated detail): one line on what the project is; loop entry points `make fix`, `make feature`, `make queue`, `make update`, `make console`; the existing `auto` rule; tests: `make quick` while working, `make check` before done, layers in `docs/testing.md`; e2e only via `make e2e` in the sandbox VM, key events are never posted on the host; user decisions live in the `## Decision` sections of `openspec/changes/*/proposal.md`, read them before working a change. Keep the existing bullets
- [ ] 2.3 Rerun the file; both cases pass

## 3. Docs name both aliases

Scenarios: none (rule 10.3 housekeeping, covered by the AI review).

- [ ] 3.1 `docs/architecture.md` rule 10.3: after `docs/CLAUDE.md`, note that the root `CLAUDE.md` and `AGENTS.md` are symlinks to it
- [ ] 3.2 `README.md` Docs list: `[Agent rules](docs/CLAUDE.md) (also `CLAUDE.md` and `AGENTS.md`)`

## 4. Verify

- [ ] 4.1 `make trace` lists both scenarios as `tested`, no orphans
- [ ] 4.2 `make test CASE=loop` and `make check` are green
