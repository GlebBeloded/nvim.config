## Review focus

Things the scenarios suggest but don't test directly. Each one is pinned by a step below:
- Ollama exits after the popup was closed with `q`: `jobstop` makes the job exit non-zero, `on_error` writes to a deleted buffer and throws (convention 6.3). Pinned in 2.1 and 2.3.
- Whitespace-only output, not just an empty fence: both inputs are named in the scenario. Pinned in 2.1.
- The commit fails and git writes only to stderr: the notification must carry git's text, not just the prefix. Pinned in 3.1.
- A message with shell metacharacters (`'`, `$`) reaches git verbatim because it is passed as an argument list. Pinned in 3.1.
- Several lines with a body: `Committed:` shows only the subject. Not pinned. A scenario in fill-trace-scenario-gaps should cover it.

## Shared test fixtures

New file `tests/integration/git/test_ai_commit.lua`. Each case gets a fresh child (`H.child_set(child, child.start_config)`), then `child.wait_very_lazy()`. Small typed local helpers:
- `repo(staged: boolean): string`: a temp git repo with one committed file (as in `modified_repo()` of `tests/integration/file-tree/test_tree.lua`), plus `git config user.name/user.email`. When `staged` is true, the file is changed and `git add`ed. The child `cd`s into it.
- `fake_ollama(): string`: a temp dir holding an executable `ollama` shell script. The script drains stdin, sleeps `${FAKE_OLLAMA_SLEEP:-0}`, runs `printf '%b' "$FAKE_OLLAMA_OUT"` and exits `${FAKE_OLLAMA_CODE:-0}`. Each case sets these env vars and prepends the dir to `PATH` in the child (`vim.env.*`), so the unmodified `jobstart` inherits them.
- `open_popup()`: runs `Commits = {}` in the child, then `require("gleb.git.ai_commit").show_commit_input(function(t) table.insert(Commits, t) end)`, and returns the popup winid (the current window after mount).
- `popup_lines(): string[]`, plus `popup_title(): string`, which is the first line of the nui border window's buffer. The border has text, so nui draws it in a separate float.
- `wait_title(" Commit Message ")`: `child.wait` until the title has changed (`ASYNC_MS = 3000`).

## 1. AI commit popup ignores placeholders

Scenarios: "git: Enter on placeholder does nothing", "git: Enter drops comment lines" (regression guards: "git: Enter confirms message", "git: Enter on empty buffer does nothing")

Layer: integration (`tests/integration/git/test_ai_commit.lua`). The popup is the real config's nui popup. Set the buffer's content with `nvim_buf_set_lines` after `open_popup()` in an unstaged repo, so no Ollama runs.

- [x] 1.1 Create the test file and the fixtures above. Add failing tests:
  - `T["git: Enter on placeholder does nothing"]`: for each of `{"# No staged changes"}` (left as is by the unstaged repo) and `{"# Error: Ollama exited with code 1"}`: `type_keys("<CR>")`, then assert the popup window is still valid and `#Commits == 0`.
  - `T["git: Enter drops comment lines"]`: set the buffer to `{"feat: x", "# note"}`, press `<CR>`, then assert the window is invalid and `Commits == {"feat: x"}`.
- [x] 1.2 Add the regression guards: `T["git: Enter confirms message"]` (buffer `{"feat: x  "}`, expect `{"feat: x"}` and the window closed) and `T["git: Enter on empty buffer does nothing"]` (buffer `{""}`).
- [x] 1.3 Run `make test FILE=tests/integration/git/test_ai_commit.lua`. Confirm that the 1.1 cases fail on the `Commits` assertion and that the 1.2 cases pass.
- [x] 1.4 In `lua/gleb/git/ai_commit.lua`, make `get_text()` a typed local (`---@return string`) that skips lines matching `^#` before the right-trim and the whole-text trim (design, "Comment lines are dropped"). Leave the `<CR>` map unchanged.
- [x] 1.5 The four cases pass. Run `make quick`.

## 2. Empty Ollama output retitles the popup

Scenarios: "git: Empty Ollama output is shown" (regression guards: "git: Generated message fills popup", "git: Popup resizes to content", "git: Ollama failure is shown", "git: q discards popup")

Layer: integration (same file). Use a staged repo with `fake_ollama()`.

- [x] 2.1 Add the failing tests:
  - `T["git: Empty Ollama output is shown"]`: run it once with `FAKE_OLLAMA_OUT="\`\`\`\n\`\`\`\n"` and once with `"  \n"`, each with exit 0. Each time, `wait_title(" Commit Message ")`, then assert `popup_lines() == {"# Error: Ollama returned an empty message"}`.
  - `T["git: q discards popup"]`: set `FAKE_OLLAMA_SLEEP=1` and `open_popup()`. Press `q` and assert the window is invalid. Let the stopped job's `on_exit` run with `child.lua("vim.wait(500)")`. Then assert `#Commits == 0` and that `v:errmsg` is `""` (the deleted-buffer error from Review focus).
- [x] 2.2 Add the regression guards:
  - `T["git: Generated message fills popup"]`: `FAKE_OLLAMA_OUT="\`\`\`\nfeat(git): add x\n\`\`\`\n"`, expect lines `{"feat(git): add x"}` and title ` Commit Message `.
  - `T["git: Popup resizes to content"]`: set `columns` to 200, use a one-line output, then assert `nvim_win_get_width == 72` and height 1.
  - `T["git: Ollama failure is shown"]`: `FAKE_OLLAMA_CODE=1`, expect `{"# Error: Ollama exited with code 1"}` and the title.
- [x] 2.3 Run the file. The empty-output case must fail on `wait_title` (the title stays ` 🦙 Generating... `) and `q discards popup` on `v:errmsg`. The 2.2 cases must pass.
- [x] 2.4 In `call_ai`'s exit handler, when the cleaned response is empty, call `on_error("Ollama returned an empty message")` (design, "Empty output goes through on_error"). In `show_commit_input`, the error callback returns early unless `vim.api.nvim_buf_is_valid(bufnr)`, the same guard the success callback has (convention 6.3).
- [x] 2.5 Both new cases and the guards pass. In a child at 80x24, check the popup against the Proposed render in design.md with `MONO=1 make render`, or with `H.screen_rows` in a scratch run. Run `make quick`.

## 3. git_commit checks the exit code

Scenarios: "file-tree: c reports commit failure" (regression guard: "file-tree: c commits confirmed message")

Layer: integration (`tests/integration/file-tree/test_tree.lua`, tree mappings).

- [ ] 3.1 Add the failing tests. Setup is shared through a typed local `commit_from_tree(message: string)`:
  - Take `modified_repo()`, `git add a.txt`, and set user.name/email in the repo config.
  - `cd` the child into it. Set `Notes = {}` and wrap `vim.notify` to record `{ msg, level }`.
  - Stub `require("gleb.git.ai_commit").show_commit_input = function(cb) cb(<message>) end`.
  - Run `:Neotree git_status`, wait for `a.txt`, then `type_keys("c")`.

  The cases:
  - `T["file-tree: c reports commit failure"]`: write an executable `.git/hooks/pre-commit` that runs `echo "hook says no" >&2; exit 1`. Then `commit_from_tree("feat: x")` and wait for a note starting `Commit failed:`. Assert that it is `{ "Commit failed: hook says no", ERROR }`, that no note starts with `Committed:`, and that `git log -1 --format=%s` is still `init`.
  - `T["file-tree: c commits confirmed message"]`: `commit_from_tree("feat: x")`, wait for a note `{ "Committed: feat: x", INFO }`, then assert `git log -1 --format=%s` is `feat: x`. Run a second commit in the same case (stage a new change, message `fix: it's $HOME`) and assert the subject is the same string verbatim.
- [ ] 3.2 Run `make test FILE=tests/integration/file-tree/test_tree.lua`. The failure case must fail, because `Committed: feat: x` is emitted. The success case must pass.
- [ ] 3.3 In `lua/gleb/file_tree/init.lua`, add these named locals:
  - `---@param msg string`, `---@param result vim.SystemCompleted`, `local function on_commit_exit(msg, result)`. It runs inside `vim.schedule`. On `result.code == 0`: `refresh("git_status")` and `vim.notify("Committed: " .. <first line>, INFO)`. Otherwise: `vim.notify("Commit failed: " .. <trimmed stderr, else trimmed stdout, else "exit " .. code>, ERROR)`.
  - `---@param msg string`, `local function run_commit(msg)`. It calls `vim.system({ "git", "commit", "-m", msg }, { text = true }, function(r) on_commit_exit(msg, r) end)`.

  `git_commit` then passes `run_commit` to `show_commit_input` (design, "git_commit uses async vim.system"; convention 6.4, 8.3).
- [ ] 3.4 Both cases and the existing tree cases pass. Run `make quick`.

## 4. Integration

- [ ] 4.1 `VERBOSE=1 make trace` lists the 11 scenarios named in tasks 1–3 as `tested`, and there are no orphans. "P pushes successfully", "P reports push failure" and "Leaving popup closes it" stay with `fill-trace-scenario-gaps`.
- [ ] 4.2 `make check` is green.

## Notes

- 2.3: "Generated message fills popup" also failed: `on_stdout` dropped empty chunks and joined lines with `""`, so the fence strip ate `feat`. Fixed with `stdout_buffered = true` and joining with `"\n"`.
- 2.4: `nvim_buf_is_valid(bufnr)` is not enough. When the popup opens over the alpha dashboard, alpha's `BufUnload` autocmd aborts nui's `nvim_buf_delete`, so `bufnr` stays valid after `q`. Both callbacks check `is_open()` (the popup window, which nui nils on unmount) instead.
- 2.5: the 80x24 render matches the Proposed one (width 64, height 1, same text). It sits at rows 10-12, col 9, because nui keeps the anchor from before the resize.
