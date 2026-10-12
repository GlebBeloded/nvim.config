#!/usr/bin/env sh
# Run make targets concurrently: one status line per target as it finishes,
# then the full log of every failed target. Exit 1 if any failed.
#   tests/check.sh lint types test +smoke-startup
# A target prefixed with "+" runs alone after all the others (timing-sensitive).
set -u

MAKE=${MAKE:-make}
logs=$(mktemp -d "${TMPDIR:-/tmp}/check.XXXXXX")
trap 'rm -rf "$logs"' EXIT INT TERM

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

parallel="" serial=""
for t in "$@"; do
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
