#!/usr/bin/env sh
# `make quick`: lint + trace, plus only the layers the changes vs $BASE
# (default auto; committed, staged, unstaged and untracked) can affect, run
# concurrently by tests/check.sh. `make check` stays the merge gate.
#   lua/gleb/<feature>/, openspec/specs/<cap>/, tests/<layer>/<cap>/ -> mini.test for <cap>
#   init.lua, plugin spec, options, test harness, other lua/gleb files -> all mini.test layers
#   any Lua or .luarc.jsonc -> types (cached by content, tests/types.sh)
#   init.lua, plugin spec, lazy-lock.json, options, autocommands, tests/smoke/ -> smoke
#   terminal/, keymaps -> chain; shortcuts capability -> chain + stack
#   terminal/, keymaps, shortcuts capability, tests/e2e/ -> e2e (E2E=1, focus bursts),
#     only when Accessibility is granted (else make check reports it as skipped)
# Overrides: ALL=1 all mini.test layers, STACK=1 stack, E2E=1 e2e, SMOKE=1 smoke, TYPES=1 types.
set -eu

BASE=${BASE:-auto}
base=$(git merge-base "$BASE" HEAD 2>/dev/null || git rev-parse HEAD)
changed=$({
	git diff --name-only "$base"
	git ls-files --others --exclude-standard
} | sort -u)

caps="" all=${ALL:-} types=${TYPES:-} smoke=${SMOKE:-} chain="" stack=${STACK:-} e2e=${E2E:-}

add_cap() {
	case " $caps " in *" $1 "*) ;; *) caps="$caps $1" ;; esac
}

# $1 capability: has it mini.test files (unit, integration, screen)?
has_tests() {
	for layer in unit integration screen; do
		[ -d "tests/$layer/$1" ] && return 0
	done
	return 1
}

# $1 capability: run its tests, or all layers when it has none
cap_or_all() {
	if has_tests "$1"; then add_cap "$1"; else all=1; fi
}

for f in $changed; do
	case "$f" in
	*.lua | .luarc.jsonc) types=1 ;;
	esac
	case "$f" in
	init.lua | lazy-lock.json | lua/gleb/plugins/* | lua/gleb/options.lua | lua/gleb/autocommands.lua)
		all=1 smoke=1 ;;
	lua/gleb/keymaps.lua) add_cap keymaps && chain=1 e2e=1 ;;
	lua/gleb/lualine.lua) add_cap statusline ;;
	lua/gleb/*/*) d=${f#lua/gleb/} && d=${d%%/*} && cap_or_all "$(echo "$d" | tr _ -)" ;;
	lua/*) all=1 ;;
	tests/helpers.lua | tests/minimal_init.lua | tests/child_init.lua | tests/runner.lua | tests/parallel.lua)
		all=1 ;;
	tests/smoke/*) smoke=1 ;;
	tests/shortcuts/* | openspec/specs/shortcuts/* | openspec/changes/*/specs/shortcuts/*)
		chain=1 stack=1 e2e=1 ;;
	tests/chain/* | tests/stack/*) chain=1 stack=1 ;;
	tests/e2e/*) e2e=1 ;;
	terminal/*) chain=1 e2e=1 ;;
	tests/screenshots/tests-*-*-*) c=${f#tests/screenshots/tests-*-} && add_cap "${c%%-test_*}" ;;
	tests/unit/*/* | tests/integration/*/* | tests/screen/*/*) c=${f#tests/*/} && add_cap "${c%%/*}" ;;
	openspec/specs/*/* | openspec/changes/*/specs/*/*) c=${f%/*} && c=${c##*/} && add_cap "$c" ;;
	esac
done
case " $caps " in *" keymaps "*) chain=1 ;; esac
tested=""
for c in $caps; do has_tests "$c" && tested="$tested $c"; done
caps=$tested

targets="lint trace"
[ -n "$types" ] && targets="$targets types"
if [ -n "$all" ]; then
	caps="" targets="$targets test"
elif [ -n "$(echo "$caps" | tr -d ' ')" ]; then
	targets="$targets test"
fi
[ -n "$chain" ] && targets="$targets chain"
[ -n "$stack" ] && targets="$targets stack"
if [ -n "$e2e" ] && [ "$e2e" != 0 ] && keys=$(tests/e2e/build.sh 2>/dev/null) && "$keys" trusted >/dev/null; then
	targets="$targets e2e"
	export E2E=1
fi
[ -n "$smoke" ] && targets="$targets smoke"

CAPS=$(echo "$caps" | sed 's/^ *//; s/ \{1,\}/,/g')
export CAPS
echo "quick vs $BASE: $targets${CAPS:+ (CAPS=$CAPS)}"
# shellcheck disable=SC2086 # word splitting is the target list
exec "$(dirname "$0")/check.sh" $targets
