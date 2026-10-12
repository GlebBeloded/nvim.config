#!/usr/bin/env sh
# PostToolUse (Edit|Write): format the edited Lua file with stylua, then lint it
# with selene. Exit 2 feeds selene's findings back to Claude (the edit stays).
set -u

file=$(jq -r '.tool_input.file_path // empty')
case "$file" in
*.lua) ;;
*) exit 0 ;;
esac
[ -f "$file" ] || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
stylua "$file" || { echo "stylua failed on $file" >&2; exit 2; }
if ! out=$(selene --display-style quiet "$file" 2>&1); then
	printf 'selene found issues in %s:\n%s\n' "$file" "$out" >&2
	exit 2
fi
exit 0
