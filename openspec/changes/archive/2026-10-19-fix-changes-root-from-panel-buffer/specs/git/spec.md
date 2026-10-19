# Spec Delta

## MODIFIED Requirements

### Requirement: Changes panel open and close
`<CR>` on an actionable file row SHALL close the panel-owned diff view, edit the file in the editor window and focus it as a listed normal file buffer independent of the panel, keeping the panel open. `q` SHALL close the panel and only its view; editor restoration SHALL remain in `windows.restore`. Buffers loaded only by the panel SHALL be unloaded on close when unmodified.

#### Scenario: Changes panel Enter opens the file
- **WHEN** the diff view shows `b.txt` of the `dirty` fixture and `<CR>` is pressed in normal mode on the `b.txt` panel row
- **THEN** no window with filetype `gleb-diff` remains, the current window edits `b.txt`, and the `gleb-changes` window is still open

#### Scenario: Changes panel file is an independent normal buffer
- **WHEN** the diff view shows `b.txt` of the `dirty` fixture and `<CR>` is pressed in normal mode on the `b.txt` panel row
- **THEN** the current buffer is listed, has empty `buftype`, has the absolute path of `b.txt`, and remains a valid file buffer after the Changes panel closes

#### Scenario: Changes panel q closes the panel and the diff view
- **WHEN** `a.txt` was edited, the changes panel was opened, the diff view shows `b.txt`, and `q` is pressed in normal mode in the panel
- **THEN** no `gleb-changes` or `gleb-diff` window remains, the tab page count is unchanged, and the current window edits `a.txt`

#### Scenario: Changes panel close preserves another diff view
- **WHEN** another diff view exists and `q` closes a Changes panel with its own diff view
- **THEN** the panel-owned view closes and the other diff view remains valid

#### Scenario: Changes panel unloads its clean file buffer
- **WHEN** the panel loaded an otherwise unloaded file for review, the file remains unmodified and `q` closes the panel
- **THEN** that file buffer is unloaded

### Requirement: Changes review workflow
In a repository with staged, unstaged and untracked changes, Cmd+G SHALL resolve the repository from a real directory for file and non-file buffers, then open the changes panel with the diff view of the selected file. In a diff window `]f` SHALL show the panel's next changed file and `]c` SHALL move the cursor to the next change of the current file.

#### Scenario: Cmd+G opens the changes review of a dirty repo
- **WHEN** Neovim runs in a fresh copy of the `dirty` fixture and Cmd+G is pressed as a real key press
- **THEN** the changes panel is the leftmost window of the current tab and lists exactly the fixture manifest's changed files: `a.txt` (staged), `b.txt` and `lib/c.lua` (unstaged), `d.txt` (staged and unstaged) and `new.txt` (untracked), and the editor area shows the diff view of `lib/c.lua`

#### Scenario: Cmd+G from a non-file buffer uses a real directory
- **WHEN** Neovim's working directory is the `dirty` fixture, the current named non-file buffer has no filesystem path, and Cmd+G is pressed
- **THEN** Git runs with an existing directory as its working directory, no `ENOENT` error is reported, and the changes review opens for the `dirty` fixture

#### Scenario: Cmd+G with the project tree open replaces it
- **WHEN** the project tree is open in a dirty repository and Cmd+G is pressed as a real key press
- **THEN** no project-tree window remains and the changes panel and its diff view are open

#### Scenario: ]f steps to the next changed file in the changes review
- **WHEN** the changes review shows a changed file of the `dirty` fixture with a diff window focused and `]` `f` is pressed as a real key press
- **THEN** the diff view shows the next file in the panel's order, and repeating `]` `f` visits every changed file of the manifest once

#### Scenario: ]c steps to the next change in the changes review
- **WHEN** the changes review shows `b.txt` of the `dirty` fixture with the cursor of the right diff window in its first change and `]` `c` is pressed as a real key press
- **THEN** the cursor is on the first changed line of the second hunk from the manifest
