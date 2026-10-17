## Context

See proposal.md (Why, Evidence). How a link goes wrong:

```
test child: XDG_DATA_HOME=/var/folders/…/osQtcE/2/data
  data/nvim/lazy  -> ~/.local/share/nvim/lazy     (symlink)
  data/nvim/site  -> ~/.local/share/nvim/site     (symlink)
  nvim-treesitter.install({"hcl"})
    install_dir  = stdpath("data")/site      = host site (through the symlink)
    query source = <plugin path as loaded>   = /var/folders/…/data/nvim/lazy/nvim-treesitter/runtime/queries/hcl
    => host site/queries/hcl -> /var/folders/… (dangles once the temp dir is cleaned)
```

## Goals / Non-Goals

**Goals:**
- Tests can't modify the host's parser directory.
- A broken query link heals itself.

**Non-Goals:**
- Changing which parsers are installed.
- The sandbox VM sync.

## Decisions

1. **No install under the test sandbox.** `lua/gleb/treesitter.lua` skips `install()` when the process runs under the test sandbox (the env marker `tests/helpers.lua` already sets, or a new `GLEB_TEST_SANDBOX=1`), and checks the configured parsers once instead. It then reports missing ones with one WARN listing them, so a test that needs a parser fails loudly. Tests that exercise installing call the installer with an explicit temporary `install_dir`.
2. **Repair** (a pure function in `lua/gleb/treesitter.lua`, or `treesitter/repair.lua` if it grows past one screen):
   - For every entry in `<site>/queries/`: if it is a symlink and `fs_realpath` fails, or its target does not start with `<plugin>/runtime/queries/`, relink it to `<plugin>/runtime/queries/<name>`, provided that directory exists.
   - `<plugin>` is the installed nvim-treesitter directory, from `vim.api.nvim_get_runtime_file("lua/nvim-treesitter/init.lua")` resolved with `fs_realpath`.
   - Real directories and files are never touched.
   - Runs once at startup, before the installer, and is quiet unless it relinks: then one INFO naming the repaired languages.
3. **Regression test.** An integration child is started with the real helpers and calls the installer for a parser, with a fake installer stub when building is not possible. The test asserts the host `site` tree's names, link targets and mtimes are unchanged.

## Risks / Trade-offs

- Skipping installs in tests means a newly added parser must be installed by a normal start, or by the sandbox VM's parser sync, before its tests pass. The WARN names it.
- The repair trusts nvim-treesitter's runtime layout (`runtime/queries/<lang>`). It skips when that directory doesn't exist.
