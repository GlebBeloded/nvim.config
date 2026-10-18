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
#   build.sh billing  Go/TS repo with staged, unstaged and untracked changes (changes panel)
#   build.sh diffgo  Go files with changed, inserted, deleted and moved lines
#   build.sh treeproj Project-tree sample with modified, added, untracked and ignored files
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
			offset = 0
			while (match(text, "(^|[^A-Za-z0-9_])" identifier "([^A-Za-z0-9_]|$)")) {
				matched = substr(text, RSTART, RLENGTH)
				col = offset + RSTART + index(matched, identifier) - 1
				printf "%s{\"path\":\"%s\",\"line\":%d,\"col\":%d}", sep, file, line, col
				sep = ","
				consumed = RSTART + index(matched, identifier) + length(identifier) - 2
				offset += consumed
				text = substr(text, consumed + 1)
			}
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
	cat >lua/shop/discount.lua <<'EOF'
local M = { rate = 0.1 }

---@param amount number
function M.apply(amount)
    return amount * (1 - M.rate)
end

-- Flat-rate shops override the percentage.
M.apply = function(amount)
    return amount - M.rate
end

return M
EOF
	cat >lua/shop/checkout.lua <<'EOF'
local discount = require("shop.discount")

return discount.apply(100)
EOF
	cat >spec/discount_spec.lua <<'EOF'
local discount = require("shop.discount")

assert(discount.apply(100) == 99.9)
EOF
	git init -q
	commit "Lua references fixture"
	printf '{"references":{"total":[%s],"apply":[%s]}}\n' \
		"$(identifier_locations total lua/shop/price.lua lua/shop/cart.lua spec/price_spec.lua)" \
		"$(identifier_locations apply lua/shop/discount.lua lua/shop/checkout.lua spec/discount_spec.lua)" >../manifest.json
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
	cat >shop/money.py <<'EOF'
from dataclasses import dataclass


@dataclass(frozen=True)
class Money:
    cents: int
EOF
	cat >shop/pricing.py <<'EOF'
from shop.money import Money

ZERO = Money(0)


class Price(Money):
    """A unit price in cents."""


def discount(price: Money, percent: int) -> int:
    return price.cents * percent // 100
EOF
	cat >tests/test_pricing.py <<'EOF'
from shop import money, pricing


def test_zero_is_money() -> None:
    assert isinstance(pricing.ZERO, money.Money)
EOF
	python3 -m py_compile shop/__init__.py shop/price.py shop/cart.py shop/money.py shop/pricing.py tests/test_price.py tests/test_pricing.py
	rm -rf shop/__pycache__ tests/__pycache__
	git init -q
	commit "Python references fixture"
	printf '{"references":{"total":[%s],"Money":[%s]}}\n' \
		"$(identifier_locations total shop/price.py shop/cart.py tests/test_price.py)" \
		"$(identifier_locations Money shop/money.py shop/pricing.py tests/test_pricing.py)" >../manifest.json
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
	cat >src/money.ts <<'EOF'
// An amount in cents.
export class Money {
  cents: number;

  constructor(cents: number) {
    this.cents = cents;
  }

  // Reads a decimal amount such as "19.99".
  static parse(text: string): Money {
    return new Money(Math.round(Number(text) * 100));
  }
}

// Narrows an unknown value to an amount.
export function isMoney(value: unknown): value is Money {
  return value instanceof Money;
}
EOF
	cat >src/wallet.ts <<'EOF'
import { Money, isMoney } from "./money";

export class Coin extends Money {}

export class Wallet {
  items: Money[] = [];

  add(item: Money): Wallet {
    this.items.push(item);
    return this;
  }

  latest(): Money {
    return this.items.at(-1) as Money;
  }

  restore(json: string): Wallet {
    const value: unknown = JSON.parse(json);
    const item: Money = isMoney(value) ? value : Money.parse(json);
    return this.add(item);
  }
}
EOF
	cat >src/money.test.ts <<'EOF'
import { Money } from "./money";

export const amounts: Array<Money> = [Money.parse("19.99")];
EOF
	if command -v tsc >/dev/null 2>&1; then
		tsc --noEmit
	else
		for file in eslint.config.js src/price.ts src/cart.ts src/price.test.ts; do
			node --check --input-type=module <"$file"
		done
		for file in src/money.ts src/wallet.ts src/money.test.ts; do
			node --check "$file"
		done
	fi
	git init -q
	commit "TypeScript references fixture"
	printf '{"references":{"total":[%s],"Money":[%s]}}\n' \
		"$(identifier_locations total src/price.ts src/cart.ts src/price.test.ts)" \
		"$(identifier_locations Money src/money.ts src/wallet.ts src/money.test.ts)" >../manifest.json
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
pub mod money;
pub mod ledger;
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
	cat >src/money.rs <<'EOF'
/// An amount in cents.
pub struct Money {
    pub cents: i64,
}

impl Money {
    pub fn from_cents(cents: i64) -> Money {
        Money { cents }
    }
}
























EOF
	cat >src/ledger.rs <<'EOF'
use crate::money::Money;

/// Adds up the entries of one account.
pub fn balance(entries: &[i64]) -> Money {
    Money::from_cents(entries.iter().sum())
}

/// Returns true when the amount is zero.
pub fn is_free(amount: &Money) -> bool {
    match amount {
        Money { cents: 0 } => true,
        _ => false,
    }
}
EOF
	cat >tests/money.rs <<'EOF'
use rustproj::money::Money;

#[test]
fn starts_from_cents() {
    let amount = Money::from_cents(250);
    assert_eq!(amount.cents, 250);
}
EOF
	cargo check --all-targets >&2
	git init -q
	commit "Rust references fixture"
	printf '{"references":{"total":[%s],"Money":[%s]}}\n' \
		"$(identifier_locations total src/price.rs src/main.rs tests/price.rs)" \
		"$(identifier_locations Money src/money.rs src/ledger.rs tests/money.rs)" >../manifest.json
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
	cat >lib/tax.sh <<'EOF'
#!/usr/bin/env bash
rate=20
export rate

tax() {
	printf '%s\n' "$(($1 * rate / 100))"
}
EOF
	cat >bin/invoice.sh <<'EOF'
#!/usr/bin/env bash
source "$(dirname "$0")/../lib/tax.sh"

rate=25
tax 100
EOF
	bash -n lib/price.sh bin/run.sh test/price_test.sh lib/tax.sh bin/invoice.sh
	git init -q
	commit "Bash references fixture"
	printf '{"references":{"total":[%s],"rate":[%s]}}\n' \
		"$(identifier_locations total lib/price.sh bin/run.sh test/price_test.sh)" \
		"$(identifier_locations rate lib/tax.sh bin/invoice.sh)" >../manifest.json
}

tfproj() {
	mkdir -p net
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
	cat >network.tf <<'EOF'
variable "vpc_cidr" {
  type = string
}

module "vpc" {
  source = "./net"
  cidr   = var.vpc_cidr
}

resource "aws_s3_bucket" "logs" {
  bucket     = module.vpc.id
  depends_on = [module.vpc]
}

output "vpc_id" {
  value = module.vpc.id
}
EOF
	cat >net/main.tf <<'EOF'
variable "cidr" {
  type = string
}

locals {
  name = "subnet-${var.cidr}"
}

output "id" {
  value = var.cidr
}
EOF
	git init -q
	commit "Terraform references fixture"
	printf '{"references":{"region":[%s],"cidr":[%s],"vpc":[%s]}}\n' \
		"$(identifier_locations region variables.tf main.tf outputs.tf)" \
		"$(identifier_locations cidr net/main.tf network.tf)" \
		"$(identifier_locations vpc network.tf net/main.tf)" >../manifest.json
}

treeproj() {
	git init -q
	mkdir -p .github/workflows cmd/server internal/billing internal/money web/src
	printf 'bin/\nnode_modules/\n.env\n*.log\n' >.gitignore
	printf 'module example.com/billing\n\ngo 1.22\n' >go.mod
	: >go.sum
	printf 'test:\n\tgo test ./...\n' >Makefile
	printf '# billing\n\nInvoices, tax and money formatting.\n' >README.md
	cat >.github/workflows/ci.yml <<'EOF'
name: ci
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: go test ./...
EOF
	cat >cmd/server/main.go <<'EOF'
package main

import (
	"fmt"

	"example.com/billing/internal/billing"
)

func main() {
	inv := billing.Invoice{ID: "INV-1", Lines: []int{100, 250}}
	fmt.Println(inv.Due())
}
EOF
	cat >internal/billing/discount.go <<'EOF'
package billing

// Discount takes percent off an amount in cents.
func Discount(cents, percent int) int {
	return cents - cents*percent/100
}
EOF
	cat >internal/billing/discount_test.go <<'EOF'
package billing

import "testing"

func TestDiscount(t *testing.T) {
	if got := Discount(200, 10); got != 180 {
		t.Fatalf("Discount = %d", got)
	}
}
EOF
	cat >internal/billing/invoice.go <<'EOF'
package billing

import (
	"fmt"

	"example.com/billing/internal/money"
)

// Invoice is a list of line amounts in cents.
type Invoice struct {
	ID    string
	Lines []int
}

// Total sums the lines and applies the tax rate.
func (i Invoice) Total() int {
	total := 0
	for _, cents := range i.Lines {
		total += cents
	}
	return total
}

// Due renders the total as dollars.
func (i Invoice) Due() string {
	return fmt.Sprintf("due %s", money.Format(i.Total()))
}
EOF
	cat >internal/billing/invoice_test.go <<'EOF'
package billing

import "testing"

func TestDue(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}}
	if got := inv.Due(); got != "due $3.50" {
		t.Fatalf("Due = %q", got)
	}
}
EOF
	cat >internal/money/money.go <<'EOF'
package money

import "fmt"

// Format renders cents as dollars.
func Format(cents int) string {
	return fmt.Sprintf("$%d.%02d", cents/100, cents%100)
}
EOF
	cat >internal/money/money_test.go <<'EOF'
package money

import "testing"

func TestFormat(t *testing.T) {
	if got := Format(350); got != "$3.50" {
		t.Fatalf("Format = %q", got)
	}
}
EOF
	printf '{\n  "name": "billing-web",\n  "private": true\n}\n' >web/package.json
	printf '{\n  "name": "billing-web",\n  "lockfileVersion": 3,\n  "requires": true,\n  "packages": {}\n}\n' \
		>web/package-lock.json
	cat >web/src/cart.tsx <<'EOF'
import { price } from "./price";

export function Cart({ cents }: { cents: number }) {
  return <span>{price(cents)}</span>;
}
EOF
	printf 'export function price(cents: number): string {\n  return `$${cents / 100}`;\n}\n' >web/src/price.ts
	printf 'export declare function price(cents: number): string;\n' >web/src/price.d.ts
	cat >web/src/price.test.ts <<'EOF'
import { price } from "./price";

test("price", () => {
  expect(price(350)).toBe("$3.5");
});
EOF
	commit "billing service"
	# modified (unstaged): invoice.go gains the Tax field, invoice_test.go and price.ts change
	cat >internal/billing/invoice.go <<'EOF'
package billing

import (
	"fmt"

	"example.com/billing/internal/money"
)

// Invoice is a list of line amounts in cents.
type Invoice struct {
	ID    string
	Lines []int
	Tax   Rate
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
EOF
	cat >internal/billing/invoice_test.go <<'EOF'
package billing

import "testing"

func TestDue(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}, Tax: 10}
	if got := inv.Due(); got != "due $3.85" {
		t.Fatalf("Due = %q", got)
	}
}
EOF
	printf 'export function price(cents: number): string {\n  return `$${(cents / 100).toFixed(2)}`;\n}\n' >web/src/price.ts
	# added (staged)
	cat >internal/billing/tax.go <<'EOF'
package billing

// Rate is a tax rate in percent.
type Rate int

// Apply adds the tax to an amount in cents.
func (r Rate) Apply(cents int) int {
	return cents + cents*int(r)/100
}
EOF
	cat >internal/billing/tax_test.go <<'EOF'
package billing

import "testing"

func TestApply(t *testing.T) {
	if got := Rate(10).Apply(200); got != 220 {
		t.Fatalf("Apply = %d", got)
	}
}
EOF
	git add internal/billing/tax.go internal/billing/tax_test.go
	# untracked
	printf '# notes\n\n- tax rounding\n' >notes.md
	# ignored (.gitignore)
	mkdir -p bin web/node_modules/left-pad
	printf '#!/bin/sh\necho server\n' >bin/server
	printf 'module.exports = (s) => s;\n' >web/node_modules/left-pad/index.js
	printf 'TAX_RATE=0.2\n' >.env
	printf '{"modified":["internal/billing/invoice.go","internal/billing/invoice_test.go","web/src/price.ts"],"added":["internal/billing/tax.go","internal/billing/tax_test.go"],"untracked":["notes.md"],"ignored":["bin/","web/node_modules/",".env"]}\n' \
		>../manifest.json
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
	cat >billing/batch.go <<'EOF'
package billing

// Batch groups the invoices of one customer.
type Batch struct {
	Current Invoice
	Past    []*Invoice
}

// NewInvoice starts an invoice with one line.
func NewInvoice(cents int) *Invoice {
	return &Invoice{Lines: []int{cents}}
}

// Merge appends extra lines to inv.
func Merge(inv Invoice, extra []int) Invoice {
	inv.Lines = append(inv.Lines, extra...)
	return inv
}
EOF
	cat >billing/invoice_test.go <<'EOF'
package billing

import "testing"

func TestDue(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}}
	if got := inv.Due(); got != "$3.50" {
		t.Fatalf("Due() = %q, want $3.50", got)
	}
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
	cat >report/calls.go <<'EOF'
package report

// Calls counts rendered summaries.
var Calls int

// Count records one rendered summary.
func Count() {
	Calls++
}
EOF
	cat >report/calls_test.go <<'EOF'
package report

import "testing"

func TestCount(t *testing.T) {
	Calls = 0
	Count()
	if Calls != 1 {
		t.Fatalf("Calls = %d, want 1", Calls)
	}
}
EOF
	go build ./... >&2
	go vet ./... >&2
	git init -q
	commit "gomod fixture"
	printf '{"references":{"Format":[%s],"Calls":[%s],"Invoice":[%s]}}\n' \
		"$(format_locations internal/money/money.go internal/money/money_test.go billing/invoice.go report/summary.go)" \
		'{"path":"report/calls.go","line":4,"col":5},{"path":"report/calls.go","line":8,"col":2},{"path":"report/calls_test.go","line":6,"col":2},{"path":"report/calls_test.go","line":8,"col":5},{"path":"report/calls_test.go","line":9,"col":34}' \
		'{"path":"billing/invoice.go","line":6,"col":6},{"path":"billing/invoice.go","line":11,"col":9},{"path":"billing/invoice.go","line":20,"col":9},{"path":"billing/batch.go","line":5,"col":10},{"path":"billing/batch.go","line":6,"col":13},{"path":"billing/batch.go","line":10,"col":29},{"path":"billing/batch.go","line":11,"col":10},{"path":"billing/batch.go","line":15,"col":16},{"path":"billing/invoice_test.go","line":6,"col":9}' \
		>../manifest.json
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

billing() {
	git init -q
	mkdir -p cmd/server internal/billing internal/money web/src
	printf 'module example.com/billing\n\ngo 1.23\n' >go.mod
	printf 'bin/\n.env\nnode_modules/\n' >.gitignore
	printf '# billing\n\nInvoices, tax and prices.\n' >README.md
	printf 'test:\n\tgo test ./...\n' >Makefile
	cat >cmd/server/main.go <<'GO'
package main

func main() {}
GO
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
	Tax   Rate
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
	cat >internal/billing/invoice_test.go <<'GO'
package billing

import "testing"

func TestTotal(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}}
	if inv.Total() != 350 {
		t.Fatal("total")
	}
}
GO
	cat >web/src/price.ts <<'TS'
export type Price = { cents: number; currency: string };

export function format(price: Price): string {
  const units = price.cents / 100;
  return `${units} ${price.currency}`;
}

export function add(a: Price, b: Price): Price {
  return { cents: a.cents + b.cents, currency: a.currency };
}
TS
	printf 'export function Cart() {\n  return null;\n}\n' >web/src/cart.tsx
	commit "billing: invoices and prices"
	# unstaged edits: invoice.go +12 -3, invoice_test.go +20 -1, price.ts +4 -4
	cat >internal/billing/invoice.go <<'GO'
package billing

import (
	"fmt"

	"example.com/billing/internal/money"
)

// Invoice is a list of line amounts in cents, with a tax rate.
type Invoice struct {
	ID    string // invoice number
	Lines []int
	Tax   Rate
}

// Total sums the lines and applies the tax rate.
func (i Invoice) Total() int {
	var total int
	for _, cents := range i.Lines {
		total += cents
	}
	if i.Tax == nil {
		return total
	}
	return i.Tax.Apply(total)
}

// Due renders the total as dollars.
func (i Invoice) Due() string {
	return fmt.Sprintf("due %s", money.Format(i.Total()))
}

// Paid reports whether nothing is due.
func (i Invoice) Paid() bool {
	total := i.Total()
	return total == 0
}
GO
	cat >internal/billing/invoice_test.go <<'GO'
package billing

import "testing"

func TestTotal(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}}
	if got := inv.Total(); got != 350 {
		t.Fatal("total")
	}
}

func TestDue(t *testing.T) {
	inv := Invoice{Lines: []int{100, 250}}
	if got := inv.Due(); got != "due $3.50" {
		t.Fatalf("due = %q", got)
	}
}

func TestPaid(t *testing.T) {
	if !(Invoice{}).Paid() {
		t.Fatal("empty invoice is paid")
	}
}

func TestTaxNil(t *testing.T) {
	if got := (Invoice{Lines: []int{100}}).Total(); got != 100 {
		t.Fatalf("total = %d", got)
	}
}
GO
	cat >web/src/price.ts <<'TS'
export type Price = { cents: number; currency: "EUR" | "USD" };

export function format(price: Price): string {
  const units = (price.cents / 100).toFixed(2);
  return `${units} ${price.currency.toLowerCase()}`;
}

export function add(a: Price, b: Price): Price {
  return { ...a, cents: a.cents + b.cents };
}
TS
	# staged new files: tax.go +41, tax_test.go +33
	{
		printf 'package billing\n\n'
		printf '// Rate applies a tax to an amount in cents.\ntype Rate interface {\n\tApply(cents int) int\n}\n'
		for name in Flat Percent Exempt; do
			printf '\n// %s is a %s tax rate.\ntype %s struct {\n\tValue int\n}\n' "$name" "$name" "$name"
			printf '\n// Apply implements Rate.\nfunc (r %s) Apply(cents int) int {\n\treturn cents + r.Value\n}\n' "$name"
		done
		printf '\n// Rates lists every known rate.\nvar Rates = []Rate{\n\tFlat{}, Percent{}, Exempt{},\n}\n'
	} >internal/billing/tax.go
	{
		printf 'package billing\n\nimport "testing"\n'
		for name in Flat Percent Exempt; do
			printf '\nfunc Test%s(t *testing.T) {\n\trate := %s{Value: 5}\n\tif got := rate.Apply(100); got != 105 {\n\t\tt.Fatalf("%s = %%d", got)\n\t}\n\t_ = Invoice{Tax: rate}\n\t_ = rate\n\t_ = t\n}\n' "$name" "$name" "$name"
		done
	} >internal/billing/tax_test.go
	git add internal/billing/tax.go internal/billing/tax_test.go
	# untracked: notes.md (9 lines)
	printf '# Notes\n\n- tax rates per region\n- invoice numbering\n- rounding of cents\n\nOpen questions:\n- refunds\n- currencies\n' >notes.md
	staged=$(git diff --cached --name-only | file_entries true false)
	unstaged=$(git diff --name-only | file_entries false false)
	untracked=$(git ls-files --others --exclude-standard | file_entries false true)
	printf '{"files":[%s,%s,%s]}\n' "$staged" "$unstaged" "$untracked" >../manifest.json
}

# $1 first, $2 last: one 4-line block per step (blank, func, body, close)
ctl_steps() {
	i=$1
	while [ "$i" -le "$2" ]; do
		printf '\nfunc (c *Ctl) Step%d() error {\n\treturn c.step(%d)\n}\n' "$i" "$i"
		i=$((i + 1))
	done
}

# $1 old | new: internal/user/controller.go, 151 lines; Drop() is lines 50-67
ctl_controller() {
	printf '// Package user manages user accounts.\npackage user\n\nimport "log"\n\n'
	printf '// Ctl removes users and counts what it did.\n// It is not safe for concurrent use.\ntype Ctl struct {\n\tstats Stats\n}\n\n'
	printf '// Stats are the counters of a Ctl.\ntype Stats struct{ Removed, Skipped, LastRun Counter }\n\n'
	printf '// Counter is one metric.\ntype Counter interface{ Inc(); Touch() }\n'
	ctl_steps 1 8
	printf '\nfunc (c *Ctl) Drop(id string) error {\n\tuser, ok, err := c.lookup(id)\n\tif err != nil {\n'
	if [ "$1" = old ]; then printf '\t\treturn err\n'; else printf '\t\treturn wrap(err)\n'; fi
	printf '\t}\n\tif !ok {\n\t\tlog.Info("no user, skipping")\n\n'
	if [ "$1" = new ]; then printf '\t\tc.stats.Skipped.Inc()\n'; fi
	printf '\t\treturn err\n\t}\n\n\tif err = c.del(user); err != nil {\n\t\treturn err\n\t}\n\tc.stats.Removed.Inc()\n'
	if [ "$1" = old ]; then printf '\tc.stats.LastRun.Touch()\n'; fi
	printf '\treturn nil\n}\n'
	ctl_steps 9 29
}

# $1 old | new: internal/user/ids.go; new moves Validate (7 lines) below Key
ids_validate() {
	printf '// Validate rejects empty ids.\nfunc Validate(id string) error {\n\tif id == "" {\n\t\treturn errEmpty\n\t}\n\treturn nil\n}\n'
}
ids_rest() {
	printf '// Normalize trims and lowercases an id.\nfunc Normalize(id string) string {\n\treturn strings.ToLower(strings.TrimSpace(id))\n}\n'
	printf '// Key is the storage key of an id.\nfunc Key(id string) string {\n\treturn "user/" + Normalize(id)\n}\n'
}
ids() {
	printf 'package user\n\n'
	if [ "$1" = old ]; then ids_validate; ids_rest; else ids_rest; ids_validate; fi
}

diffgo() {
	git init -q
	mkdir -p internal/user
	ctl_controller old >internal/user/controller.go
	ids old >internal/user/ids.go
	commit "add user controller"
	ctl_controller new >internal/user/controller.go
	ids new >internal/user/ids.go
	printf '{"head":"%s","controller":"internal/user/controller.go","ids":"internal/user/ids.go"}\n' \
		"$(git rev-parse --short=7 HEAD)" >../manifest.json
}

# cache key input: this script, plus the Go toolchain for Go fixtures
key_input() {
	cat "$0"
	case "$name" in
	gomod) go version ;;
	esac
}

case "$name" in
gomod | luaproj | pyproj | tsproj | rustproj | bashproj | tfproj | dirty | billing | diffgo | treeproj) ;;
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
