## Why
In the neo-tree `git_status` tree, `c` passes whatever the AI popup holds to `git commit`, including the placeholders `# No staged changes` and `# Error: ...` (`git/ai_commit.lua:167-173,184,199`), and `git_commit` reports "Committed:" without checking the result (`file_tree/init.lua:80-87`, `vim.fn.system` with a shell string). When Ollama exits 0 with empty output, nothing updates the popup and its title stays ` 🦙 Generating... ` (`git/ai_commit.lua:65-67`).

Kind: bug

## What Changes
- Popup `<CR>`: drop lines starting with `#` before the emptiness check, so a placeholder-only buffer is never confirmed; `on_commit` gets the text without comment lines.
- Empty Ollama output (exit 0): retitle to ` Commit Message ` and show `# Error: Ollama returned an empty message`.
- `git_commit` runs `git commit -m <message>` via `vim.system` with an argument list, checks the exit code, and on failure notifies `Commit failed: <stderr>` at ERROR instead of "Committed:" (convention 6.4).

## Capabilities
### Modified Capabilities
- `file-tree`: Git status commit and push (exit code checked, failure notified).
- `git`: AI commit message result handling (empty output), AI commit popup actions (comment lines ignored).

## Impact
- Code: `lua/gleb/file_tree/init.lua` (`git_commit`), `lua/gleb/git/ai_commit.lua`
- Plugins: none added, removed or upgraded
- Core keymaps: unchanged
- Out of scope: `<space>` staging (fix-neotree-stage-toggle), `gr`/`c` shadowing (fix-git-status-map-shadowing), the hard-coded Ollama model, `P` push (already checks the code).
