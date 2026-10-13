# Proposal

Kind: feature

## Why

The e2e layer only checks that keys arrive (the shortcut table). No test runs a real workflow on real tools: `gr` is checked only as "bound to Telescope `lsp_references`" (`maparg`), gopls never runs in any test, and differ (`<A-g>`, Cmd+G) is opened only on tiny repos inside headless children. A broken gopls root, a Telescope jump that lands on the wrong line, or differ stepping past a hunk would ship green. Part 1 adds reusable fixture repos and the first two real workflows.

## What Changes

- **Fixture builder** `tests/fixtures/build.sh <name>`: builds throwaway repos into `.tests/fixtures/<name>-<hash>/` (gitignored), cached by the hash of the script plus the guest's `go version`, never committed and never nested in the checkout's git tree. Hermetic git (no global config, fixed author and dates). Each fixture writes a manifest (`manifest.json`) with the facts the tests assert (reference locations, changed files and hunks), so the tests carry no line literals.
  - `gomod`: one stdlib-only Go module, `money.Format` declared in `internal/money` and called from `billing` (twice) and `report` (once), plus one call in its own package's test.
  - `dirty`: a git repo with three commits and a staged file, an unstaged file with two separate hunks, a file with both staged and unstaged hunks, and an untracked file.
- **Lua helper** `tests/fixtures.lua`: `copy(name, dest)` builds (or reuses) a fixture and returns a fresh per-test copy and its manifest.
- **Stack**: `stack.lua` `M.start` takes options `cwd` (Neovim's and zellij's start dir), `env` (extra variables) and `layout = "nvim"` (Neovim pane only, no `cat` pane), used by `tests/e2e/alacritty.lua`.
- **Sandbox**: provision installs Go and gopls pinned to the host's versions (go.dev release tarball, `go install golang.org/x/tools/gopls@<ver>`), the same pinning rule as Neovim, zellij and Alacritty; `PROVISION_REV` bump. Go and gopls caches persist in the guest (`.tests/go/`) so gopls starts warm; `GOTOOLCHAIN=local`, `GOPROXY=off`, `GOFLAGS=-mod=mod`, `GOTELEMETRY=off` keep runs offline.
- **Two e2e workflows** (sandbox VM, real Alacritty -> zellij -> Neovim, real key events, state read over RPC):
  - Go references: `gr` on `Format` lists every reference across packages; `<CR>` on the `report` call site opens that file at its line and column.
  - Differ review: Cmd+G on the dirty repo lists every changed file; `]f` steps through files and `]c` through hunks.
- **`make quick`**: changes under `tests/fixtures/`, `lua/gleb/lsp/` or `lua/gleb/git/` add the e2e layer (only while the VM is up).
- **Docs**: `docs/testing.md` gets the fixtures in the layout block, one paragraph on adding a fixture, and the new e2e time.

## Capabilities

### New Capabilities

- `lsp`: language-server workflows of the config (module `lua/gleb/lsp`); starts with the Go references workflow.

### Modified Capabilities

- `git`: adds the requirement "Differ review workflow" (dirty repo, file and hunk navigation from a real key press).

## Impact

- Code: `tests/fixtures/` (new), `tests/fixtures.lua` (new), `tests/shortcuts/stack.lua`, `tests/e2e/alacritty.lua`, `tests/e2e/lsp/`, `tests/e2e/git/` (new), `tests/sandbox/sandbox.sh`, `tests/quick.sh`, `docs/testing.md`. No config code under `lua/` changes.
- Plugin dependency: none added, removed or upgraded. New guest tools (test-only): Go and gopls, pinned to the host's versions.
- Core keymaps: unchanged.
- e2e time: two more stack starts plus a warm gopls; target under +10 s warm.
- Out of scope (part 2+): other languages (Lua/LuaLS, Rust), rename and code-action workflows, differ staging (`s`/`u`) and conflicts, the neo-tree + codediff preview flow (`<A-G>`), diffview, PR review (needs the differ sidecar and GitHub), screenshots of the workflows, headless integration twins of these workflows for `make quick` on the host, one stack shared by the whole e2e layer.
