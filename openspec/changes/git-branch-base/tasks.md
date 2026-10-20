## 1. Hermetic gh and the prbranch fixture

Scenarios: `git: Branch base passes the remote host to gh`

- [x] 1.1 Write the scenario in tests/integration/git/test_base.lua: a fresh `F.copy("prbranch", …)`, `FAKE_GH_LOG` set in the child, and the PATH left as `M.isolate()` makes it. See it fail (`gleb.git.base` is missing).
- [x] 1.2 Add `tests/fixtures/bin/gh` (design.md Decision 6, mode 0755), and prepend `tests/fixtures/bin` to `PATH` in `M.isolate()` (tests/helpers.lua).
- [x] 1.3 Add `prbranch` and `committed_lines` to tests/fixtures/build.sh exactly as design.md "Fixture" gives them, add the name to its header and `case` list, and add the new manifest keys to `fixtures.Manifest` in tests/fixtures.lua. Check that the built manifest equals the one in design.md.
- [x] 1.4 Run `make test FILE=tests/integration/git/test_base.lua` once task 3 lands. Until then the case stays red, and no xfail is needed: it is a new scenario.

## 2. Pure rules

Scenarios: `git: Branch base rules pick the default branch`, `git: Branch base rules parse remote hosts`, `git: Branch base rules list the no-base cases`

- [x] 2.1 Write the three tables of design.md Decision 4 (and the `pr_outcome` rows) in tests/unit/git/test_base_rules.lua, and see them fail.
- [x] 2.2 Add `lua/gleb/git/base/rules.lua`: `remote_host`, `default_branch`, `skip_reason`, `pr_outcome`. It is pure, typed and requires nothing (rule 1.3).
- [x] 2.3 Run `make test FILE=tests/unit/git/test_base_rules.lua` and see it pass.

## 3. Resolver and pull request lookup

Scenarios: `git: Branch base defaults to the remote default branch`, `git: Branch base follows the open pull request`, `git: Branch base uses the pull request base commit when its ref is missing`, `git: Branch base is absent on the default branch`, `git: Branch base is absent on master`, `git: Branch base is absent on a detached HEAD`, `git: Branch base is absent outside a repository`, `git: Branch base is absent without a remote default branch`, `git: Branch base passes the remote host to gh`, `git: Branch base ignores a merged pull request`, `git: Branch base falls back when gh fails`, `git: Branch base works without gh`, `git: Branch base gives up on a slow gh`, `git: Branch base keeps the last pull request when gh fails`, `git: Branch base clears the pull request when none is found`

- [x] 3.1 Write the scenarios in tests/integration/git/test_base.lua. The canned JSON comes from design.md Decision 6 with the manifest oids, and the odd repos from Decision 7. See them fail.
- [x] 3.2 Add `lua/gleb/git/base/init.lua`: the types and API of Decision 1, the steps of Decision 2 and the lookup of Decision 3. Use `vim.system` argument lists with exit-code checks (rule 6.4) and scheduled callbacks that re-check the request is current (rule 6.3). It shows no message (rule 8.4).
- [x] 3.3 Run `make test FILE=tests/integration/git/test_base.lua` and see these pass.

## 4. Cache, watch and refresh

Scenarios: `git: Branch base is cached`, `git: Branch base refreshes after a commit`, `git: Branch base refreshes after a checkout`, `git: Branch base asks gh again after the TTL on focus`, `git: Branch base stops watching on reset`

- [x] 4.1 Write the scenarios in tests/integration/git/test_base.lua. Commits and checkouts run on the host with `H.git` in the copy. Event counts come from a `User GlebGitBaseChanged` recorder autocmd in the child. See them fail.
- [x] 4.2 Implement the cache key, the `pending` coalescing, the TTL, the `FocusGained` augroup `gleb_git_base`, and the git-dir and common-dir watches with their teardown (Decisions 2.7, 3 and 5).
- [x] 4.3 Run the file and see every scenario in it pass.

## 5. Gate

Scenarios: `git: Missing optional git plugins are tolerated`, `git: Git commands are available after startup`

- [x] 5.1 Run `make quick`, then `make check`. `make smoke` must show nothing new in `:messages` and keep the startup budget, because nothing resolves at startup.
- [x] 5.2 `make trace` lists every new scenario as tested.
