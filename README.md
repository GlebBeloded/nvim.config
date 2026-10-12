# nvim.config

My Neovim config (Lua, lazy.nvim, macOS, run inside zellij in Alacritty). AI agents maintain it through a
local spec-driven loop: every behaviour has an OpenSpec scenario and a headless test, and changes merge
into the `auto` branch only when every gate is green.

## Quick start

```sh
git clone <this repo> ~/.config/nvim && cd ~/.config/nvim
git switch auto
make install deps   # stylua, selene, lua-language-server; test deps
nvim                # lazy.nvim installs the plugins pinned in lazy-lock.json
make check          # the full gate
```

## Commands

| Command | What it does |
|---|---|
| `make check` | every test layer, concurrently: the merge gate |
| `make quick` | only what your changes vs `auto` touch: the inner loop |
| `make test FILE=… CASE=…` | one test file or case |
| `make render CASE=<case>` | capture the real screen in color |
| `make fix BUG="…"` | AI loop: fix a bug end to end |
| `make feature IDEA="…"` | AI loop: build a feature (asks for approval) |
| `make queue` | AI loop: work the next queued change in `openspec/changes/` |
| `make outdated` | plugins with updates past `lazy-lock.json` |
| `make update PLUGIN=<name>` | AI loop: update one plugin, adapt the config if it breaks |
| `make console` | Archon web console for runs and gates |

## Docs

- [Architecture](docs/architecture.md): module map, startup, AI loop, terminal stack, key decisions, conventions
- [Workflow](docs/workflow.md): running the loop, queueing issues, design renders, debugging shortcuts
- [Testing](docs/testing.md): test layers, naming, screenshots
- [Agent rules](docs/CLAUDE.md) (also `CLAUDE.md` and `AGENTS.md`)
- Behaviour specs: [openspec/specs](openspec/specs); queued changes and known issues: [openspec/changes](openspec/changes); project rules: [openspec/config.yaml](openspec/config.yaml)
