#!/usr/bin/env sh
# Stop: run `make quick` (the layers the changes vs auto touch); exit 2 (block
# stopping) with the failing tail if red. `make check` stays the merge gate.
# Skips when the work tree is clean, and lets Claude stop on the second
# attempt (stop_hook_active) so a red gate cannot loop forever.
# Inside Archon loop runs (ARCHON_RUN=1, .archon/config.yaml env) it only lints
# the changed Lua files: the workflow runs the full make check once as its gate.
set -u

input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0

log=$(mktemp)
if [ "${ARCHON_RUN:-}" = "1" ]; then
	files=$(git status --porcelain --untracked-files=all | awk '{print $NF}' | grep '\.lua$' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
	[ -z "$files" ] && { rm -f "$log"; exit 0; }
	# shellcheck disable=SC2086 # word splitting is the file list
	{ stylua --check $files && selene $files; } >"$log" 2>&1 && { rm -f "$log"; exit 0; }
	gate="lint (stylua --check, selene) on changed files"
elif make quick >"$log" 2>&1; then
	rm -f "$log"
	exit 0
else
	gate="make quick"
fi
{
	echo "$gate is red. Fix it before finishing. Last lines:"
	tail -n 40 "$log"
} >&2
rm -f "$log"
exit 2
