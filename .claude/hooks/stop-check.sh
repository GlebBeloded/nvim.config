#!/usr/bin/env sh
# Stop: run `make check`; exit 2 (block stopping) with the failing tail if red.
# Skips when the work tree is clean, and lets Claude stop on the second
# attempt (stop_hook_active) so a red gate cannot loop forever.
# Skips inside Archon loop runs, whose workflows gate with make check themselves.
set -u

input=$(cat)
# Archon loop nodes (NVIM_LOOP=1, .archon/config.yaml env) gate with make check themselves.
[ "${NVIM_LOOP:-}" = "1" ] && exit 0
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0

log=$(mktemp)
if make check >"$log" 2>&1; then
	rm -f "$log"
	exit 0
fi
{
	echo "make check is red. Fix it before finishing. Last lines:"
	tail -n 40 "$log"
} >&2
rm -f "$log"
exit 2
