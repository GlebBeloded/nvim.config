# shellcheck shell=bash
# Host-side mkdir lock that serializes sandbox.sh commands changing the guest
# across checkouts (docs/testing.md "Sandbox VM"). Sourced; call `sandbox_lock <dir>`:
# it returns once this process owns <dir> and releases it when the process exits.
#   <dir>/owner   "<pid> <start time>" and the owner's checkout ($ROOT)
#   SANDBOX_LOCK_POLL     s between attempts while another process holds it (default 1)
#   SANDBOX_LOCK_TIMEOUT  s to wait before giving up (default 3600)
# A lock whose owner is gone (pid not running, or reused by a process started later) is reclaimed.

LOCK_HELD= # the dir this process owns, released on exit

lock_log() { printf 'sandbox: %s\n' "$*" >&2; }

# start time of pid $1 (empty if it does not run); with the pid it identifies the process
lock_started() { ps -o lstart= -p "$1" 2>/dev/null; }

# take $1 if free; mkdir is atomic, so only one caller wins
lock_try() {
	mkdir "$1" 2>/dev/null || return 1
	# written aside and renamed: a reader sees no owner record or a whole one, never a partial one
	printf '%s %s\n%s\n' "$$" "$(lock_started $$)" "${ROOT:-$PWD}" >"$1/owner.$$"
	mv -f "$1/owner.$$" "$1/owner"
	LOCK_HELD=$1
	trap lock_release EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
}

# the owner record of $1: "<pid> <start time>"
lock_owner() { head -1 "$1/owner" 2>/dev/null; }

# a lock dir without an owner record is alive: its owner is between mkdir and the write
lock_owner_alive() {
	local record pid
	[ -f "$1/owner" ] || return 0
	record=$(lock_owner "$1")
	pid=${record%% *}
	[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$pid $(lock_started "$pid")" = "$record" ]
}

# move a stale $1 aside; only one reclaimer's mv succeeds
lock_reclaim() {
	local stale="$1.stale.$$"
	mv "$1" "$stale" 2>/dev/null || return 0
	lock_log "reclaiming stale lock $1 ($(head -1 "$stale/owner" 2>/dev/null))"
	rm -rf "$stale"
}

lock_wait() {
	local dir=$1 poll=${SANDBOX_LOCK_POLL:-1} timeout=${SANDBOX_LOCK_TIMEOUT:-3600}
	local deadline=$((SECONDS + timeout)) said=
	until lock_try "$dir"; do
		if ! lock_owner_alive "$dir"; then
			lock_reclaim "$dir"
			continue
		fi
		if [ -z "$said" ]; then
			lock_log "waiting for sandbox lock held by $(lock_holder "$dir") at $dir"
			said=1
		fi
		if [ $SECONDS -gt $deadline ]; then
			lock_log "gave up after ${timeout} s waiting for $dir ($(lock_holder "$dir"))"
			exit 1
		fi
		sleep "$poll"
	done
}

# "pid N (<root>)" of the holder of $1
lock_holder() {
	local record root
	record=$(lock_owner "$1")
	root=$(sed -n 2p "$1/owner" 2>/dev/null)
	echo "pid ${record%% *} (${root:-unknown checkout})"
}

lock_release() {
	[ -n "$LOCK_HELD" ] || return 0
	if [ "$(lock_owner "$LOCK_HELD")" = "$$ $(lock_started $$)" ]; then
		rm -rf "$LOCK_HELD"
	fi
	LOCK_HELD=
}

# fails unless this process holds $1: stopping or restarting the shared VM needs the lock
lock_held_by_me() {
	[ -n "$LOCK_HELD" ] && [ "$LOCK_HELD" = "$1" ] && [ "$(lock_owner "$1")" = "$$ $(lock_started $$)" ]
}

sandbox_lock() {
	mkdir -p "$(dirname "$1")"
	lock_wait "$1"
}
