#!/usr/bin/env sh
# Build a fixture repo for the e2e workflows into .tests/fixtures/<name>-<hash>/
# (repo/ + manifest.json with the facts the tests assert), cached by the hash of
# this script (plus `go version` for gomod). Prints the cache dir.
#   build.sh gomod   stdlib-only Go module, money.Format referenced across packages
#   build.sh dirty   repo with staged, unstaged and untracked changes (differ review)
# Git is hermetic: no user or system config, fixed author, committer and dates.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
name=${1:?usage: build.sh <fixture>}
out="$root/.tests/fixtures"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Fixture GIT_AUTHOR_EMAIL=fixture@example.com GIT_AUTHOR_DATE=2026-01-01T00:00:00Z
export GIT_COMMITTER_NAME=Fixture GIT_COMMITTER_EMAIL=fixture@example.com GIT_COMMITTER_DATE=2026-01-01T00:00:00Z

git() { command git -c init.defaultBranch=main "$@"; }

# $1 message: commit everything
commit() {
	git add -A
	git commit -q -m "$1"
}

# $@ Go files: JSON locations of `Format(` (declaration and calls), file order
format_locations() {
	grep -nE '(^|[^A-Za-z0-9_])Format\(' "$@" | awk '
		{
			file = $0; sub(/:.*/, "", file)
			rest = substr($0, length(file) + 2); line = rest; sub(/:.*/, "", line)
			text = substr(rest, length(line) + 2)
			match(text, /(^|[^A-Za-z0-9_])Format\(/)
			col = RSTART + RLENGTH - 7
			printf "%s{\"path\":\"%s\",\"line\":%d,\"col\":%d}", sep, file, line, col
			sep = ","
		}'
}

gomod() {
	mkdir -p internal/money billing report
	cat >go.mod <<'EOF'
module example.com/fixture

go 1.22
EOF
	cat >internal/money/money.go <<'EOF'
package money

import "fmt"

// Format renders cents as a dollar amount, e.g. 1999 -> "$19.99".
func Format(cents int) string {
	return fmt.Sprintf("$%d.%02d", cents/100, cents%100)
}
EOF
	cat >internal/money/money_test.go <<'EOF'
package money

import "testing"

func TestDollars(t *testing.T) {
	if got := Format(1999); got != "$19.99" {
		t.Fatalf("got %q", got)
	}
}
EOF
	cat >billing/invoice.go <<'EOF'
package billing

import "example.com/fixture/internal/money"

// Invoice is a list of line amounts in cents.
type Invoice struct {
	Lines []int
}

// Due renders the sum of the lines.
func (i Invoice) Due() string {
	total := 0
	for _, cents := range i.Lines {
		total += cents
	}
	return money.Format(total)
}

// Rendered renders every line.
func (i Invoice) Rendered() []string {
	lines := []string{}
	for _, cents := range i.Lines {
		lines = append(lines, money.Format(cents))
	}
	return lines
}
EOF
	cat >report/summary.go <<'EOF'
package report

import "example.com/fixture/internal/money"

// Summary is the one-line report footer.
func Summary(total int) string {
	return "total: " + money.Format(total)
}
EOF
	go build ./... >&2
	go vet ./... >&2
	git init -q
	commit "gomod fixture"
	printf '{"references":{"Format":[%s]}}\n' "$(format_locations internal/money/money.go \
		internal/money/money_test.go billing/invoice.go report/summary.go)" >../manifest.json
}

# stdin: paths, one per line; $1, $2: staged, untracked. JSON fixtures.Entry list items
file_entries() {
	awk -v staged="$1" -v untracked="$2" '
		{ printf "%s{\"path\":\"%s\",\"staged\":%s,\"untracked\":%s}", sep, $0, staged, untracked; sep = "," }'
}

# $1 path: JSON list of the worktree start lines of its unstaged hunks
hunk_starts() {
	git diff -U0 -- "$1" | awk '
		/^@@/ { split($3, new, ","); printf "%s%d", sep, substr(new[1], 2); sep = "," }'
}

# $1 file, $2 line, $3 text: replace line $2 of $1
replace_line() {
	awk -v n="$2" -v text="$3" 'NR == n { $0 = text } { print }' "$1" >"$1.new"
	mv "$1.new" "$1"
}

dirty() {
	git init -q
	printf 'one\ntwo\n' >a.txt
	commit "add a.txt"
	for word in alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau; do
		echo "$word"
	done >b.txt
	mkdir lib
	printf 'local M = {}\n\nreturn M\n' >lib/c.lua
	commit "add b.txt and lib/c.lua"
	printf 'first\nsecond\nthird\n' >d.txt
	commit "add d.txt"
	echo three >>a.txt
	git add a.txt
	replace_line b.txt 2 BETA
	replace_line b.txt 17 RHO
	replace_line lib/c.lua 2 'M.version = 1'
	replace_line d.txt 1 FIRST
	git add d.txt
	replace_line d.txt 3 THIRD
	printf 'new\nuntracked\nfile\n' >new.txt
	staged=$(git diff --cached --name-only | file_entries true false)
	unstaged=$(git diff --name-only | file_entries false false)
	untracked=$(git ls-files --others --exclude-standard | file_entries false true)
	printf '{"files":[%s,%s,%s],"hunks":{"b.txt":[%s]}}\n' "$staged" "$unstaged" "$untracked" \
		"$(hunk_starts b.txt)" >../manifest.json
}

# cache key input: this script, plus the Go toolchain for Go fixtures
key_input() {
	cat "$0"
	case "$name" in
	gomod) go version ;;
	esac
}

case "$name" in
gomod | dirty) ;;
*)
	echo "build.sh: unknown fixture '$name'" >&2
	exit 2
	;;
esac
dir="$out/$name-$(key_input | shasum | cut -c1-12)"
# parallel test workers in a fresh worktree all miss the cache at once: one builds, the others wait
lock="$out/$name.lock"
if [ ! -f "$dir/manifest.json" ]; then
	mkdir -p "$out"
	waited=0
	until mkdir "$lock" 2>/dev/null; do
		[ "$waited" -ge 3000 ] && rm -rf "$lock" # a killed builder's lock, after 5 min
		sleep 0.1
		waited=$((waited + 1))
	done
	trap 'rmdir "$lock" 2>/dev/null' EXIT
	if [ ! -f "$dir/manifest.json" ]; then
		find "$out" -maxdepth 1 -name "$name-*" -exec rm -rf {} +
		mkdir -p "$dir.tmp/repo"
		(cd "$dir.tmp/repo" && "$name")
		mv "$dir.tmp" "$dir"
	fi
fi
echo "$dir"
