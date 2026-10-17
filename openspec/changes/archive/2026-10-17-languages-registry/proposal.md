## Why

Knowledge about each language is scattered across features, untyped, with nothing that notices a gap:
- LSP servers, mason packages and null-ls sources live in `lua/gleb/lsp/config/<lang>/init.lua` (ad-hoc fields: `lsp_name` or `lsp_names`, `lsp_config`, `mason`, `null_ls`), listed by hand in `lua/gleb/lsp/config/init.lua`.
- Treesitter parsers are a hand list in `lua/gleb/treesitter.lua`.
- Test-file patterns are a filetype table in `lua/gleb/references/scope.lua`. The parser-language map (`terraform` → `hcl`) is in `references/kind.lua`; it is dropped, because each filetype's own parser language is used. Usage queries are files in `queries/<lang>/`.
- Reference fixtures are projects in `tests/fixtures/build.sh`.

So an agent adding a language has to know all of these places, and nothing fails when one is missed. The user wants a plugin-like API: features define what a language must provide, a language plugs in by answering every facet, and a missing answer fails loudly.

Kind: feature
Depends: fix-references-usage-types

## What Changes

- New `lua/gleb/languages/`, a typed registry.
  - Each language is one folder `lua/gleb/languages/<name>/` whose `init.lua` returns a `gleb.Language`: name, filetypes, and one entry per registered facet.
  - The registry discovers language folders itself; there is no hand-kept list.
- **Facets are the plugin API.**
  - A feature registers a facet: its name, a LuaCATS type and a validator.
  - Every language must answer every facet, either with a configuration or explicitly `{ disabled = "<reason>" }`.
  - Validation runs at startup and errors with `languages: <name> lacks facet <facet>` or the validator's message.
  - Consequences:
    - Adding a facet makes every language answer it.
    - Adding a language makes it answer every facet.
    - `make types` checks each spec's fields.
- **Three facets in this change:**
  - `lsp`: servers, server config, mason packages and null-ls sources. The current `lsp/config/<lang>` modules move here, with `lsp_name`/`lsp_names` unified as `servers`.
  - `treesitter`: the parsers to install. `treesitter.lua` keeps only the editor parsers (vim, vimdoc, markdown, markdown_inline) and adds every language's.
  - `references`:
    - `test_patterns`.
    - `usage_types`: `true` requires a `usages` query for the parser language of each of its filetypes. That language comes from Neovim's `vim.treesitter.language.get_lang`, so `typescriptreact` uses `tsx`, and terraform's query inherits hcl's.
    - `write_access`: `documentHighlight`, `tsserver` or `false`.
    - `target_kinds`: symbol-kind overrides for target-kind refinement (terraform: Class → unknown).
    - `fixture`: a `tests/fixtures/build.sh` project, with the manifest symbol `gr` is checked on.
    - `references/scope.lua` and `references/kind.lua` read only this facet.
- **Contract test,** a unit test that is data-driven over the registry. For every language and facet it checks:
  - the validator passes;
  - a `usages` query exists, compiles with the parser, and only captures catalogue ids;
  - the fixture project and its manifest symbol exist;
  - the parsers are in the install list.
- **Data-driven language coverage.**
  - `tests/integration/references/test_languages.lua` runs `gr` once per language with an enabled `references` facet, so a new language is covered automatically. A missing server is still reported as a skip.
  - The per-language usage-type cases run from each language's table of query cases (see design.md).
- **Architecture rule 1.10:** language knowledge lives only in `lua/gleb/languages/<name>/`, and features read it through the registry.
- **Behaviour is unchanged.** The same servers, mason packages, null-ls sources, parsers, test patterns and classification result.

## Capabilities

### New Capabilities
- `languages`: the registry, facets, validation and contract.

### Modified Capabilities
- none (lsp, treesitter and references behaviour is unchanged; they now read the registry).

## Impact

- Code:
  - New: `lua/gleb/languages/` (`init.lua` registry, `types.lua` classes, `contract.lua` pure checks, and one folder per language: css, go, html, js, json, lua, python, rust, shell, terraform, yaml).
  - Moved: `lua/gleb/lsp/config/<lang>/` → `lua/gleb/languages/<lang>/lsp.lua`. `lua/gleb/lsp/config/init.lua` reads the `lsp` facets.
  - Changed:
    - `lua/gleb/treesitter.lua` (the parser list is editor parsers plus facets);
    - `lua/gleb/references/scope.lua`, `kind.lua` and `kind_ts.lua` (facet lookups instead of filetype tables);
    - `docs/architecture.md` (rule 1.10, module map).
- Tests:
  - unit: registry, facet validation, contract;
  - integration: `test_languages.lua` driven by the registry; the lsp config test checks the server list is unchanged.
- Plugins: none. Core keymaps: none.
- Unchanged scenarios:
  - `lsp: diagnostic signs use Nerd Font glyphs` still holds: moving language-specific server data does not change shared diagnostic signs.
  - `references: Go test paths` still holds: the same patterns now come from the go language's `references` facet.
  - `references: TypeScript and JavaScript test paths` still holds: the same patterns come from the js facet.
  - `references: Python test paths` still holds: the same patterns come from the python facet.
  - `references: Lua test paths` still holds: the same patterns come from the lua facet.
  - `references: Rust test paths` still holds: the same patterns come from the rust facet.
  - `references: Bash test paths` still holds: the same patterns come from the shell facet.
  - `references: Terraform test paths` still holds: the same patterns come from the terraform facet.
  - `references: Project test-pattern extensions` still holds: `vim.g.gleb_test_patterns` still extends a filetype's patterns.
  - `file-tree: gr keeps its global meaning in git status tree` still holds: the global `gr` mapping is untouched; only where per-language data is read from moves.
  - `references: Project pattern extends one filetype` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: A project adds its own test pattern` still holds: `vim.g.gleb_test_patterns` still extends the facet patterns per filetype.
  - `references: gr opens the view in a Go module` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr with no usages notifies and opens nothing` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr without a references-capable client notifies` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr continues when one client refuses the request` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Wide view matches reference screenshot` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Narrow view fits its content` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Preview leaves no buffer or client behind` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Escape returns to the origin window` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Built-in close returns to the origin window` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Lua usages in production and spec files` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Python usages in production and test files` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: TypeScript usages in production and test files` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Rust usages in production and test code` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Bash usages in production and test scripts` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Terraform variable usages` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Variable usages are grouped by write and read` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr classifies every Go variable usage` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr classifies every Lua local usage` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr classifies every Python variable usage` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr classifies every TypeScript variable usage` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr classifies every Rust variable usage` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr classifies every Bash variable usage` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr classifies every Terraform variable usage` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: gr classifies struct usages` still holds: the Go query and classification pipeline are unchanged; only their per-language configuration source moves to the registry.
  - `references: gr classifies function usages as calls` still holds: the Go query and classification pipeline are unchanged; only their per-language configuration source moves to the registry.
  - `references: Composite literal keys are field writes` still holds: the Go query and write-access classification are unchanged; only their per-language configuration source moves to the registry.
  - `references: Struct usages are grouped by usage type` still holds: grouping and rendering are unchanged; only classification configuration moves to the registry.
  - `references: The view opens before classification finishes` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
  - `references: Classification gives up after the timeout` still holds: the references flow is unchanged; scope and kind read the same per-language values from the registry instead of filetype tables.
- Out of scope:
  - testing (neotest adapters), debugging (dap) and formatting-on-save facets. Each can be added later as a facet, which the contract then enforces for every language.
  - `:checkhealth` output.
  - Adding languages.

## Decision (user, 2026-10-17)

- "is the api/typing clear and logical inside lua? For example when I add new langauge, i want ai langauge not to miss it has to implement that aswell. Ideally it should have plugin-like api, and then langauges just plugin in to the library right? Create a feature for this if not like this already."

## Decision (auditor, 2026-10-17, behaviour unchanged)

- The registry changes no behaviour: every attached client that supports `textDocument/documentHighlight` still supplies read/write kinds (bash included) unless a facet explicitly opts out with a reason in its module; a registry entry never narrows what the previous code did for a filetype, registered or not.
- Paths a language module reads (e.g. the Lua server's settings file) resolve relative to that module's own file, never `stdpath("config")`, so the config works under `NVIM_APPNAME` and from a worktree.

## Agent decisions

- **Placement in the queue:** this runs right after `fix-references-usage-types` and before the per-language usage-type changes. Those changes then plug in by setting `references.usage_types = true` and adding their query, which the contract checks.
- **Language names** are the current `lsp/config` folder names: `js` covers javascript, typescript and their react variants; `shell` covers sh, bash and zsh.
- **Disabled facets need a reason.** No silent defaults: a facet a language can't serve is written as `{ disabled = "…" }`, for example json's `references`. Queued work reads `{ disabled = "queued: <change-id>" }`.
- **Validation errors at startup** rather than warning. A broken language spec is a config bug, and the loop's startup smoke test catches it.
