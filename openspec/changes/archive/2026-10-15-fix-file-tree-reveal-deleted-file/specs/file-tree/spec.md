## ADDED Requirements

### Requirement: Filesystem tree toggle
The normal-mode filesystem tree toggle SHALL reveal an existing current buffer file and SHALL focus the filesystem tree without requesting a reveal when the current buffer path does not exist on disk.

#### Scenario: Toggle tolerates a deleted current file
- **WHEN** an existing file is opened, deleted from disk, and the normal-mode `<A-e>` mapping is pressed
- **THEN** no error is raised and the focused tree uses the `filesystem` source without trying to reveal the deleted path
