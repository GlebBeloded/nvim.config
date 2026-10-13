# Spec Delta

## ADDED Requirements

### Requirement: Differ review workflow
In a repository with staged, unstaged and untracked changes, Cmd+G SHALL open differ listing every changed file in its panel, and in the diff window `]f` SHALL show the next changed file and `]c` SHALL move the cursor to the next hunk of the current file.

#### Scenario: Cmd+G opens differ listing every change of a dirty repo
- **WHEN** Neovim runs in a fresh copy of the `dirty` fixture and Cmd+G is pressed as a real key press
- **THEN** the differ panel is the leftmost window of the current tab and lists exactly the fixture manifest's changed files: `a.txt` (staged), `b.txt` and `lib/c.lua` (unstaged), `d.txt` (staged and unstaged) and `new.txt` (untracked)

#### Scenario: ]f steps to the next changed file in differ
- **WHEN** differ shows the diff of a changed file of the `dirty` fixture with the diff window focused and `]` `f` is pressed as a real key press
- **THEN** the diff window shows the next file in the panel's order, and repeating `]` `f` visits every changed file of the manifest once

#### Scenario: ]c steps to the next hunk in differ
- **WHEN** differ shows `b.txt` of the `dirty` fixture with the cursor in its first hunk and `]` `c` is pressed as a real key press
- **THEN** the cursor is on the first changed line of the second hunk from the manifest and the diff window's winbar reads `hunk 2/2`
