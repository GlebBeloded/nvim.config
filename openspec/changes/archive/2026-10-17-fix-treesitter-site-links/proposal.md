## Why

Kind: bug

Test runs write into the host's real parser directory. A test child created `~/.local/share/nvim/site/queries/hcl` as a symlink into its own temporary directory, so once macOS cleans `/var/folders`, the `hcl` and `terraform` queries (highlights, folds, the references `usages` query that inherits hcl) silently disappear from the user's editor.

## Evidence

- `readlink ~/.local/share/nvim/site/queries/hcl` gives `/var/folders/9c/…/T/nvim.hlebbeladzed/osQtcE/2/data/nvim/lazy/nvim-treesitter/runtime/queries/hcl`. Every other entry points at `~/.local/share/nvim/lazy/nvim-treesitter/runtime/queries/<lang>`.
- The link and `parser/hcl.so` are both dated 2026-10-17 04:38. That is the references work that added `hcl` to the parser list (commit 2b3c6df, "fix(treesitter): install reference language parsers"). The first install of the new parser happened inside a test child.
- `tests/helpers.lua` `fresh_state()` (lines 46-53) gives each child a temporary `XDG_DATA_HOME` whose `nvim/lazy`, `nvim/site` and `nvim/mason` are symlinks to the host's real directories.
  - In the child, `require("nvim-treesitter").install(parsers)` (`lua/gleb/treesitter.lua:25`) installs into `stdpath("data")/site`, which is the host's real `site`.
  - It links each query folder to the plugin's runtime path as the child sees it: the temporary `…/data/nvim/lazy/nvim-treesitter`.

## What Changes

- **Test children never install into the host's directories.** Under the test sandbox, the full config does not run the parser installer: missing parsers are reported, not built. Alternatively, a child's install writes only inside its own temporary directory. The fix pass picks one and records it.
- **Startup repair.** The treesitter setup checks `stdpath("data")/site/queries/*` on start. A symlink whose target is missing, or is outside the installed nvim-treesitter's `runtime/queries`, is replaced by a link to `<nvim-treesitter>/runtime/queries/<lang>`. A missing parser `.so` stays the installer's job. This repairs the user's broken `hcl` link on the next start, with no manual step.
- **Regression test:** a test child that runs the parser installer leaves every host `site` entry unchanged.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `languages`: ADDED "Parser installs stay valid".

## Impact

- Code: `lua/gleb/treesitter.lua` (repair on start, no install under the test sandbox), and `tests/helpers.lua` (if the fix keeps installs inside the child's own directory).
- Tests:
  - unit: the link repair, run on a temporary `site` dir;
  - integration: a sandboxed child running the installer leaves the host `site` untouched.
- Plugins: none. Core keymaps: none.
- `languages: Installed parsers are unchanged` still holds: the parser list passed to the installer is the same; only where and when it runs changes.
- Out of scope:
  - Repairing parser `.so` files built from a temporary checkout. The `.so` files are self-contained, so they still work.
  - The sandbox VM's own parser sync.

## Decision (user, 2026-10-17)

- "add fixes to that in the loop too: … The queries/hcl symlink into a temp directory is still unfixed."

## Agent decisions

- **Repair on start, not a one-off command.** The broken link fixes itself on the next start, and any future leak is healed the same way.
- **Only query links outside the installed plugin are repaired.** Links into the real lazy directory are left alone, so a user's custom query folder that is not a symlink is never touched.
