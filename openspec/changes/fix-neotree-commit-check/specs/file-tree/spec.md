## MODIFIED Requirements

### Requirement: Git status commit and push
In the `git_status` tree, normal-mode `c` SHALL open the AI commit popup (`gleb.git.ai_commit`) and run `git commit -m <message>` as an argument list for a confirmed message; on exit 0 it SHALL refresh the `git_status` source and notify `Committed: <first line of message>` at INFO, otherwise notify `Commit failed: <git stderr>` at ERROR. Normal-mode `P` SHALL notify `Pushing...` at INFO, run `git push` asynchronously, then notify `Pushed successfully` (INFO) on exit 0 or `Push failed` (ERROR).

#### Scenario: c commits confirmed message
- **WHEN** `c` is pressed in normal mode in the `git_status` tree and the popup is confirmed with message `feat: x`
- **THEN** `git commit -m 'feat: x'` is run, `git log -1 --format=%s` is `feat: x`, and a notification `Committed: feat: x` at INFO is emitted

#### Scenario: c reports commit failure
- **WHEN** `c` is pressed in normal mode in the `git_status` tree, the popup is confirmed with message `feat: x`, and `git commit` exits non-zero (e.g. a failing `pre-commit` hook)
- **THEN** a notification starting with `Commit failed:` at ERROR is emitted, no notification starting with `Committed:` is emitted, and `git log -1 --format=%s` is unchanged

#### Scenario: P pushes successfully
- **WHEN** `P` is pressed in normal mode in the `git_status` tree and `git push` exits 0
- **THEN** notifications `Pushing...` (INFO) then `Pushed successfully` (INFO) are emitted

#### Scenario: P reports push failure
- **WHEN** `P` is pressed in normal mode in the `git_status` tree and `git push` exits non-zero
- **THEN** notifications `Pushing...` (INFO) then `Push failed` (ERROR) are emitted
