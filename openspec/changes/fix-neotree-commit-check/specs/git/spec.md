## MODIFIED Requirements

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
