## 1. Remove certainly dead modules and helpers
Scenarios: `actions: Adapter output follows current shortcuts`
- [x] 1.1 Run `make test FILE=tests/integration/actions/test_adapters.lua CASE="Adapter output follows current shortcuts"` and see it pass, delete empty `lua/gleb/database/picker.lua` and uncalled `M.command_list`, run it again and see it pass

## 2. Route folder-status coverage through public rows
Scenarios: `file-tree: Project tree colours changed files`
- [x] 2.1 Run `make test FILE=tests/unit/file-tree/test_model.lua CASE="Project tree colours changed files"` and see it pass, preserve the same precedence assertions through `model.rows` and delete exported `M.folder_status`, run it again and see it pass

## 3. Retire the test-only lazy adapter
Scenarios: `actions: Adapter output follows current shortcuts`, `actions: Adapter reassignment applies on reopen`, `find-action: Shortcut and palette use update recent actions`
- [x] 3.1 Run `make test FILE=tests/integration/actions/test_adapters.lua CASE="Adapter output follows current shortcuts"`, `make test FILE=tests/integration/actions/test_adapters.lua CASE="Adapter reassignment applies on reopen"`, and `make test FILE=tests/integration/find-action/test_run.lua CASE="Shortcut and palette use update recent actions"` and see them pass, move adapter assertions to a remaining production adapter, drive `lazy.close` through its real filetype-scoped mapping from the real picker flow, delete `lua/gleb/actions/adapters/lazy.lua`, then run the three tests again and see them pass

## 4. Correct the stale changes-review fixture
Scenarios: `find-action: Wide palette matches reference screenshots`, `find-action: Compact palette matches reference screenshot`, `find-action: Narrow palette matches reference screenshot`, `find-action: Conflict assignment matches reference screenshot`
- [x] 4.1 Run `make test FILE=tests/screen/find-action/test_palette.lua` and see it pass, rename only the `changes.review` fixture title and category to `Review Changes` and `View | Tool Windows` and update only the affected approved screenshots, then run it again and see it pass

## Agent decisions

- Use the retained blink adapter for stateless reopen coverage because it exercises callback command lists in production.
- Assert folder precedence by row label because public rows are sorted independently of fixture declaration order.
- Keep `watch.stop_all`: it is an explicit integration-test teardown seam that isolates manual refresh from watcher-triggered refresh.
- Keep `diff.engine.compare_words` and `diff.engine.compare_chars`: the golden and property suites deliberately validate the inner algorithms directly.
- Keep `languages.contract.check`: contract scenarios deliberately validate each repository-backed language definition through this seam.
- Keep `actions.audit`: ownership scenarios deliberately inspect the configured live mappings through this public audit seam.
