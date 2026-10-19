## Context

The user wants committed branch changes in purple, a committed-diff view and pull request comments (decision
page, 2026-10-19). All three need the same facts about the current branch: is there an open pull request,
what is its base, and where does the branch fork from it. Today `lua/gleb/git/` has no branch logic. The
changes panel (`changes/git.lua`) compares HEAD with the working tree, and gitsigns compares the index with
the buffer.

Relevant existing pieces:

- `changes/git.lua` runs every git command with `vim.system` (argument lists, `cwd` = root) and schedules
  its callbacks. The base module follows the same pattern (rule 6.4).
- `file_tree/watch.lua` watches the absolute git dir non-recursively for its tree clients. Its owners are
  tree buffers with visible path sets, so it is not reused here (Decision 5).
- The test harness already puts fake programs on a child's `PATH` (`fake_ollama` in
  `tests/integration/git/test_ai_commit.lua`). Nothing stops a child from running the real `gh` today:
  this checkout's `origin` is github.com, and loop branches are not `main`.

## Goals / Non-Goals

**Goals:**
- One async answer per repository root: branch, HEAD, base ref, merge-base and the open pull request, or no
  base.
- Silent degradation: no `gh`, offline, logged out, GHES unreachable or a slow host never shows an error and
  never blocks the editor.
- Cheap refresh: the steady state costs a few read-only git processes per trigger. `gh` runs at most once per
  branch per 5 minutes unless forced.
- Hermetic tests: no case can reach the network.

**Non-Goals:**
- Fetching remote refs, or any write to the repository.
- UI: gutter, tabs, statusline and threads are later changes.
- Remotes other than `origin` (fork workflows with an `upstream` remote).

## Decisions

1. **Module and API.** `lua/gleb/git/base/rules.lua` (pure, no requires) and `lua/gleb/git/base/init.lua`.
   The types are LuaCATS:

   ```lua
   ---@class gleb.git.base.Pr
   ---@field number integer
   ---@field url string
   ---@field base_ref_name string
   ---@field base_ref_oid string
   ---@field head_ref_name string
   ---@field head_ref_oid string
   ---@field host? string GH_HOST used for the lookup

   ---@class gleb.git.base.Info
   ---@field root string normalized repository top level
   ---@field branch string current branch (never nil: a detached HEAD has no Info)
   ---@field head string full HEAD oid
   ---@field default_branch string e.g. "main"
   ---@field base_ref string "origin/<name>", or "<baseRefName>" when only baseRefOid is local
   ---@field base_oid string commit of base_ref
   ---@field merge_base string full oid of `git merge-base <base_oid> <head>`
   ---@field source "pr"|"default"
   ---@field pr? gleb.git.base.Pr
   ```

   `M.resolve(path, callback)` takes a file or directory and calls `callback(info|nil)` through
   `vim.schedule`. It answers from the cache when the root is known and not dirty; otherwise it runs a refresh
   and answers when that ends. `M.get(root)` returns the cached Info or nil and runs nothing. `M.refresh(root,
   opts)` (`opts.force`: ask `gh` regardless of the TTL) re-runs the steps for a root. `M.state` and
   `M.reset()` follow rule 1.5. The tunable constants at the top of `init.lua` are `GH_TIMEOUT_MS = 10000`,
   `PR_TTL_MS = 300000` and `WATCH_DEBOUNCE_MS = 200`. They are exported on `M` so tests can lower them.

2. **Resolution steps** (all `vim.system`, read-only, `cwd` = root, text mode):
   1. Root, once per directory (cached in `state.root_of[dir]`):
      `git rev-parse --show-toplevel --absolute-git-dir --git-common-dir`. A non-zero exit means nil (not a
      repository).
   2. State, five commands in parallel:
      - `git symbolic-ref --quiet --short HEAD` gives the branch. Exit 1 means detached.
      - `git rev-parse --verify --quiet HEAD^{commit}` gives the head oid. Failure means an unborn HEAD.
      - `git symbolic-ref --quiet --short refs/remotes/origin/HEAD` gives e.g. `origin/main`, or fails.
      - `git for-each-ref --format=%(refname:short)%09%(objectname) refs/remotes/origin/` gives every origin
        ref and its oid.
      - `git remote get-url origin` gives the URL, for the host.
   3. `rules.default_branch(origin_head, refs)`: the name after `origin/` of the `origin/HEAD` target, else
      `main` when `origin/main` is in `refs`, else `master` when `origin/master` is, else nil.
   4. `rules.skip_reason(branch, head, default)` returns one of `"detached"`, `"unborn"`, `"no default"`,
      `"default branch"` (`branch == default`, or `branch` is `main` or `master`), or nil. A reason means
      Info nil, and `gh` is not run.
   5. Pull request (Decision 3), when due. With an open pull request the base is `origin/<baseRefName>` from
      `refs`. If that ref is missing and `git cat-file -e <baseRefOid>^{commit}` succeeds, the base is
      `baseRefName` at `baseRefOid`. Otherwise it is the default branch, with `source = "default"`.
   6. Without a pull request the base is `origin/<default>` at its `refs` oid.
   7. The cache key is `(branch, head, base_oid, pr number)`. When it equals the cached key, the cached Info
      stays and nothing more runs. Otherwise `git merge-base <base_oid> <head>` runs, and a failure (unrelated
      histories) means Info nil.
   8. The new Info (or nil) replaces the cache. When it differs from the previous one in any key field
      (branch, head, base_ref, base_oid, merge_base, pr number), `nvim_exec_autocmds("User", { pattern =
      "GlebGitBaseChanged", data = { root = root } })` fires. Nil to nil fires nothing.

3. **Pull request lookup.**
   - Command: `gh pr view --json number,url,state,baseRefName,baseRefOid,headRefName,headRefOid`, `cwd` =
     root, with no branch argument. gh then finds the pull request from the branch's own tracking config, which
     also covers `gh pr checkout` branches.
   - Env (merged into the inherited env): `GH_HOST` = `rules.remote_host(origin url)` when non-nil,
     `GH_PROMPT_DISABLED=1`, `GH_NO_UPDATE_NOTIFIER=1`, `NO_COLOR=1`. `timeout = GH_TIMEOUT_MS` (`vim.system`
     kills the process).
   - It is skipped when `vim.fn.executable("gh") == 0` (`vim.system` would throw).
   - `rules.pr_outcome(code, stdout, stderr)`:
     - exit 0 with JSON whose `state` is `OPEN` and whose `number` and `baseRefName` are set gives
       `{ kind = "open", pr = … }`;
     - exit 0 with any other state, or with invalid JSON, gives `{ kind = "none" }`;
     - stderr matching `no pull requests found` gives `{ kind = "none" }`;
     - anything else (timeout 124, auth, network) gives `{ kind = "failed" }`.
   - `failed` keeps the root's last `open` result for the same branch, if any. `none` clears it.
   - Due when:
     - the branch differs from the last lookup's branch;
     - `opts.force` is set;
     - or the last lookup is older than `PR_TTL_MS` and the refresh came from `FocusGained` or the first
       resolve.
     Watcher refreshes never ask `gh` before the TTL.
   - In flight: one refresh per root at a time. A trigger during a run sets `pending`, and one more run
     follows.

4. **Rules tables** (unit, bare child, no git):
   - **Default branch table:**

     | origin_head | refs | expected |
     |---|---|---|
     | `origin/develop` | `origin/develop`, `origin/main` | `develop` |
     | nil | `origin/main`, `origin/master` | `main` |
     | nil | `origin/master` | `master` |
     | nil | none | nil |

   - **Remote host table:**

     | url | expected |
     |---|---|
     | `git@pgw.dev:finteqhub/billing.git` | `pgw.dev` |
     | `ssh://git@pgw.dev:2222/finteqhub/billing.git` | `pgw.dev` |
     | `https://user@pgw.dev/finteqhub/billing` | `pgw.dev` |
     | `https://github.com/GlebBeloded/nvim.config.git` | `github.com` |
     | `/tmp/origin.git`, `file:///tmp/origin.git`, `../origin.git` | nil |

   - **No-base table:**

     | branch, head, default | expected |
     |---|---|
     | nil, oid, `main` | `detached` |
     | `feat/tax`, nil, `main` | `unborn` |
     | `develop`, oid, `develop` | `default branch` |
     | `main`, oid, `develop` | `default branch` |
     | `master`, oid, `main` | `default branch` |
     | `feat/tax`, oid, nil | `no default` |
     | `feat/tax`, oid, `main` | nil |

   - `rules.pr_outcome`: the canned JSON gives `open`; the same with `MERGED` gives `none`; `{` gives `none`;
     exit 1 with `no pull requests found for branch "feat/tax"` gives `none`; exit 1 with
     `error connecting to pgw.dev` gives `failed`; exit 124 gives `failed`.

5. **Git-dir watch.**
   - On the first successful step 1 of a root, a non-recursive libuv fs_event starts on the absolute git dir,
     and on the common dir when it differs (linked worktrees keep refs and `FETCH_HEAD` there).
   - Commits (`index`, `COMMIT_EDITMSG`, `logs/`), checkouts (`HEAD`), fetches (`FETCH_HEAD`), rebases
     (`ORIG_HEAD`) and `packed-refs` all touch them.
   - Events mark the root dirty and restart a `WATCH_DEBOUNCE_MS` timer that runs `refresh(root)`.
   - The base commands are read-only, so they never trigger the watch themselves.
   - The handles and timers close on `reset()`, on `VimLeavePre`, and when no loaded buffer under the root is
     left (a scheduled check on `BufUnload`), per rule 6.5.
   - `FocusGained` refreshes every known root (augroup `gleb_git_base`).

6. **No network in tests.** `tests/fixtures/bin/gh` is committed and executable. `M.isolate()` in
   `tests/helpers.lua` prepends `tests/fixtures/bin` to `PATH` once per runner, so every child (unit,
   integration, screen, stack, e2e via the runner env) finds the stub first. The stub:

   ```sh
   #!/bin/sh
   # Stand-in for the GitHub CLI in test children: never touches the network.
   # FAKE_GH_LOG: append "<GH_HOST>\t<args>"; FAKE_GH_SLEEP: seconds; FAKE_GH_STDOUT: file printed on
   # stdout (exit FAKE_GH_CODE, default 0); otherwise FAKE_GH_STDERR (default: no pull request) and
   # exit FAKE_GH_CODE (default 1).
   [ -n "${FAKE_GH_LOG:-}" ] && printf '%s\t%s\n' "${GH_HOST:-}" "$*" >>"$FAKE_GH_LOG"
   [ -n "${FAKE_GH_SLEEP:-}" ] && sleep "$FAKE_GH_SLEEP"
   if [ -n "${FAKE_GH_STDOUT:-}" ]; then
   	cat "$FAKE_GH_STDOUT"
   	exit "${FAKE_GH_CODE:-0}"
   fi
   printf '%s\n' "${FAKE_GH_STDERR:-no pull requests found for branch \"$(git branch --show-current)\"}" >&2
   exit "${FAKE_GH_CODE:-1}"
   ```

   Cases set `FAKE_GH_*` in the child with `child.lua("vim.env[...] = ...")`, as the ollama stub cases do.
   **Canned pull request** (written by the case to a temp file, with the oids from the manifest):

   ```json
   {"number":482,"url":"https://pgw.dev/finteqhub/billing/pull/482","state":"OPEN",
    "baseRefName":"release/1.4","baseRefOid":"<manifest pr_merge_base>",
    "headRefName":"feat/tax","headRefOid":"<full HEAD oid>"}
   ```

7. **Integration repos.** Most cases use a fresh `F.copy("prbranch", …)`. The two odd layouts are built in the
   case with `H.git_repo`:
   - "absent on master": `master` checked out, then `git update-ref refs/remotes/origin/develop HEAD` and
     `git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop`;
   - "without a remote default branch": `main` plus `feat/x`, no remote.
   A real remote is never needed, because the base only reads remote-tracking refs.

## Fixture

`prbranch` in `tests/fixtures/build.sh`: add the name to the header list (`build.sh prbranch  billing
branch over origin/main and origin/release/1.4 (branch base, committed signs)`) and to the `case` of known
fixtures, and add these two functions. The text was verified by running it in a scratch dir with the
script's own `git`, `commit`, `replace_line` and `hunk_starts` helpers.

```sh
prbranch() {
	git init -q -b main
	mkdir -p internal/billing internal/money
	printf 'module example.com/billing\n\ngo 1.23\n' >go.mod
	printf '# billing\n\nInvoices, tax and prices.\n' >README.md
	cat >internal/money/money.go <<'GO'
package money

import "fmt"

// Format renders cents as dollars.
func Format(cents int) string {
	return fmt.Sprintf("$%d.%02d", cents/100, cents%100)
}
GO
	cat >internal/billing/invoice.go <<'GO'
package billing

import (
	"fmt"

	"example.com/billing/internal/money"
)

// Invoice is a list of line amounts in cents.
type Invoice struct {
	ID    string
	Lines []int
	Tax   TaxRate
}

// Total sums the lines and applies the tax rate.
func (i Invoice) Total() int {
	total := 0
	for _, cents := range i.Lines {
		total += cents
	}
	return i.Tax.Apply(total)
}

// Due renders the total as dollars.
func (i Invoice) Due() string {
	return fmt.Sprintf("due %s", money.Format(i.Total()))
}
GO
	printf 'package billing\n\n// TaxRate applies a tax to an amount in cents.\ntype TaxRate interface {\n\tApply(cents int) int\n}\n' >internal/billing/rate.go
	commit "billing: invoices"
	git checkout -q -b release/1.4
	sed -i.bak 's/Tax   TaxRate/Tax   Rate/' internal/billing/invoice.go
	sed -i.bak 's/TaxRate/Rate/g' internal/billing/rate.go
	rm internal/billing/*.bak
	commit "billing: rename TaxRate to Rate"
	git checkout -q -b feat/tax
	replace_line internal/billing/invoice.go 18 '	var total int'
	awk 'NR == 22 { print "\tif i.Tax == nil {"; print "\t\treturn total"; print "\t}" } { print }' \
		internal/billing/invoice.go >invoice.new
	mv invoice.new internal/billing/invoice.go
	commit "billing: a nil rate means no tax"
	printf 'package billing\n\n// Flat adds a fixed amount.\ntype Flat struct {\n\tValue int\n}\n\n// Apply implements Rate.\nfunc (r Flat) Apply(cents int) int {\n\treturn cents + r.Value\n}\n' >internal/billing/tax.go
	commit "billing: flat rate"
	git checkout -q main
	printf '# billing\n\nInvoices, tax and prices in cents.\n' >README.md
	commit "docs: cents"
	git checkout -q feat/tax
	# remote-tracking refs as a clone has them; the URL names the real host and is never contacted
	git update-ref refs/remotes/origin/main main
	git update-ref refs/remotes/origin/release/1.4 release/1.4
	git update-ref refs/remotes/origin/feat/tax feat/tax
	git branch -q -D release/1.4
	git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
	git remote add origin git@pgw.dev:finteqhub/billing.git
	git config branch.feat/tax.remote origin
	git config branch.feat/tax.merge refs/heads/feat/tax
	# unstaged: invoice.go line 11
	replace_line internal/billing/invoice.go 11 '	ID    string // invoice number'
	base=$(git merge-base origin/main HEAD)
	printf '{"head":"%s","merge_base":"%s","base":"origin/main","pr_base":"origin/release/1.4","pr_merge_base":"%s","committed":{"internal/billing/invoice.go":%s,"internal/billing/rate.go":%s,"internal/billing/tax.go":%s},"hunks":{"internal/billing/invoice.go":[%s]}}\n' \
		"$(git rev-parse --short=7 HEAD)" "$base" "$(git merge-base origin/release/1.4 HEAD)" \
		"$(committed_lines "$base" internal/billing/invoice.go)" \
		"$(committed_lines "$base" internal/billing/rate.go)" \
		"$(committed_lines "$base" internal/billing/tax.go)" \
		"$(hunk_starts internal/billing/invoice.go)" >../manifest.json
}

# $1 merge-base, $2 path: {"add":[…],"change":[…],"delete":[…]} HEAD lines of the committed hunks
committed_lines() {
	git diff -U0 -M "$1" HEAD -- "$2" | awk '
		function list(name, s) { return "\"" name "\":[" s "]" }
		/^@@/ {
			split($2, o, ","); split($3, n, ",")
			oc = (o[2] == "" ? 1 : o[2]); nc = (n[2] == "" ? 1 : n[2]); start = substr(n[1], 2)
			if (nc == 0) { del = del sd (start == 0 ? 1 : start); sd = "," }
			else for (i = 0; i < nc; i++) {
				if (oc == 0) { add = add sa (start + i); sa = "," } else { chg = chg sc (start + i); sc = "," }
			}
		}
		END { printf "{%s,%s,%s}", list("add", add), list("change", chg), list("delete", del) }'
}
```

The manifest it writes (hashes are stable: fixed author, committer and dates):

```json
{"head":"0d8b572","merge_base":"3176302138f6a74f01090cb14de1b8b802c1a64d","base":"origin/main",
 "pr_base":"origin/release/1.4","pr_merge_base":"ccaa4435dd9528084c5ea7108e139b3648557e72",
 "committed":{"internal/billing/invoice.go":{"add":[22,23,24],"change":[13,18],"delete":[]},
              "internal/billing/rate.go":{"add":[],"change":[3,4],"delete":[]},
              "internal/billing/tax.go":{"add":[1,2,3,4,5,6,7,8,9,10,11],"change":[],"delete":[]}},
 "hunks":{"internal/billing/invoice.go":[11]}}
```

`fixtures.Manifest` (`tests/fixtures.lua`) gains `merge_base?`, `base?`, `pr_base?`, `pr_merge_base?` (strings)
and `committed?` (`table<string, { add: integer[], change: integer[], delete: integer[] }>`). Tests read these
and carry no oids or line literals.

## Risks / Trade-offs

- **Stale base.** The base is the remote-tracking ref as of the last fetch, and the editor never fetches.
  After someone merges into `main` upstream, the purple layer still uses the old merge-base until the user
  fetches. The watch sees `FETCH_HEAD` and refreshes then. This is accepted: no hidden network writes.
- **`gh` cost.** One `gh pr view` is about 0.3-1 s against GHES, off the main loop. It runs at most once per
  branch per 5 minutes, plus forced refreshes. A host that is not GitHub fails fast and falls back, cached by
  the same TTL.
- **Test hermeticity.** If a test child ever ran without the stub, it could reach github.com for this
  checkout's `origin`. `M.isolate()` is the one entry point every layer uses, so the stub is installed there.
  The case "Branch base passes the remote host to gh" relies on the `PATH` from `M.isolate()` alone, so it
  fails if the stub is not first.
- **Screenshots of checkout files.** A screen case that opens a file of this checkout on a loop branch would
  depend on that branch's commits once `git-committed-signs` draws them. No screen case does today
  (`grep -rn "H.root" tests/screen` opens fixtures only, checked 2026-10-19). Change 2 repeats the check.
