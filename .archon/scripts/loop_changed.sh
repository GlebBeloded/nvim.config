#!/usr/bin/env bash
# Does the checkout need the loop-test layer (tests/check.sh)? Exit 0 = run it, 1 = skip it.
# Skips only when nothing loop-test reads changed vs the merge base with auto: the workflows, fixtures,
# scripts and prompts (.archon/), the Makefile (loop-test target, ARCHON), tests/check.sh, the loop's Lua tests and
# the harness they test, and the openspec rules and schemas that exec-code fixtures' `openspec validate` reads. Fail safe: runs on
# auto itself (branch or detached at its tip), and when the base is unknown or git fails.
#   loop_changed.sh [repo]   (default: the current directory); LOOP_BASE names the base (auto)
# and the loop's own Lua tests with what they exercise (tests/runner.lua LOOP_FILES): the sandbox and the test harness
LOOP_PATHS=(.archon Makefile tests/check.sh openspec/config.yaml openspec/schemas tests/unit/loop tests/unit/shortcuts/test_sandbox.lua
	tests/sandbox tests/helpers.lua tests/runner.lua tests/parallel.lua tests/minimal_init.lua tests/prune_tmp.sh tests/flaky.txt)

loop_changed() {
	local repo=${1:-.} ref=${LOOP_BASE:-auto} base changed
	[ "$(git -C "$repo" symbolic-ref -q --short HEAD 2>/dev/null)" = "$ref" ] && return 0
	git -C "$repo" rev-parse -q --verify "$ref^{commit}" >/dev/null 2>&1 || ref=local/$ref
	base=$(git -C "$repo" merge-base HEAD "$ref" 2>/dev/null) || return 0
	[ "$(git -C "$repo" rev-parse HEAD 2>/dev/null)" = "$(git -C "$repo" rev-parse "$ref" 2>/dev/null)" ] && return 0
	changed=$(git -C "$repo" diff --name-only "$base" -- "${LOOP_PATHS[@]}" &&
		git -C "$repo" ls-files --others --exclude-standard -- "${LOOP_PATHS[@]}") || return 0
	[ -n "$changed" ]
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then loop_changed "$@"; fi
