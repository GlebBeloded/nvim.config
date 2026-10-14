## 1. Preserve the startup session name after a project cwd change
Scenarios: `session: project cwd change preserves the startup session name`
- [x] 1.1 Write the test `session: project cwd change preserves the startup session name` in tests/integration/session/test_session.lua and see it fail
- [x] 1.2 Capture the session name once in `lua/gleb/session/init.lua` before later cwd changes and reuse it for restore and save
- [x] 1.3 Run `make test FILE=tests/integration/session/test_session.lua CASE="project cwd change preserves the startup session name"` and see it pass
