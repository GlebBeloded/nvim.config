## 1. Size code-action popups from displayed content
Scenarios: `select: Code action popup fits editor width`
- [x] 1.1 Write the test `select: Code action popup fits editor width` in `tests/unit/select/test_code_action.lua` with an 80-column child and short and long formatted items, then run it and see the hard-coded width fail
- [x] 1.2 Replace the constant width with the widest formatted item or prompt measured by `vim.fn.strdisplaywidth`, add two columns of padding, and cap it at `vim.o.columns - 4`
- [x] 1.3 Run `make test FILE=tests/unit/select/test_code_action.lua CASE="Code action popup fits editor width"` and see it pass

## 2. Exercise cancellation through the mounted menu
Scenarios: `select: Cancelling a code action completes selection`
- [x] 2.1 Tighten the test `select: Cancelling a code action completes selection` in `tests/unit/select/test_code_action.lua` to mount the real menu and press `<Esc>`; with a temporary fault removing `<Esc>` from the close mapping, run it, see it fail and record the failure, then remove the fault
- [x] 2.2 Keep the existing cancellation callback semantics and replace the test's direct `on_close()` call with mounted-menu key input
- [x] 2.3 Run `make test FILE=tests/unit/select/test_code_action.lua CASE="Cancelling a code action completes selection"` and see it pass
