#!/usr/bin/env sh
# Fetch pinned test dependencies into .tests/deps (gitignored).
# Not part of the user's plugin list; only the test runner and LuaLS load them.
set -eu
unset $(git rev-parse --local-env-vars) # GIT_DIR & co. leaked from `git bisect run` or a hook: `git init` would re-init the real repo (core.bare=true, 2026-10-19)

MINI_COMMIT="1345d191bb3da9c7b0e977f4387c5761f9bff68d" # mini.nvim v0.18.0
DEPS_DIR="${TEST_DEPS_DIR:-.tests/deps}"

# Print the commit pinned for plugin $1 in lazy-lock.json.
lock_commit() {
	sed -n "s/.*\"$1\": {.*\"commit\": \"\([0-9a-f]*\)\".*/\1/p" lazy-lock.json
}

# Shallow-fetch $2 at commit $3 into $DEPS_DIR/$1; no-op when already there.
fetch_pinned() {
	dir="$DEPS_DIR/$1"
	if [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)" = "$3" ]; then
		return 0
	fi
	rm -rf "$dir"
	mkdir -p "$DEPS_DIR"
	git init --quiet "$dir"
	git -C "$dir" fetch --quiet --depth 1 "$2" "$3"
	git -C "$dir" checkout --quiet FETCH_HEAD
	echo "$1 pinned at $3"
}

fetch_pinned mini.nvim https://github.com/nvim-mini/mini.nvim "$MINI_COMMIT"
# Type libraries for LuaLS (`make types`), at the commits of lazy-lock.json.
fetch_pinned lazy.nvim https://github.com/folke/lazy.nvim "$(lock_commit lazy.nvim)"
