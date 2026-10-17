#!/usr/bin/env sh
# Build a fixture repo for the e2e workflows into .tests/fixtures/<name>-<hash>/
# (repo/ + manifest.json with the facts the tests assert), cached by the hash of
# this script (plus `go version` for gomod). Prints the cache dir.
#   build.sh gomod   stdlib-only Go module, money.Format referenced across packages
#   build.sh luaproj Lua module with production and spec usages
#   build.sh pyproj  Python package with production and test usages
#   build.sh tsproj  TypeScript project with production and test usages
#   build.sh rustproj Rust crate with production, integration and inline test usages
#   build.sh bashproj Bash project with production and test-script usages
#   build.sh tfproj  Terraform module with variable usages
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

# $1 identifier, $@ files: JSON locations of each identifier, in file order
identifier_locations() {
	identifier=$1
	shift
	grep -nE "(^|[^A-Za-z0-9_])$identifier([^A-Za-z0-9_]|$)" "$@" | awk -v identifier="$identifier" '
		{
			file = $0; sub(/:.*/, "", file)
			rest = substr($0, length(file) + 2); line = rest; sub(/:.*/, "", line)
			text = substr(rest, length(line) + 2)
			col = index(text, identifier)
			printf "%s{\"path\":\"%s\",\"line\":%d,\"col\":%d}", sep, file, line, col
			sep = ","
		}'
}

luaproj() {
	mkdir -p lua/shop spec
	cat >.luarc.json <<'EOF'
{
  "runtime.path": ["lua/?.lua", "lua/?/init.lua"]
}
EOF
	cat >lua/shop/price.lua <<'EOF'
local M = {}

function M.total(price, quantity)
	return price * quantity
end

return M
EOF
	cat >lua/shop/cart.lua <<'EOF'
local price = require("shop.price")

return price.total(10, 2)
EOF
	cat >spec/price_spec.lua <<'EOF'
local price = require("shop.price")

assert(price.total(10, 2) == 20)
EOF
	git init -q
	commit "Lua references fixture"
	printf '{"references":{"total":[%s]}}\n' \
		"$(identifier_locations total lua/shop/price.lua lua/shop/cart.lua spec/price_spec.lua)" >../manifest.json
}

pyproj() {
	mkdir -p shop tests
	cat >pyproject.toml <<'EOF'
[project]
name = "fixture-shop"
version = "0.0.0"
requires-python = ">=3.10"
EOF
	: >shop/__init__.py
	cat >shop/price.py <<'EOF'
def total(price: int, quantity: int) -> int:
    return price * quantity
EOF
	cat >shop/cart.py <<'EOF'
from shop import price


def cart_total() -> int:
    return price.total(10, 2)
EOF
	cat >tests/test_price.py <<'EOF'
from shop import price


def test_total() -> None:
    assert price.total(10, 2) == 20
EOF
	python3 -m py_compile shop/__init__.py shop/price.py shop/cart.py tests/test_price.py
	rm -rf shop/__pycache__ tests/__pycache__
	git init -q
	commit "Python references fixture"
	printf '{"references":{"total":[%s]}}\n' \
		"$(identifier_locations total shop/price.py shop/cart.py tests/test_price.py)" >../manifest.json
}

tsproj() {
	mkdir -p src
	cat >package.json <<'EOF'
{
  "name": "fixture-shop",
  "private": true,
  "type": "module"
}
EOF
	cat >eslint.config.js <<'EOF'
export default [];
EOF
	cat >tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "module": "ESNext",
    "moduleResolution": "Node",
    "noEmit": true,
    "target": "ES2022"
  },
  "include": ["src/**/*.ts"]
}
EOF
	cat >src/price.ts <<'EOF'
export function total(price, quantity) {
  return price * quantity;
}
EOF
	cat >src/cart.ts <<'EOF'
import * as price from "./price";

export function cartTotal() {
  return price.total(10, 2);
}
EOF
	cat >src/price.test.ts <<'EOF'
import * as price from "./price";

export const expected = price.total(10, 2);
EOF
	if command -v tsc >/dev/null 2>&1; then
		tsc --noEmit
	else
		for file in eslint.config.js src/price.ts src/cart.ts src/price.test.ts; do
			node --check --input-type=module <"$file"
		done
	fi
	git init -q
	commit "TypeScript references fixture"
	printf '{"references":{"total":[%s]}}\n' \
		"$(identifier_locations total src/price.ts src/cart.ts src/price.test.ts)" >../manifest.json
}

rustproj() {
	mkdir -p src tests
	cat >Cargo.toml <<'EOF'
[package]
name = "rustproj"
version = "0.1.0"
edition = "2021"
EOF
	cat >src/lib.rs <<'EOF'
pub mod price;
EOF
	cat >src/price.rs <<'EOF'
pub fn total(price: i32, quantity: i32) -> i32 {
    price * quantity
}

#[cfg(test)]
mod tests {
    #[test]
    fn totals_a_cart() {
        assert_eq!(super::total(10, 2), 20);
    }
}
EOF
	cat >src/main.rs <<'EOF'
use rustproj::price;

fn main() {
    println!("{}", price::total(10, 2));
}
EOF
	cat >tests/price.rs <<'EOF'
use rustproj::price;

#[test]
fn totals_a_cart() {
    assert_eq!(price::total(10, 2), 20);
}
EOF
	cargo check --all-targets >&2
	git init -q
	commit "Rust references fixture"
	printf '{"references":{"total":[%s]}}\n' \
		"$(identifier_locations total src/price.rs src/main.rs tests/price.rs)" >../manifest.json
}

bashproj() {
	mkdir -p lib bin test
	cat >lib/price.sh <<'EOF'
#!/usr/bin/env bash
total() {
	printf '%s\n' "$(($1 * $2))"
}
EOF
	cat >bin/run.sh <<'EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/price.sh"

total 10 2
EOF
	cat >test/price_test.sh <<'EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/price.sh"

test "$(total 10 2)" = 20
EOF
	bash -n lib/price.sh bin/run.sh test/price_test.sh
	git init -q
	commit "Bash references fixture"
	printf '{"references":{"total":[%s]}}\n' \
		"$(identifier_locations total lib/price.sh bin/run.sh test/price_test.sh)" >../manifest.json
}

tfproj() {
	cat >variables.tf <<'EOF'
variable "region" {
  type = string
}
EOF
	cat >main.tf <<'EOF'
locals {
  selected_region = var.region
}
EOF
	cat >outputs.tf <<'EOF'
output "selected_region" {
  value = var.region
}
EOF
	git init -q
	commit "Terraform references fixture"
	printf '{"references":{"region":[%s]}}\n' \
		"$(identifier_locations region variables.tf main.tf outputs.tf)" >../manifest.json
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
gomod | luaproj | pyproj | tsproj | rustproj | bashproj | tfproj | dirty) ;;
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
