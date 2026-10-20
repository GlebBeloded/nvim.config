#!/usr/bin/env bash
# Removes stale Neovim temp dirs ($TMPDIR/nvim.$USER/<random>) that no live process uses. A test child killed after a
# hang (tests/parallel.lua) or an interrupted run leaves its dir behind, with the isolated data dirs and language
# servers its tests copied in: 16k dirs and ~18 GB filled the disk on 2026-10-19. Dirs younger than PRUNE_TMP_MIN
# minutes (default 720) are kept, and so is any dir a running process names in its arguments or holds open.
#   tests/prune_tmp.sh [root]   root defaults to ${TMPDIR:-/tmp}/nvim.$USER
set -euo pipefail

root=${1:-${TMPDIR:-/tmp}/nvim.$USER}
root=$(printf '%s' "${root%/}" | tr -s /) # $TMPDIR ends in /: `T//nvim.<user>` never matches a child's `T/nvim.<user>`
[ -d "$root" ] || exit 0
minutes=${PRUNE_TMP_MIN:-720}
base=$(basename "$root")

live=$(mktemp)
trap 'rm -f "$live"' EXIT
{
	ps -Ao command= || true
	lsof -c nvim -c gopls -c node -c lua-language -c rust-analyzer -c python -Fn 2>/dev/null || true # whole-host lsof is slow
} | grep -o "$base/[A-Za-z0-9_]*" | sed "s|^$base/||" | sort -u >"$live" || true

removed=0
while IFS= read -r dir; do
	name=${dir##*/}
	grep -qxF "$name" "$live" && continue
	chmod -R u+rwX "$dir" 2>/dev/null || true # read-only fixtures (the `billing` repo) and write-only dirs block rm
	rm -rf "$dir"
	removed=$((removed + 1))
done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -mmin "+$minutes")
[ "$removed" -eq 0 ] || echo "prune-tmp: removed $removed stale Neovim temp dirs from $root"

# language servers a killed test child left behind: reparented to launchd (ppid 1) with their XDG dirs under
# $root; they live on for days, and each kept writing the Go build cache (10 gopls, Oct 2026)
# (one `ps` for all: per-process calls took a minute; system binaries hide their env, servers do not)
orphans=0
for pid in $(ps eww -Ao pid=,ppid=,command= | awk -v needle="XDG_DATA_HOME=$root/" '$2 == 1 && index($0, needle) {print $1}'); do
	pkill -P "$pid" 2>/dev/null || true
	kill "$pid" 2>/dev/null && orphans=$((orphans + 1))
done
[ "$orphans" -eq 0 ] || echo "prune-tmp: stopped $orphans orphaned test processes"
