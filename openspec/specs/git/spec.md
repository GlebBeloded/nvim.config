# git Specification

## Purpose
Git integration loaded from `lua/gleb/git/`: gutter signs, unified/split diff viewers (differ.nvim, diffview.nvim, vscode-diff), permalink copying via `:Gitlink`, and an AI-generated commit message popup.

## Requirements

### Requirement: Module loading
`require("gleb.git")` SHALL load, in order, the gitsigns, differ, diffview and gitlink configurations. The vscode-diff configuration SHALL be loaded by lazy.nvim when that plugin loads. The gitsigns, differ, diffview and vscode-diff configurations SHALL return without error when their plugin cannot be required.

#### Scenario: Missing optional git plugins are tolerated
- **WHEN** `require("gleb.git.gitsigns")`, `require("gleb.git.differ")`, `require("gleb.git.diffview")` and `require("gleb.git.vscode_diff")` are called with those plugins absent from the runtimepath
- **THEN** no error is raised

#### Scenario: Git commands are available after startup
- **WHEN** Neovim starts with the full config
- **THEN** user commands `Gitsigns`, `Differ`, `DiffviewOpen` and `Gitlink` exist (`vim.fn.exists(":<cmd>") == 2`)

### Requirement: Gutter signs
The config SHALL show git hunk signs in the sign column using `┃` for added, untracked, changed and changed-deleted lines and `` for deleted and top-deleted lines, with number highlighting, line highlighting, word diff and current-line blame disabled by default.

#### Scenario: Added line shows bar sign
- **WHEN** a tracked file is edited to add a new line and gitsigns has refreshed the buffer
- **THEN** the sign column on that line shows `┃`

#### Scenario: Blame is off by default
- **WHEN** a tracked file is opened and the cursor rests on a line for more than 300 ms
- **THEN** no blame virtual text is shown at end of line

### Requirement: Differ viewer
The config SHALL set up differ.nvim with split (side-by-side) layout, 3 lines of context, word-granularity deep diff, and a file panel on the left, 35 columns wide, listing files as a tree.

#### Scenario: Differ opens panel on the left
- **WHEN** `:Differ` is executed in a repository with working-tree changes
- **THEN** a new panel window is the leftmost window of the current tab with width 35 listing the changed files as a tree

### Requirement: Diffview viewer
The config SHALL set up diffview.nvim with enhanced diff highlighting, `diff2_horizontal` layout for diffs, `diff3_mixed` for merges, and a left file panel 35 columns wide with tree listing, flattened directories and folder statuses only when folded.

#### Scenario: Diffview file panel on the left
- **WHEN** `:DiffviewOpen` is executed in a repository with working-tree changes
- **THEN** the leftmost window of the new tab is the file panel with width 35

### Requirement: Diffview view mappings
In diffview diff windows the config SHALL map, in normal mode, `<tab>`/`<s-tab>` to next/previous entry, `gf` to edit the file, `<D-o>` (Cmd+O), `<D-i>` (Cmd+I), `<D-d>` (Cmd+D), `<D-a>` (Cmd+A) to choose ours/theirs/base/all conflict versions and `dx` to choose none.

#### Scenario: tab moves to next entry
- **WHEN** `:DiffviewOpen` shows two changed files, focus is in a diff window of the first, and `<tab>` is pressed in normal mode
- **THEN** the diff windows show the second file

#### Scenario: dx drops both conflict sides
- **WHEN** `:DiffviewOpen` is open on a file with a merge conflict, the cursor is inside a conflict in a diff window, and `dx` is pressed in normal mode
- **THEN** the conflict markers and both sides are removed from the working-file buffer

#### Scenario: Cmd+O chooses ours
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<D-o>` is pressed in normal mode
- **THEN** the working-file buffer holds `ours` in place of the conflict and no conflict marker remains

#### Scenario: Cmd+I chooses theirs
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<D-i>` is pressed in normal mode
- **THEN** the working-file buffer holds `theirs` in place of the conflict and no conflict marker remains

#### Scenario: Cmd+D chooses base
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<D-d>` is pressed in normal mode
- **THEN** the working-file buffer holds `base` in place of the conflict and no conflict marker remains

#### Scenario: Cmd+A chooses all
- **WHEN** `:DiffviewOpen` is open on a file with a diff3 merge conflict (ours `ours`, base `base`, theirs `theirs`), the cursor is inside the conflict in a diff window, and `<D-a>` is pressed in normal mode
- **THEN** the working-file buffer holds `ours`, `base`, `theirs` in that order in place of the conflict and no conflict marker remains

### Requirement: Diffview file panel mappings
In the diffview file panel the config SHALL map, in normal mode, `j`/`<tab>` to next entry, `k`/`<s-tab>` to previous entry, `<cr>`/`o`/`l` to select the entry, `h` to close a fold, `s` to toggle staging, `S` to stage all, `U` to unstage all, `R` to refresh and `q` to run `:DiffviewClose`.

#### Scenario: q closes diffview from file panel
- **WHEN** `:DiffviewOpen` is open, focus is in the file panel, and `q` is pressed in normal mode
- **THEN** the diffview tab is closed and the tab page count returns to its previous value

#### Scenario: s stages entry from file panel
- **WHEN** the cursor is on an unstaged file entry in the diffview file panel and `s` is pressed in normal mode
- **THEN** the file appears in `git diff --cached --name-only`

### Requirement: vscode-diff configuration
When vscode-diff loads, the config SHALL call its setup with the explorer positioned left, 35 columns wide, in tree view mode, keeping the plugin's default diff keymaps.

#### Scenario: vscode-diff setup runs on plugin load
- **WHEN** lazy.nvim loads `vscode-diff.nvim`
- **THEN** `require("gleb.git.vscode_diff")` has been executed without error

### Requirement: Gitlink permalink command
The config SHALL configure gitlinker with no default mappings, without printing the URL, and with host `pgw.dev` producing GitHub-style URLs. It SHALL define the `:Gitlink` command accepting a range: without a range it copies the URL for the current line, with a range it copies the URL for the inclusive line endpoints supplied to the command; the URL SHALL be copied to the `+` register.

#### Scenario: Gitlink copies current line URL
- **WHEN** `:Gitlink` is executed in a tracked file of a repository with a GitHub remote, cursor on line 10
- **THEN** register `+` contains a blob URL for the current commit and file ending in `#L10`

#### Scenario: Gitlink copies range URL
- **WHEN** lines 3-5 are selected in visual mode and `:'<,'>Gitlink` is executed
- **THEN** register `+` contains a blob URL ending in `#L3-L5`

#### Scenario: pgw.dev remote uses GitHub URL format
- **WHEN** `:Gitlink` is executed in a repository whose `origin` remote is on host `pgw.dev`
- **THEN** register `+` contains a URL of the form `https://pgw.dev/<owner>/<repo>/blob/<sha>/<path>#L<n>`

### Requirement: AI commit message popup
`require("gleb.git.ai_commit").show_commit_input(on_commit)` SHALL open and focus a centered, rounded floating window (initially 60x3, filetype `gitcommit`, `wrap` on) titled ` 🦙 Generating... ` with footer ` <CR> ✓ │ i edit │ q ✗ `. If `git diff --cached` is empty it SHALL retitle to ` Commit Message `, set the buffer to `# No staged changes` and spawn nothing.

#### Scenario: No staged changes
- **WHEN** `show_commit_input(cb)` is called with nothing staged
- **THEN** the current window is a floating window whose buffer is `{"# No staged changes"}` with filetype `gitcommit`, its title is ` Commit Message `, and no `ollama` job is started

### Requirement: AI commit message generation
With staged changes, the popup SHALL spawn `ollama run tavernari/git-commit-message:sp_commit_mini`, write to its stdin a prompt asking for a `<type>(<scope>): <description>` message under 50 chars followed by the staged diff (first 200 lines plus `... (truncated)` when longer), and close stdin.

#### Scenario: Ollama is spawned with staged diff
- **WHEN** `show_commit_input(cb)` is called with staged changes
- **THEN** a job `ollama run tavernari/git-commit-message:sp_commit_mini` is started and its stdin receives a prompt containing the output of `git diff --cached`

#### Scenario: Long diff is truncated
- **WHEN** `show_commit_input(cb)` is called with a staged diff longer than 200 lines
- **THEN** the prompt sent to the job contains only the first 200 diff lines followed by `... (truncated)`

### Requirement: AI commit message result handling
When the job exits 0 with non-empty output, the config SHALL strip surrounding Markdown code fences and whitespace, put the result lines in the popup buffer and resize the popup to width min(72, 80% of `columns`) and the wrapped line count capped at 10. On exit 0 with empty output the buffer SHALL be `# Error: Ollama returned an empty message`; on a non-zero exit it SHALL be `# Error: Ollama exited with code <code>`. In all cases the title SHALL become ` Commit Message `.

#### Scenario: Generated message fills popup
- **WHEN** the spawned job prints "```\nfeat(git): add x\n```" and exits 0
- **THEN** the popup buffer is `{"feat(git): add x"}` and its title is ` Commit Message `

#### Scenario: Popup resizes to content
- **WHEN** the spawned job prints a one-line message and exits 0 with `columns` = 200
- **THEN** the popup window width is 72 and height is 1

#### Scenario: Ollama failure is shown
- **WHEN** the spawned job exits with code 1
- **THEN** the popup buffer is `{"# Error: Ollama exited with code 1"}` and its title is ` Commit Message `

#### Scenario: Empty Ollama output is shown
- **WHEN** the spawned job prints only whitespace or an empty code fence and exits 0
- **THEN** the popup buffer is `{"# Error: Ollama returned an empty message"}` and its title is ` Commit Message `

### Requirement: AI commit popup actions
In the popup, normal-mode `<CR>` SHALL drop every line starting with `#`, right-trim the remaining lines and trim the whole text; if that text is non-empty it SHALL close the popup and call `on_commit(text)`, otherwise the popup stays open and `on_commit` is not called. Normal-mode `q` and leaving the popup buffer (`BufLeave`) SHALL close the popup and stop a running AI job without calling `on_commit`.

#### Scenario: Enter confirms message
- **WHEN** the popup buffer contains `feat: x  ` and `<CR>` is pressed in normal mode
- **THEN** the popup window is closed and `on_commit` is called once with `feat: x`

#### Scenario: Enter on empty buffer does nothing
- **WHEN** the popup buffer is empty and `<CR>` is pressed in normal mode
- **THEN** the popup stays open and `on_commit` is not called

#### Scenario: Enter on placeholder does nothing
- **WHEN** the popup buffer is `{"# No staged changes"}` or `{"# Error: Ollama exited with code 1"}` and `<CR>` is pressed in normal mode
- **THEN** the popup stays open and `on_commit` is not called

#### Scenario: Enter drops comment lines
- **WHEN** the popup buffer is `{"feat: x", "# note"}` and `<CR>` is pressed in normal mode
- **THEN** the popup window is closed and `on_commit` is called once with `feat: x`

#### Scenario: q discards popup
- **WHEN** `q` is pressed in normal mode in the popup while the AI job is running
- **THEN** the popup window is closed, the job is stopped and `on_commit` is not called

#### Scenario: Leaving popup closes it
- **WHEN** focus leaves the popup buffer with `:wincmd p`
- **THEN** the popup window is closed and `on_commit` is not called
