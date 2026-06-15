# TODO

## PR diff throws errors

- Investigate why PR diff preview (neo-tree + vscode-diff integration) throws errors
- Key files: `lua/gleb/file_tree/diff_preview.lua`, `lua/gleb/file_tree/init.lua`
- Uses internal vscode-diff API: `codediff.core.git`, `codediff.ui.view`
- Potential issues identified:
  - Async chain (get_git_root -> resolve_revision -> view.create) may fail silently
  - Tab/window management race conditions during rapid navigation
  - Treesitter errors in log (Invalid node type "substitute") may interfere with diff rendering
- Need: exact error message to narrow down root cause

## 2026-04-13

Fix error after commit in ai_commit.lua:

Error executing vim.schedule lua callback: ...ed/.local/share/nvim/lazy/nui.nvim/lua/nui/line/init.lua:72: Invalid 'buffer': Expected Lua number
stack traceback:
[C]: in function 'nvim_buf_set_lines'
...ed/.local/share/nvim/lazy/nui.nvim/lua/nui/line/init.lua:72: in function 'render'
....local/share/nvim/lazy/nui.nvim/lua/nui/popup/border.lua:656: in function 'set_text'
/Users/hlebbeladzed/.config/nvim/lua/gleb/git/ai_commit.lua:138: in function 'set_title'
/Users/hlebbeladzed/.config/nvim/lua/gleb/git/ai_commit.lua:198: in function 'on_error'
/Users/hlebbeladzed/.config/nvim/lua/gleb/git/ai_commit.lua:59: in function </Users/hlebbeladzed/.config/nvim/lua/gleb/git/ai_commit.lua:57>

If a response (e.g. from AI commit / git workflow) contains a URL suggesting to open a PR, automatically copy that URL to the system clipboard via pbcopy.

## 2026-04-16

LSP goes crazy with errors when editing `go.mod` files — floods with diagnostics and makes it impossible to type. Need to investigate gopls behavior on go.mod edits and potentially debounce or suppress LSP diagnostics while actively editing go.mod.

Go to definition: when there are multiple definitions, show a choice popup under the cursor (floating window / telescope picker anchored to cursor position) instead of the default quickfix list at the bottom.

Configure function preview (hover/completion) to show comment + signature, similar to IDEA/VSCode behavior:

- Show function signature and doc comment in preview popup
- Truncate long comments (e.g. cap at N lines with "..." indicator)
- Truncate long signatures similarly
- Goal: compact, readable preview like IntelliJ IDEA / VSCode — not a wall of text

In nvim, I want nvim to see what tilt is running, and suggest debugging targets automatically in nvim-dap.

## [2026-04-27 18:43]

in nvim, fix bug with diff when it doesnt work iwth arrows but works with j/k.

## [2026-04-27 18:44]

remove ai commit comment generation

## [2026-05-05 14:53]
In neovim, I want find to filter by filetype dynamically (only go or only without _test.go files) when doing searches in the codebase

## [2026-05-07 13:04]
In neovim when I open git diff, when I use j to go to the last file, and when I press j after that, it jumps to the buffer to the right with that file opened. It should stay at the last file without jumping to the file buffer. It should stay at the tree.

## [2026-05-07 13:08]
When viewing git diff, be able to annotate diff chunks to some file. Then the diff with annotations should be passed to an agent. Like PR comments, but for local stuff - annotate, then pass to the agent.

## [2026-05-07 13:09]
When viewing git diff, be able to fold code. There should be annotations or commands shown on how to do so.

## [2026-05-07 13:13]
In diff mode, scrolling with the mouse only scrolls one pane, but j/k scrolls both. Mouse scroll should also scroll both panes (or scrolling behavior should be consistent between mouse and j/k).

## [2026-05-07 13:40]
can I somehow pipe context from nvim to claude code session? flow zellij pane nvim + cc. type in nvim -> message passed to cc in another pane? If not possible in cc, possible in other cc-like products?

## [2026-05-07 17:12]
User says terminal+Neovim+Zellij workflow feels clunky/fragile compared to IntelliJ IDEA — afraid of accidentally closing something with 'x'. Wants to know why it feels clunky and how to make it feel less so.

## [2026-05-07 22:10]
In neovim when I push a commit and the PR is not yet opened, and you can see in the status that I should open a PR, use open command to redirect me to that page.

## [2026-05-08 15:38]
gopls is leaking

## [2026-05-08 15:43]
When diffing a deleted file in neo-tree, error occurs:

E211: File "internal/provisioner/vault/testdata/staging-branch/lavanderia.json+disabled" no longer available
E5108: Error executing lua: vim/_editor.lua:0: nvim_exec2(), line 1: Vim:Error executing Lua callback: .../nvim/lazy/neo-tree.nvim/lua/neo-tree/command/parser.lua:199: .../nvim/lazy/neo-tree.nvim/lua/neo-tree/command/parser.lua:108: Invalid path: /private/tmp/merchant-operator-reconciliations/internal/provisioner/vault/testdata/sandbox/lavanderia.json+disabled is not a file
stack traceback:
    [C]: in function 'error'
    .../nvim/lazy/neo-tree.nvim/lua/neo-tree/command/parser.lua:199: in function 'parse'
    ...re/nvim/lazy/neo-tree.nvim/lua/neo-tree/command/init.lua:170: in function '_command'
    ....local/share/nvim/lazy/neo-tree.nvim/plugin/neo-tree.lua:7: in function <....local/share/nvim/lazy/neo-tree.nvim/plugin/neo-tree.lua:6>
    [C]: in function 'nvim_exec2'
    vim/_editor.lua: in function 'cmd'
    ...rs/hlebbeladzed/.config/nvim/lua/gleb/file_tree/init.lua:44: in function <...rs/hlebbeladzed/.config/nvim/lua/gleb/file_tree/init.lua:40>

Source: ~/.config/nvim/lua/gleb/file_tree/init.lua:44 (neo-tree command failing because deleted file path is not valid).

Expected behavior: instead of erroring, the diff should show the file as all red (all deleted lines).

## [2026-05-08 18:29]
Verify that when opening a file in a dev tree (e.g., via fugitive/diffview/git tree view) and editing it, the edits are NOT automatically staged/added to git. Want to confirm current behavior and config to ensure no autocmd or plugin is auto-running `git add` on save.

## [2026-05-11]
CRD autocomplete doesn't work when running `kubectl edit` in nvim.

- `kubectl edit` opens `/tmp/kubectl-edit-XXXXXX.yaml`; yamlls attaches as yaml but has no schema for CRDs.
- `mosheavni/yaml-companion.nvim` only matches against the kubernetes schema bundled in yaml-language-server (core types: Pod, Deployment, Service, etc.) — no CRD support.
- CRDs are **custom (FinteqHub-internal)** — pre-generated catalogs like `datreeio/CRDs-catalog` won't work.
- Need to generate JSON schemas from the live cluster's CRDs and point yamlls at them.
- Options to evaluate:
  - `yannh/kubeconform` ecosystem + a CRD-to-JSONSchema extractor (e.g. `yannh/kubeconform/scripts/openapi2jsonschema.py`)
  - krew plugin `kubectl schema` / `crd-extractor`
  - script that dumps all `kubectl get crds -o json` → JSON Schema → local dir
- Wiring: extend `lua/gleb/lsp/config/yaml/schemas.lua` to map schema files to `kubectl-edit-*.yaml` globs, or rely on yaml-companion's `:Telescope yaml_schema` picker after opening.

## [2026-06-05 14:12]
show LSP status at the bottom (statusline)


## [2026-06-05 16:34]
Integrate fusen.nvim (walkersumida/fusen.nvim) for out-of-band sticky-note comments anchored to lines, stored in JSON outside source (per git branch), rendered as eol virtual text / float window. Goal: comments not in git diff, readable by AI agents from the JSON.
