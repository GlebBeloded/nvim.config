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

status=0
lua-language-server --check="$PWD" --configpath="$PWD/.luarc.jsonc" \
	--checklevel=Warning --check_format=pretty --logpath="$LOG_DIR" >"$OUT" 2>&1 || status=$?

if grep -q "Setting file loading error" "$OUT"; then
	grep -A2 "Setting file loading error" "$OUT" | head -3
	echo "types: .luarc.jsonc failed to load"
	exit 1
fi
# drop the progress bar, keep diagnostics and the summary
tr '\r' '\n' <"$OUT" | grep -v '^ *>*=* *[0-9]*/[0-9]*$' | grep -v '^Initializing' | sed '/^[[:space:]]*$/d'
exit "$status"
