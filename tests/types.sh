#!/usr/bin/env sh
# `make types`: lua-language-server --check with the committed .luarc.jsonc.
# LuaLS silently falls back to defaults when the config fails to parse, so that
# is treated as a failure too.
set -eu

: "${VIMRUNTIME:?VIMRUNTIME must be exported (see Makefile)}"
LOG_DIR="${TMPDIR:-/tmp}/luals-check-$$"
OUT="$LOG_DIR/out.txt"
mkdir -p "$LOG_DIR"
trap 'rm -rf "$LOG_DIR"' EXIT

# Skip when nothing LuaLS reads changed since the last green run: the Lua
# files, the config, the LuaLS version and the libraries ($VIMRUNTIME and .tests/deps).
STAMP=.tests/types.ok
key=$({
	lua-language-server --version
	echo "$VIMRUNTIME"
	for lib in mini.nvim lazy.nvim vscode-diff.nvim; do
		git -C ".tests/deps/$lib" rev-parse HEAD 2>/dev/null || true
	done
	git ls-files -z --cached --others --exclude-standard -- '*.lua' .luarc.jsonc | xargs -0 shasum
} | shasum | cut -d' ' -f1)
if [ "$(cat "$STAMP" 2>/dev/null)" = "$key" ]; then
	echo "types: unchanged since the last green run (rm $STAMP to force)"
	exit 0
fi

status=0
lua-language-server --check="$PWD" --configpath="$PWD/.luarc.jsonc" \
	--checklevel=Warning --check_format=pretty --logpath="$LOG_DIR" >"$OUT" 2>&1 || status=$?

if grep -q "Setting file loading error" "$OUT"; then
	grep -A2 "Setting file loading error" "$OUT" | head -3
	echo "types: .luarc.jsonc failed to load"
	exit 1
fi
# drop the progress bar (`>>>>=== 12/369 [Found 5 problems in 1 files]`), keep diagnostics and the summary
tr '\r' '\n' <"$OUT" | grep -Ev '^ *[>=]* *[0-9]+/[0-9]+( *\[[^]]*\])? *$' | grep -v '^Initializing' | sed '/^[[:space:]]*$/d'
[ "$status" -eq 0 ] && mkdir -p .tests && echo "$key" >"$STAMP"
exit "$status"
