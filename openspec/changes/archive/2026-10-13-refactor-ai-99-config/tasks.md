# 99 Config Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the 99 setup and entry keymaps into testable `gleb.ai` modules, keep one canonical model value, and preserve all existing Neovim behavior.

**Architecture:** Keep provider behavior in `pi_provider.lua`, pure entry-keymap behavior in `entry_keymaps.lua`, and plugin wiring/order in `ai/init.lua`; the lazy spec delegates to that entry point. Because the completed implementation already exists on `loop/refactor-ai-99-config`, establish its regression tests as a red test-only commit, then merge that branch with history preserved and retain current-branch infrastructure and change artifacts during conflict resolution.

**Tech Stack:** Lua, Neovim APIs, lazy.nvim, ThePrimeagen/99, mini.test child Neovim

**Spec:** `openspec/specs/ai/spec.md`; `openspec/changes/refactor-ai-99-config/proposal.md`; `openspec/changes/refactor-ai-99-config/design.md`

## Global Constraints

- No visible Neovim UI or core keymap change (approval feedback).
- No plugin dependency is added, removed, or upgraded; keep the pinned ThePrimeagen/99 dependency and `event = "VeryLazy"`.
- Preserve the exact lhs, modes (`n`, `v`), descriptions, menu text `99> [s]earch [v]ibe: `, `Question` highlight, scheduled insert behavior, provider command, provider name, and model `openai-codex/gpt-5.6-sol`.
- Keep visual mappings in mode `v` and do not add `silent`; applying conventions 3.6 or 3.4 here would change behavior.
- Do not add a missing-99 fallback or a new scenario; this change has `skip_specs: true`.
- Keep the Ollama commit model in `lua/gleb/git/ai_commit.lua` out of scope.
- Preserve the history of `loop/refactor-ai-99-config`; keep current-branch versions of unrelated files and the newer sandbox-lock and load-scaled startup infrastructure.
- Never delete or weaken a test or scenario. Every added case is named exactly `"ai: <scenario title>"`.

## Review Focus

- Requiring `gleb.ai.pi_provider` before `99` is available must succeed; Task 1 Step 1 requires it in a bare child before installing the 99 stub.
- First access to an inherited provider member after 99 loads must resolve through `Providers.BaseProvider`; Task 1 Step 1 installs the stub late and asserts the inherited value.
- The menu's blocking `getchar()` must not hang the test or hide the prompt; Task 1 Step 1 records `nvim_echo`, inspects the bottom row, and supplies menu choices in the same `type_keys` call.
- An unsupported menu key must leave the current buffer and normal mode unchanged; Task 1 Step 1 asserts no action, empty filetype, and mode `n` after `x`.
- Real `VeryLazy` setup must keep all four entry mappings and load the named wiring module; Task 1 Step 1 asserts normal and visual descriptions plus `package.loaded["gleb.ai"]` in the full config.

---

### Task 1: Merge the tested 99 refactor

**Scenarios:**

- `ai: runs Pi ephemerally with low thinking`
- `ai: defaults to Codex Sol`
- `ai: Provider name`
- `ai: Provider inherits base provider`
- `ai: Menu shows prompt`
- `ai: Menu s opens search prompt`
- `ai: Menu v opens vibe prompt`
- `ai: Menu ignores other keys`
- `ai: Shift-Enter opens vibe prompt`
- `ai: Visual Alt-9 opens visual prompt`
- `ai: Visual Shift-Enter opens visual prompt`
- `ai: Keymaps exist after VeryLazy`

**Files:**

- Create: `lua/gleb/ai/entry_keymaps.lua`
- Create: `lua/gleb/ai/init.lua`
- Modify: `lua/gleb/ai/pi_provider.lua`
- Modify: `lua/gleb/plugins/plugins.lua`
- Create: `tests/unit/ai/test_entry_keymaps.lua`
- Modify: `tests/unit/ai/test_pi_provider.lua`
- Modify: `tests/integration/ai/test_setup.lua`
- Preserve: `openspec/changes/refactor-ai-99-config/design.md`
- Preserve: `openspec/changes/refactor-ai-99-config/tasks.md`

**Interfaces:**

- Consumes: `require("99")` with `setup(opts)`, `search()`, `vibe()`, `visual()`, and `Providers.BaseProvider`; existing `require("gleb.ai.prompt_keymaps").setup()`.
- Produces: `require("gleb.ai").setup() -> nil`; `require("gleb.ai.entry_keymaps").setup(ninety_nine: gleb.ai.Actions) -> nil`; `PiProvider.MODEL: string`; unchanged `_build_command(_, query, context) -> string[]`, `_get_provider_name() -> string`, and `_get_default_model() -> string`.

- [x] **Step 1: Write the failing mini.test cases before merging implementation**

  On the current branch, copy only the completed branch's test changes into the three test files. The case keys must be exactly the scenario names listed above.

  In `tests/unit/ai/test_pi_provider.lua`, require the provider before installing the 99 stub, retain the exact command/name/default assertions, and install the stub only in the inheritance case:

  ```lua
  local function start()
      child.start_bare()
      child.lua([[Provider = require("gleb.ai.pi_provider")]])
  end

  T["ai: Provider inherits base provider"] = function()
      child.lua([[package.loaded["99"] = { Providers = { BaseProvider = { inherited = "from base" } } }]])
      eq(child.lua_get("Provider.inherited"), "from base")
  end
  ```

  In new `tests/unit/ai/test_entry_keymaps.lua`, start a bare child and pass `entry_keymaps.setup()` a stub whose `search`, `vibe`, and `visual` actions record their names, open a new buffer, and set filetype `99`. Assert the following exact outcomes:

  ```lua
  T["ai: Menu shows prompt"]                 -- bottom row text and { text, "Question" }; no action
  T["ai: Menu s opens search prompt"]        -- Opened == "search", filetype == "99", mode == "i"
  T["ai: Menu v opens vibe prompt"]          -- Opened == "vibe", filetype == "99", mode == "i"
  T["ai: Menu ignores other keys"]           -- Opened == vim.NIL, filetype == "", mode == "n"
  T["ai: Shift-Enter opens vibe prompt"]      -- Opened == "vibe", filetype == "99", mode == "i"
  T["ai: Visual Alt-9 opens visual prompt"]   -- Opened == "visual", filetype == "99", mode == "i"
  T["ai: Visual Shift-Enter opens visual prompt"] -- Opened == "visual", filetype == "99", mode == "i"
  ```

  Wrap `vim.api.nvim_echo` to record chunks for `Menu shows prompt`; after `child.type_keys("<A-9>")`, assert `vim.trim(table.concat(H.screen_rows(child, -1).text[1])) == "99> [s]earch [v]ibe:"`, send `<Esc>`, then assert `{ { "99> [s]earch [v]ibe: ", "Question" } }`. Send menu actions as `child.type_keys("<A-9>", "s")` and `child.type_keys("<A-9>", "v")` so typeahead satisfies `getchar()`; start visual cases with `V`.

  In `tests/integration/ai/test_setup.lua`, extend the existing case without renaming it:

  ```lua
  T["ai: Keymaps exist after VeryLazy"] = function()
      child.wait_very_lazy()
      eq({ map_desc("<A-9>"), map_desc("<S-CR>") }, { "99: Menu", "99: Vibe" })
      eq({ map_desc("<A-9>", "v"), map_desc("<S-CR>", "v") }, { "99: Visual", "99: Visual" })
      eq(child.lua_get([[package.loaded["gleb.ai"] ~= nil]]), true)
  end
  ```

- [x] **Step 2: Run the focused tests and verify they fail for the missing refactor**

  Run:

  ```bash
  make test FILE=tests/unit/ai/test_pi_provider.lua
  make test FILE=tests/unit/ai/test_entry_keymaps.lua
  make test FILE=tests/integration/ai/test_setup.lua
  ```

  Expected: the provider file fails because loading it still requires missing `99`; the entry-keymap file fails because `gleb.ai.entry_keymaps` does not exist; the integration case fails because `package.loaded["gleb.ai"]` is false.

- [x] **Step 3: Commit the red regression tests so the merge starts from a clean tree**

  ```bash
  git add tests/unit/ai/test_pi_provider.lua tests/unit/ai/test_entry_keymaps.lua tests/integration/ai/test_setup.lua
  git commit -m "test(ai): pin 99 refactor behavior"
  ```

- [x] **Step 4: Merge the completed implementation branch without committing yet**

  Run `git merge --no-ff --no-commit loop/refactor-ai-99-config`. Resolve conflicts by keeping the source branch's AI modules and test behavior, while keeping the current branch's unrelated files and current `design.md`/`tasks.md`. Do not cherry-pick, manually replay, or reimplement the source commits.

  The merged implementation must have these exact boundaries:

  - `pi_provider.lua`: named lazy `__index` lookup of `require("99").Providers.BaseProvider[key]`, `PiProvider.MODEL = "openai-codex/gpt-5.6-sol"`, and `_get_default_model()` returning that constant.
  - `entry_keymaps.lua`: named prompt/menu functions and `M.setup(ninety_nine)` registering the same four mappings with unchanged modes, lhs, descriptions, text, highlight, and scheduled `startinsert`.
  - `ai/init.lua`: `M.setup()` calls `nn.setup({ provider = provider, model = provider.MODEL })`, then prompt-keymap setup, then entry-keymap setup.
  - `plugins.lua`: the 99 spec keeps its event and dependencies, and its config only calls `require("gleb.ai").setup()`.

- [x] **Step 5: Run the focused tests and verify they pass**

  Run the three commands from Step 2.

  Expected: all four provider cases, all seven entry-keymap cases, and `ai: Keymaps exist after VeryLazy` pass.

- [x] **Step 6: Verify traceability and invariants**

  Run:

  ```bash
  make trace VERBOSE=1
  rg -n -F 'openai-codex/gpt-5.6-sol' lua/gleb/ai lua/gleb/plugins/plugins.lua
  rg -n 'require\("99"\)' lua/gleb/ai/pi_provider.lua
  git diff --check
  ```

  Expected: trace lists all twelve task scenarios as tested with no orphan; the model search has one hit in `pi_provider.lua`; the provider's only 99 require is inside the lazy lookup function; `git diff --check` prints nothing.

- [x] **Step 7: Run project verification**

  Run `make quick`, then `make check E2E=1`.

  Expected: both commands pass. A host-load startup timeout or shared sandbox lock is infrastructure noise only after a clean isolated rerun confirms it; do not weaken tests, timing budgets, or sandbox locking to make the gate green.

  - This implementation pass ran `make quick` successfully. Per the pass instruction, the following gate runs the full `make check`; it was not run here.

- [x] **Step 8: Commit the verified merge**

  ```bash
  git add lua/gleb/ai/entry_keymaps.lua lua/gleb/ai/init.lua lua/gleb/ai/pi_provider.lua lua/gleb/plugins/plugins.lua tests/unit/ai/test_entry_keymaps.lua tests/unit/ai/test_pi_provider.lua tests/integration/ai/test_setup.lua openspec/changes/refactor-ai-99-config/design.md openspec/changes/refactor-ai-99-config/tasks.md
  git commit -m "refactor(ai): merge tested 99 config modules"
  ```
