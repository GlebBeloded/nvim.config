## Why
When Ollama answers with a fenced message ("```\nfeat(git): add x\n```"), the popup shows `(git): add x` instead of `feat(git): add x` (case `git: Generated message fills popup`, `tests/unit/git/test_ai_commit.lua`). `call_ai` in `lua/gleb/git/ai_commit.lua:44-51` keeps the non-empty items of each `on_stdout` list and joins them with `""` (`:61`), so the line breaks a job channel splits on are lost and the text becomes "```feat(git): add x```". The fence strip at `:63` (`^%s*```[%w]*%s*`) then reads `feat` as the fence's language tag and removes it. The same join also glues a multi-line answer into one line and breaks a line that arrives split across two `on_stdout` calls.

Kind: bug

## What Changes
- Job output is reassembled as the channel delivers it (`:h channel-lines`: the last item of each `on_stdout` list continues in the next call's first item), so newlines are kept.
- The opening fence is stripped only as a whole line (```` ``` ```` plus an optional language tag up to the newline); the closing fence likewise.
- The xfail on `git: Generated message fills popup` is removed.

## Capabilities
### Modified Capabilities
- None: the `git` spec already requires `{"feat(git): add x"}` (scenario "Generated message fills popup"); this change makes the code meet it.

## Impact
- Code: `lua/gleb/git/ai_commit.lua` (`call_ai`), `tests/unit/git/test_ai_commit.lua`.
- Plugins: none added, removed or upgraded.
- Core keymaps: unchanged.
- Out of scope: empty output and comment lines (fix-neotree-commit-check), the hard-coded Ollama model.
