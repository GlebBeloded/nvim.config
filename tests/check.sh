#!/usr/bin/env bash
# Run make targets concurrently: one status line per target as it finishes,
# then the full log of every failed target. Exit 1 if any failed.
#   tests/check.sh lint types test +smoke-startup
# A target prefixed with "+" runs alone after all the others (timing-sensitive).
# The whole run holds the host-wide check lock (tests/sandbox/lock.sh), so checks of other
# checkouts on this host wait instead of skewing each other's timing layers:
#   CHECK_LOCK=0        run without it
#   CHECK_LOCK_DIR      the lock (default ~/.cache/nvim-check-lock)
#   CHECK_LOCK_POLL     s between attempts while another check holds it (default 2)
#   CHECK_LOCK_TIMEOUT  s to wait before giving up (default 3600)
# Lock order: the check lock is outer, the sandbox lock (taken by e2e) inner.
set -u

MAKE=${MAKE:-make}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=tests/sandbox/lock.sh
source "$ROOT/tests/sandbox/lock.sh"
LOCK_PREFIX=check LOCK_NAME="the check lock"

# a check started from inside a check (CHECK_LOCK_HOLDER names the live owner) already holds it
check_lock_reentrant() {
	[ -n "${CHECK_LOCK_HOLDER:-}" ] && [ "$(lock_owner "$1")" = "$CHECK_LOCK_HOLDER" ] && lock_owner_alive "$1"
}

check_lock() {
	local dir=${CHECK_LOCK_DIR:-$HOME/.cache/nvim-check-lock}
	[ "${CHECK_LOCK:-1}" = 0 ] && return 0
	check_lock_reentrant "$dir" && return 0
	mkdir -p "$(dirname "$dir")"
	lock_wait "$dir" "${CHECK_LOCK_POLL:-2}" "${CHECK_LOCK_TIMEOUT:-3600}"
	CHECK_LOCK_HOLDER=$(lock_owner "$dir")
	export CHECK_LOCK_HOLDER
}

check_lock
logs=$(mktemp -d "${TMPDIR:-/tmp}/check.XXXXXX")
trap 'lock_release; rm -rf "$logs"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

now() { perl -MTime::HiRes=time -e 'printf "%.1f", time'; }
started=$(now)

# shared prerequisites once, so concurrent targets never bootstrap at once
"$MAKE" -s deps deps-shortcuts >"$logs/deps.log" 2>&1 || {
	cat "$logs/deps.log"
	exit 1
}

# $1 target: run it in the background, leaving <target>.rc and <target>.time
start() {
	(
		t0=$(now)
		"$MAKE" -s "$1" >"$logs/$1.log" 2>&1
		rc=$?
		perl -e "printf '%.1f', $(now) - $t0" >"$logs/$1.time"
		echo "$rc" >"$logs/$1.rc"
	) &
}

# $@ targets: wait for all, printing each as it finishes
wait_all() {
	pending="$*"
	while [ -n "$pending" ]; do
		rest=""
		for t in $pending; do
			if [ -f "$logs/$t.rc" ]; then
				if [ "$(cat "$logs/$t.rc")" = 0 ]; then status="ok  "; else status="FAIL"; fi
				# a layer that cannot run here (e2e without Accessibility) says why
				skip=$(grep -o -m1 '[a-z0-9-]*: SKIPPED: .*' "$logs/$t.log")
				[ -n "$skip" ] && [ "$status" = "ok  " ] && status="skip"
				printf '%s %-14s %5s s%s\n' "$status" "$t" "$(cat "$logs/$t.time")" "${skip:+  ($skip)}"
			else
				rest="$rest $t"
			fi
		done
		pending=$rest
		[ -n "$pending" ] && sleep 0.1
	done
	wait
}

# shellcheck source=.archon/scripts/loop_changed.sh
source "$ROOT/.archon/scripts/loop_changed.sh"

parallel="" serial=""
for t in "$@"; do
	# loop-test (~90 s) only when a file it reads changed vs auto (loop_changed.sh says which)
	if [ "${t#+}" = loop-test ] && ! loop_changed "$ROOT"; then
		echo "loop-test: skipped (no loop changes)"
		continue
	fi
	case "$t" in
	+*) serial="$serial ${t#+}" ;;
	*) parallel="$parallel $t" ;;
	esac
done

for t in $parallel; do start "$t"; done
# shellcheck disable=SC2086 # word splitting is the target list
wait_all $parallel
for t in $serial; do
	start "$t"
	wait_all "$t"
done

failed=""
for t in $parallel $serial; do
	[ "$(cat "$logs/$t.rc")" = 0 ] || failed="$failed $t"
done
for t in $failed; do
	printf '\n===== %s =====\n' "$t"
	cat "$logs/$t.log"
done
elapsed=$(perl -e "printf '%.1f', $(now) - $started")
if [ -n "$failed" ]; then
	printf '\ncheck: FAILED:%s (%s s)\n' "$failed" "$elapsed"
	exit 1
fi
printf 'check: ok (%s s)\n' "$elapsed"
