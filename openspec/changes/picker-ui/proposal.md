## Why

Menus come from four separate places: Telescope for live grep and references, a nui.nvim code-action menu, the 99 echo-prompt menu, and plugin pickers. Each one looks and behaves differently. The user wants a single custom UI that we control, built on a library rich enough to draw anything.

Kind: feature
Adopt: loop/picker-ui

## What Changes

- New `lua/gleb/picker/`: one shared picker UI on **mini.pick**, styled like snacks.picker, which the user finds more refined. It is the base for `find-action` and for every list menu in the config.
- **Frame (new global UI rule):**
  - Every border is drawn in full.
  - The only text on a border is the title and the live query in the top border: `╭ Find Action › diff ───╮`.
  - Hints sit on the last row inside the window, right-aligned and grey, below a `├──┤` rule joined to the border. There is no match counter.
- **Rows:**
  - The primary text, then secondary text right after it in a dimmer grey.
  - The category right-aligned in grey.
  - Optional section headers with a trailing rule (`recently used ───`), drawn through `source.show`.
- **Responsive layout:** `window.config` is a callable, so mini.pick recomputes it on its own `VimResized` refresh.
  - `source.show` picks columns from the window width:
    - At least 72 columns: everything.
    - 48–71 columns: no category, and hints shrink to keys only.
    - Under 48 columns: primary text only, and no hint row.
  - When Neovim has fewer than about 15 lines, the picker takes the full height.
- **Replacements:**
  - Live grep (`<A-F>`) and LSP references (`gr`) use mini.pick sources: mini.extra's `grep_live` and `lsp`.
  - `vim.ui.select` uses the shared picker, including code actions and support for `opts.preview_item`. This replaces `lua/gleb/select/code_action.lua` (nui).
  - The 99 searches switch from `extensions.telescope` to `extensions.native`.
- **BREAKING:** telescope.nvim is removed, along with `lua/gleb/telescope.lua`, the telescope spec and its tests. project.nvim's telescope extension (`lua/gleb/project.lua`) goes with it.
- Add a convention to `docs/architecture.md`: rule 8.9 "Borders are always drawn in full; hints and counters never sit on a border; the title (and query) is the only border text; hints go right-aligned in grey on the last inner row below a joined rule."

## Capabilities

### New Capabilities
- `picker`: the shared picker frame, row anatomy, responsive breakpoints and `vim.ui.select`.

### Modified Capabilities
- `telescope`: removed (requirements retired).
- `select`: the code-action picker becomes a `picker` consumer. Its keymap, completion-contract and fit-width requirements change.
- `keymaps`: `<A-F>` live grep and `gr` references run through `picker` sources instead of Telescope.
- `shortcuts`: Cmd+Shift+F keeps its terminal route while invoking the replacement live-grep picker.
- `lsp`: the Go references workflow uses the shared references picker instead of Telescope.
- `session`: the startup-session-name guarantee survives generic cwd changes after project.nvim is removed.
- `ai`: 99 search uses its native picker extension.

## Impact

- Plugins:
  - **Adds** `nvim-mini/mini.pick` and `nvim-mini/mini.extra`, and optionally `mini.visits` for recently used items.
  - **Removes** `nvim-telescope/telescope.nvim`.
  - Alternatives, checked 2026-10-14:

    | Library | Stars | Last push | Notes |
    |---|---|---|---|
    | mini.nvim (pick/extra) | 9.6k | 2026-10-13 | 0 open issues on the mirror; `source.show` gives the raw buffer; mini.test-friendly. **Chosen** |
    | snacks.nvim picker | 8.1k | 2026-05-25 | Richest out of the box, but frozen: 118 open PRs, the author has moved to another project |
    | fzf-lua | 4.5k | 2026-10-14 | Fastest, but fzf-rendered rows cannot draw right-aligned extmark labels |
    | nui.nvim | 2.1k | 2026-08-18 | Primitives only: no matcher, no async |
    | telescope.nvim (current) | 19.8k | 2026-08-17 | 464 open issues; replaced |
- Code: new `lua/gleb/picker/`; `lua/gleb/select/`, `lua/gleb/keymaps.lua` (`gr`, `<A-F>`), `lua/gleb/ai/`, `lua/gleb/alpha.lua`, `lua/gleb/project.lua`, `lua/gleb/plugins/plugins.lua`, `init.lua` and `lazy-lock.json` change; `lua/gleb/telescope.lua` is deleted.
- Tests: screen tests (reference screenshots) for the frame, the hint row and the three widths; integration tests for grep, references and `ui.select`; unit tests for the breakpoint logic. The old telescope tests are retired together with their spec.
- Core keymaps: `<A-F>` and `gr` keep their keys but open the new picker.
- Pinned behavior: `file-tree: gr keeps its global meaning in git status tree` still holds because the tree continues to leave `gr` unmapped and inherits the replacement global references picker.
- Out of scope: the Find Action palette (`find-action`), new code-search menus (separate shortcut, later), and moving keys onto the registry.

## Decision (user, 2026-10-14)

- Get rid of telescope for "our own custom UI … richest library so we can do whatever we want". Telescope, LSP references and the other menus are all rewritten.
- Library: **mini.pick**, styled like snacks ("I like snacks.picker ui more. It is more refined").
- Borders: "drawing full border is good. We just put tip above bottom border in gray text", as a general rule for all current and future work. The title stays in the top border, in the single-window mini.pick style.
- Hint row: separated by a joined rule (H1), right-aligned, with no total count.
- Small windows show just the commands. The agent picks the exact breakpoints.
- Search stays in separate pickers: no tab bar. Code search gets its own shortcut and menus later.

## Rejected run
Run on `loop/picker-ui` was rejected by the judge:
- fix loop exhausted with gates still red: review
- review findings:
  [must-fix] The match counter shows up on the bottom border whenever the picker is in preview or info view. This breaks the picker spec's frame requirement ("SHALL show no match counter") and rule 8.9 of docs/architecture.md (hints and counters never sit on a border).
  - Where: lua/gleb/picker/frame.lua:93-96 and :111. The footer is cleared only inside `create_show`, and that function returns early when `vim.fn.bufwinid(buf) == -1`.
  - Why: mini.pick sets the footer every time it updates the border text (mini/pick.lua:2678-2682: source name plus the `cur|matched|total` counter). In preview or info view the main window shows a different buffer, so `show` never reaches `nvim_win_set_config(win, { footer = "" })`.
  - Reproduced with `make probe`: start `gleb.picker.start({...})` and press `<Tab>` (mini.pick's default toggle_preview). The footer becomes `{ " T ", "────…", " 1|2|2 " }`.
  - Affected pickers: every shared picker that keeps mini.pick's default `<Tab>`/`<S-Tab>` (live grep, references, files, recent files, general `vim.ui.select`). Code actions remap preview to `<M-p>` and are hit through that key.
  - Fix: clear the footer through a path that does not depend on the main buffer being visible, for example a `MiniPickStart` autocmd or updating config on the window itself. Add a scenario that toggles preview.
  - Why earlier passes missed it: all frame and screen tests (tests/screen/picker/test_frame.lua, test_responsive.lua) check only the main view, so the early-return branch was not exercised.
  - Live grep results crash the shared picker's `show`: `lua/gleb/picker/frame.lua:101` wraps mini.pick grep strings as structured rows, while `lua/gleb/picker/rows.lua:35` passes their NUL field separators to Vim string functions and raises `Vim:E976: Using a Blob as a String`. The installed mini.pick source emits those separators and its `default_show` sanitizes them. Existing tests stop before a query produces results.
  - Commit `892ce19` resets cwd after `resession.load` in `lua/gleb/session/init.lua:51`, discarding the cwd restored from the saved session. `tests/integration/session/test_session.lua:109` was changed to expect that regression instead of preserving the existing restore contract.

The remaining work adds result-bearing live-grep coverage, delegates unstructured source rows to mini.pick's safe renderer, restores the session cwd contract, prevents counters in alternate picker views, and leaves the approved picker renders unchanged.
