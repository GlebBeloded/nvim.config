#!/usr/bin/env sh
# Fetch pinned test dependencies into .tests/deps (gitignored).
# Not part of the user's plugin list; only the test runner loads them.
set -eu

MINI_COMMIT="1345d191bb3da9c7b0e977f4387c5761f9bff68d" # mini.nvim v0.18.0
DEPS_DIR="${TEST_DEPS_DIR:-.tests/deps}"
MINI_DIR="$DEPS_DIR/mini.nvim"

if [ "$(git -C "$MINI_DIR" rev-parse HEAD 2>/dev/null || true)" = "$MINI_COMMIT" ]; then
	exit 0
fi

rm -rf "$MINI_DIR"
mkdir -p "$DEPS_DIR"
git init --quiet "$MINI_DIR"
git -C "$MINI_DIR" fetch --quiet --depth 1 https://github.com/nvim-mini/mini.nvim "$MINI_COMMIT"
git -C "$MINI_DIR" checkout --quiet FETCH_HEAD
echo "mini.nvim pinned at $MINI_COMMIT"
