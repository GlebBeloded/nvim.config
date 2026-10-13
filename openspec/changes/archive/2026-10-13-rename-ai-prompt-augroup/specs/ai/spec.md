# Spec Delta

## MODIFIED Requirements

### Requirement: Prompt submit keymap
The config SHALL, on `FileType` `99` (augroup `gleb_ai_prompt_keymaps`, cleared on each setup), map `<S-CR>` buffer-locally in normal and insert modes to `<Cmd>write<CR>` with description `99: Submit prompt`, overriding the global `<S-CR>` vibe mapping inside prompt buffers.

#### Scenario: submits with Shift+Enter in normal and insert modes
- **WHEN** `require("gleb.ai.prompt_keymaps").setup()` is called, then `:enew` and `vim.bo.filetype = "99"`
- **THEN** `vim.fn.maparg("<S-CR>", "n")` and `vim.fn.maparg("<S-CR>", "i")` both equal `<Cmd>write<CR>`

#### Scenario: Submit mapping is buffer-local
- **WHEN** after the previous scenario, `:enew` creates a buffer with filetype other than `99`
- **THEN** that buffer has no buffer-local `<S-CR>` mapping

#### Scenario: Setup is idempotent
- **WHEN** `require("gleb.ai.prompt_keymaps").setup()` is called twice
- **THEN** `vim.api.nvim_get_autocmds({ group = "gleb_ai_prompt_keymaps" })` returns exactly one autocmd
