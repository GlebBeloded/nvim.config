## 1. Exercise ufo's real fold render
Scenarios: `folding: Split buffers use their own fold text`
- [x] 1.1 Add or tighten the assertion in `tests/integration/folding/test_fold_text.lua` by opening Go and Lua buffers in a split, closing a fold in each, letting ufo render both folds, and asserting handler-specific text; with a temporary fault (use the current buffer's filetype instead of the rendered buffer's filetype in the fold handler) run `make test FILE=tests/integration/folding/test_fold_text.lua CASE="Split buffers use their own fold text"`, see it fail and record the failure, then remove the fault
  - Red: the current-buffer fault made the non-current Lua fold assertion return `false`.
- [x] 1.2 Run `make test FILE=tests/integration/folding/test_fold_text.lua CASE="Split buffers use their own fold text"` and see it pass

## 2. Annotate folding handlers
Scenarios: `folding: Split buffers use their own fold text`
- [x] 2.1 Run `make test FILE=tests/integration/folding/test_fold_text.lua CASE="Split buffers use their own fold text"` and see it pass, add LuaCATS class, parameter, and return annotations for the handler modules and their `bufnr` parameter in `lua/gleb/folding/go.lua` and `lua/gleb/folding/lua.lua`, then run it again and see it pass
