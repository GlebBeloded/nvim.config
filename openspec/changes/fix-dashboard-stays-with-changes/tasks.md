## 1. Replace the dashboard during Changes review
Scenarios: `git: Changes panel review replaces the dashboard`
- [x] 1.1 Write the test `git: Changes panel review replaces the dashboard` in `tests/integration/git/test_changes_diff.lua`; start Neovim on the real Alpha dashboard in a populated `dirty` fixture, run the real `changes.review` action, and see the assertion that no window displays an `alpha` buffer fail
- [x] 1.2 Change the Changes panel editor-window selection so its panel-owned diff replaces the dashboard window without changing normal editor selection
- [x] 1.3 Run `make test FILE=tests/integration/git/test_changes_diff.lua CASE="Changes panel review replaces the dashboard"` and see it pass

## Agent decisions

- Prefer Alpha only as an opt-in fallback after normal editor windows, so existing editor selection keeps its priority.
