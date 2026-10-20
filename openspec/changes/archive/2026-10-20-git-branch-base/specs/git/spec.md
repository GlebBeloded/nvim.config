## ADDED Requirements

### Requirement: Branch base resolution
`require("gleb.git.base").resolve(path, callback)` SHALL call back with the base of the repository holding `path`. The base is `origin/<baseRefName>` of the branch's open pull request, else `origin/<default>`, where default is the branch `refs/remotes/origin/HEAD` names, else `main`, else `master`. The result also carries the root, branch, HEAD and `git merge-base <base> HEAD`. The rules SHALL live in `gleb.git.base.rules`, testable without git.

#### Scenario: Branch base defaults to the remote default branch
- **WHEN** a fresh copy of the `prbranch` fixture is on `feat/tax`, the `gh` stub reports no pull request, and `resolve(<copy>/internal/billing/invoice.go, cb)` is called
- **THEN** `cb` receives `root` = the copy, `branch` = `feat/tax`, `head` = the full HEAD oid, `base_ref` = `origin/main`, `merge_base` = the manifest's `merge_base`, `source` = `default` and no `pr`

#### Scenario: Branch base follows the open pull request
- **WHEN** the `gh` stub prints the design.md "Canned pull request" JSON (`number` 482, `state` `OPEN`, `baseRefName` `release/1.4`) and `resolve` is called on the `prbranch` copy
- **THEN** `cb` receives `base_ref` = `origin/release/1.4`, `merge_base` = the manifest's `pr_merge_base`, `source` = `pr`, and `pr.number` = 482 with `pr.url` = `https://pgw.dev/finteqhub/billing/pull/482`

#### Scenario: Branch base uses the pull request base commit when its ref is missing
- **WHEN** `refs/remotes/origin/release/1.4` is deleted from the `prbranch` copy and the `gh` stub prints the canned JSON, whose `baseRefOid` is still in the object store
- **THEN** `cb` receives `base_ref` = `release/1.4`, `base_oid` = the canned `baseRefOid` and `merge_base` = the manifest's `pr_merge_base`

#### Scenario: Branch base rules pick the default branch
- **WHEN** `rules.default_branch(origin_head, refs)` runs over the design.md "Default branch table"
- **THEN** every row returns its expected branch: `origin/develop` names `develop`; no `origin/HEAD` with `origin/main` gives `main`; only `origin/master` gives `master`; no origin refs gives nil

#### Scenario: Branch base rules parse remote hosts
- **WHEN** `rules.remote_host(url)` runs over the design.md "Remote host table"
- **THEN** `git@pgw.dev:finteqhub/billing.git`, `ssh://git@pgw.dev:2222/finteqhub/billing.git` and `https://user@pgw.dev/finteqhub/billing` give `pgw.dev`, `https://github.com/GlebBeloded/nvim.config.git` gives `github.com`, and `/tmp/origin.git`, `file:///tmp/origin.git` and `../origin.git` give nil

### Requirement: Branch base exceptions
There SHALL be no base, and `gh` SHALL not run, outside a repository, on a detached or unborn HEAD, on the remote default branch, on `main` or `master`, without a remote default branch, or when the base and HEAD share no commit. `resolve` then calls back with nil, and no message is shown.

#### Scenario: Branch base is absent on the default branch
- **WHEN** the `prbranch` copy runs `git checkout -q main` and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base is absent on master
- **WHEN** a temp repo whose `refs/remotes/origin/HEAD` points to `origin/develop` is on branch `master` and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base is absent on a detached HEAD
- **WHEN** the `prbranch` copy runs `git checkout -q --detach` and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base is absent outside a repository
- **WHEN** `resolve` is called on a file in a temp directory outside any repository
- **THEN** `cb` receives nil, the `gh` stub log is empty and `:messages` is unchanged

#### Scenario: Branch base is absent without a remote default branch
- **WHEN** a temp repo with commits on `main` and `feat/x` and no remote is on `feat/x` and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base is absent for unrelated histories
- **WHEN** a temp repo's branch and `origin/main` have no common commit and `resolve` is called on it
- **THEN** `cb` receives nil and the `gh` stub log is empty

#### Scenario: Branch base rules list the no-base cases
- **WHEN** `rules.skip_reason(branch, head, default)` runs over the design.md "No-base table"
- **THEN** detached (`branch` nil), unborn (`head` nil), the default branch, `main`, `master` and a missing default return their reason strings, and `feat/tax` with a head and default `main` returns nil

### Requirement: Branch base pull request lookup
The pull request lookup SHALL run `gh pr view --json number,url,state,baseRefName,baseRefOid,headRefName,headRefOid` in the root, with `GH_HOST` set to the `origin` host and prompts off, killed after `GH_TIMEOUT_MS`. Only an `OPEN` result counts. A missing `gh`, a failure or a timeout SHALL fall back silently to the default branch, keeping the last pull request found for that branch; "no pull requests found" clears it.

#### Scenario: Branch base passes the remote host to gh
- **WHEN** `resolve` is called on the `prbranch` copy, whose `origin` URL is `git@pgw.dev:finteqhub/billing.git`
- **THEN** the `gh` stub log has exactly one line: `GH_HOST` `pgw.dev` and the arguments `pr view --json number,url,state,baseRefName,baseRefOid,headRefName,headRefOid`

#### Scenario: Branch base ignores a merged pull request
- **WHEN** the `gh` stub prints the canned JSON with `state` `MERGED` and `resolve` is called on the `prbranch` copy
- **THEN** `cb` receives `base_ref` = `origin/main`, `source` = `default` and no `pr`

#### Scenario: Branch base falls back when gh fails
- **WHEN** the `gh` stub exits 1 with `error connecting to pgw.dev` on stderr and `resolve` is called on the `prbranch` copy
- **THEN** `cb` receives `base_ref` = `origin/main` and `:messages` is unchanged

#### Scenario: Branch base works without gh
- **WHEN** the child's `PATH` holds only a directory with a `git` symlink, so no `gh` is found, and `resolve` is called on the `prbranch` copy
- **THEN** `cb` receives `base_ref` = `origin/main`, and no error is raised or shown

#### Scenario: Branch base gives up on a slow gh
- **WHEN** `GH_TIMEOUT_MS` is set to 200, the `gh` stub sleeps 30 s and `resolve` is called on the `prbranch` copy
- **THEN** within 2 s `cb` receives `base_ref` = `origin/main`, and the stub process is no longer running

#### Scenario: Branch base keeps the last pull request when gh fails
- **WHEN** a first `resolve` finds the canned open pull request, the stub is switched to exit 1 with `error connecting to pgw.dev`, and `refresh(root, { force = true })` runs
- **THEN** `get(root)` still has `pr.number` 482 and `base_ref` `origin/release/1.4`

#### Scenario: Branch base clears the pull request when none is found
- **WHEN** a first `resolve` finds the canned open pull request, the stub is switched back to "no pull requests found", and `refresh(root, { force = true })` runs
- **THEN** `get(root)` has `base_ref` `origin/main` and no `pr`, and `User GlebGitBaseChanged` fired once for the root with `data.root` = the root

### Requirement: Branch base cache and refresh
Results SHALL be cached per root. `get(root)` returns the cache without running a process. They SHALL be refreshed on `FocusGained`, on a change in the git dir (debounced `WATCH_DEBOUNCE_MS`) and by `refresh(root, opts)`. `gh` runs again only after a branch change, with `force`, or once its last answer is older than `PR_TTL_MS`, with at most one run per root at a time. `User GlebGitBaseChanged` SHALL fire only when the result changes.

#### Scenario: Branch base is cached
- **WHEN** `resolve` is called twice on files of the `prbranch` copy and `FocusGained` fires
- **THEN** the `gh` stub log has one line, both callbacks receive equal results, and `User GlebGitBaseChanged` fired once

#### Scenario: Branch base refreshes after a commit
- **WHEN** after a first `resolve`, a commit is made in the `prbranch` copy by a `git commit` outside Neovim
- **THEN** within 2 s `User GlebGitBaseChanged` fires for the root, `get(root).head` is the new HEAD oid, `merge_base` is unchanged, and the `gh` stub log still has one line

#### Scenario: Branch base refreshes after a checkout
- **WHEN** after a first `resolve`, `git checkout -q main` runs in the `prbranch` copy outside Neovim
- **THEN** within 2 s `User GlebGitBaseChanged` fires for the root and `get(root)` is nil

#### Scenario: Branch base asks gh again after the TTL on focus
- **WHEN** `PR_TTL_MS` is set to 0 after a first `resolve` and `FocusGained` fires
- **THEN** the `gh` stub log has two lines

#### Scenario: Branch base stops watching on reset
- **WHEN** a first `resolve` on the `prbranch` copy has started the git-dir watch and `require("gleb.git.base").reset()` runs
- **THEN** `state.roots` is empty and no libuv fs_event handle of the module is active

#### Scenario: Branch base discards stale asynchronous results
- **WHEN** `reset()` removes a root while its pull-request commit check or merge-base check is in flight
- **THEN** the discarded request calls no resolver callback, publishes no event and does not recreate root state
