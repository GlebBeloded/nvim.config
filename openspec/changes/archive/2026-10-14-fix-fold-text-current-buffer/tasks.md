## 1. Render fold text from its owning buffer
Scenarios: `folding: Split buffers use their own fold text`
- [x] 1.1 Write the test `folding: Split buffers use their own fold text` in tests/integration/folding/test_fold_text.lua and see it fail
- [x] 1.2 Accept the fold handler context, use its buffer for filetype dispatch, and pass that buffer to the Go and Lua fold-text readers
- [x] 1.3 Run `make test FILE=tests/integration/folding/test_fold_text.lua CASE="Split buffers use their own fold text"` and see it pass
