#!/usr/bin/env sh
# Build a fixture repo for the e2e workflows into .tests/fixtures/<name>-<hash>/
# (repo/ + manifest.json with the facts the tests assert), cached by the hash of
# this script (plus `go version` for gomod). Prints the cache dir.
#   build.sh gomod   stdlib-only Go module, money.Format referenced across packages
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

# cache key input: this script, plus the Go toolchain for Go fixtures
key_input() {
	cat "$0"
	case "$name" in
	gomod) go version ;;
	esac
}

case "$name" in
gomod) ;;
*)
	echo "build.sh: unknown fixture '$name'" >&2
	exit 2
	;;
esac
dir="$out/$name-$(key_input | shasum | cut -c1-12)"
if [ ! -f "$dir/manifest.json" ]; then
	rm -rf "$out/$name"-*
	mkdir -p "$dir.tmp/repo"
	(cd "$dir.tmp/repo" && "$name")
	mv "$dir.tmp" "$dir"
fi
echo "$dir"
