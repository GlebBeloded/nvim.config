#!/usr/bin/env bash
# loop_changed.sh's skip decision on a scratch repo (run by `make loop-test`).
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(mktemp -d "${TMPDIR:-/tmp}/loop-changed.XXXXXX")
trap 'rm -rf "$repo"' EXIT
fails=0

# $1 expected (run|skip), $2 case name
expect() {
	local got=skip
	bash "$here/loop_changed.sh" "$repo" && got=run
	[ "$got" = "$1" ] || {
		echo "loop_changed: $2: expected $1, got $got"
		fails=1
	}
}

g() { git -C "$repo" "$@"; }
g init -q -b main
g config user.email t@t
g config user.name t
mkdir -p "$repo/.archon" "$repo/lua" "$repo/openspec/specs"
echo a >"$repo/.archon/config.yaml"
echo a >"$repo/lua/init.lua"
g add -A
g commit -qm base

expect run "no auto branch"
g branch auto
expect run "on auto"
g checkout -q --detach auto
expect run "detached at auto"
g checkout -q -b work
expect run "branch at auto's tip"
echo b >"$repo/lua/init.lua"
echo b >"$repo/openspec/specs/x.md"
g commit -qam lua
g add -A
g commit -qm specs
expect skip "lua and specs only"
echo b >"$repo/.archon/config.yaml"
expect run "uncommitted .archon edit"
g checkout -q -- .archon
echo x >"$repo/.archon/new.py"
expect run "untracked .archon file"
g add -A
g commit -qm loop
expect run "committed .archon change"
g checkout -q auto
g checkout -q -b other
echo m >"$repo/Makefile"
expect run "untracked Makefile"
exit $fails
