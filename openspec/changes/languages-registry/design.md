## Context

See proposal.md (Why). Language knowledge today, by place:

| Place | Holds | Typed | Discovered |
|---|---|---|---|
| `lsp/config/<lang>/init.lua` | servers (`lsp_name`/`lsp_names`), `lsp_config`, `mason`, `null_ls` | no | hand list in `lsp/config/init.lua` |
| `treesitter.lua` | parsers | `string[]` | hand list |
| `references/scope.lua` | test patterns by filetype | partly | filetype table |
| `references/kind.lua` | parser-language map, tsserver special case | partly | filetype table |
| `queries/<lang>/usages.scm` | usage types | n/a | runtimepath |
| `tests/fixtures/build.sh` | reference fixture projects | n/a | case list |

## Goals / Non-Goals

**Goals:**
- One place per language.
- A typed, discoverable registry.
- Features declare what a language must provide.
- A missing piece fails at startup or in the contract test, never silently.

**Non-Goals:**
- New languages or behaviour.
- Testing, debugging and formatting facets (later).

## Decisions

1. **Types** (`lua/gleb/languages/types.lua`, LuaCATS only):

   ```lua
   ---@class gleb.language.Disabled
   ---@field disabled string  reason, e.g. "no references in JSON" or "queued: <change-id>"

   ---@class gleb.Language
   ---@field name string                       folder name
   ---@field filetypes string[]
   ---@field lsp gleb.language.Lsp|gleb.language.Disabled
   ---@field treesitter gleb.language.Treesitter|gleb.language.Disabled
   ---@field references gleb.language.References|gleb.language.Disabled

   ---@class gleb.language.Lsp
   ---@field servers string[]                  vim.lsp.enable names
   ---@field config? vim.lsp.Config            merged over the shared handlers config
   ---@field mason string[]
   ---@field null_ls? fun(null_ls: table): table[]

   ---@class gleb.language.Treesitter
   ---@field parsers string[]

   ---@class gleb.language.References
   ---@field test_patterns string[]            Lua patterns on the normalised path
   ---@field usage_types true|gleb.language.Disabled
   ---@field write_access "documentHighlight"|"tsserver"|false
   ---@field target_kinds table<string, gleb.references.TargetKind>  SymbolKind name → target kind override (terraform: { Class = "unknown" }), {} for none
   ---@field fixture { project: string, symbol: string }
   ```

   Facet fields are required, never optional, so `make types` flags a spec that omits one.
2. **Registry** (`lua/gleb/languages/init.lua`):
   - `M.all()` loads every `lua/gleb/languages/*/init.lua` found through `vim.api.nvim_get_runtime_file`, sorted by name.
   - `M.for_filetype(ft)` looks up a language by filetype.
   - `M.facet(name)` returns `{ language, config }` pairs for the languages where that facet is enabled.
   - `M.register_facet(name, validate)` is called by the feature that owns the facet, in its setup.
   - The registry is pure apart from `require`. Test resets go through `M.state` and `M.reset()` (rule 1.5).
3. **Facets are owned by features.**
   - `lsp/config/init.lua` registers `lsp`, `treesitter.lua` registers `treesitter`, and `references/init.lua` registers `references`.
   - `M.validate()` runs after the facets are registered, from `init.lua` load order (rule 1.6). It errors on:
     - a language that lacks a registered facet;
     - an unknown facet key;
     - `disabled` with an empty reason;
     - a validator failure.
   - The error names the language and the facet.
4. **Contract** (`lua/gleb/languages/contract.lua`, pure): `check(language) -> string[]` lists the problems. The unit test `tests/unit/languages/test_contract.lua` asserts that every registered language has none. For an enabled `references` facet:
   - each of its filetypes' parser languages (`vim.treesitter.language.get_lang(ft)`) is in the treesitter install list;
   - `queries/<lang>/usages.scm` exists and compiles for each of them when `usage_types == true` (terraform's file is `; inherits: hcl`);
   - every capture is `_…` or a catalogue id;
   - `tests/unit/references/usage_cases/<name>.lua` exists when `usage_types == true` (that language's query cases, run by a shared driver);
   - the fixture project is a case in `tests/fixtures/build.sh`, and its manifest lists `fixture.symbol`.

   The contract also rejects a disabled reason `queued: <id>` when `openspec/changes/<id>` doesn't exist, so a placeholder can't outlive its change.
5. **Migration.** Language values are taken from the current files:
   - `css`, `go`, `html`, `js`, `json`, `lua`, `python`, `rust`, `shell`, `terraform` and `yaml` keep their servers, mason packages and null-ls sources. `rust` keeps `servers = {}`: rustaceanvim starts rust-analyzer.
   - The parsers move: go `{ go, gomod }`, js `{ javascript, typescript, tsx }`, json, lua, python, rust, shell `{ bash }`, terraform `{ hcl, terraform }` and yaml. The editor list keeps vim, vimdoc, markdown and markdown_inline.
   - `references` is enabled for go, js, lua, python, rust, shell and terraform, with today's test patterns and fixtures:

     | Language | Fixture project | Symbol |
     |---|---|---|
     | go | gomod | `Format` |
     | lua | luaproj | `total` |
     | python | pyproj | `total` |
     | js | tsproj | `total` |
     | rust | rustproj | `total` |
     | shell | bashproj | `total` |
     | terraform | tfproj | `region` |

   - `usage_types` is `true` for go and `{ disabled = "queued: <change-id>" }` for the rest: `fix-references-usage-types-typescript` (js), `-python`, `-rust`, and `-lua-bash-terraform` (lua, shell, terraform).
   - `target_kinds` is `{ Class = "unknown" }` for terraform (moved from `kind.lua`, `fix-references-usage-types` Decision 3) and `{}` for the rest. lua, shell and terraform still run their write/read-only query files.
   - css, html, json and yaml get `references = { disabled = "no references fixture; data or markup language" }`.
6. **Query parser language.** The facet has no parser field. The query runner uses the buffer filetype's parser language from core `vim.treesitter.language.get_lang`, so one language can span several parsers (js: javascript, typescript, tsx) with no extra configuration. The old `terraform → hcl` map in `kind.lua` goes away, because `queries/terraform/usages.scm` inherits hcl.
7. **The view and request code don't change:** they already work for any attached client. Only scope, kind and the query runner consult the facet.

## Risks / Trade-offs

- **Startup cost:** discovery reads about 11 small modules, which is negligible. The registry is loaded once.
- **Typed facets add boilerplate** for data languages: four `{ disabled = … }` entries each. That is accepted: the reason text is exactly the record the user asked for.
- **A placeholder reason can go stale.** The contract's `queued:` check ties it to the queue.
