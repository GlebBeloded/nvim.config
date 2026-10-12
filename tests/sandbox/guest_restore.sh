#!/usr/bin/env bash
# Guest-side restore of the state the repo controls, run by `sandbox.sh e2e` before every
# e2e run so a result never depends on the branch that ran in the VM before:
# the defaults domain is deleted, then the checkout's terminal/macos_*.sh apply their setup.
#   guest_restore.sh [domain]   domain: defaults domain or plist path (default org.alacritty)
set -euo pipefail

domain=${1:-org.alacritty}
root=$(cd "$(dirname "$0")/../.." && pwd)

# a missing domain is already reset
reset_domains() {
	defaults read "$domain" >/dev/null 2>&1 || return 0
	defaults delete "$domain"
}

apply_terminal_setup() {
	local setup
	shopt -s nullglob
	for setup in "$root"/terminal/macos_*.sh; do
		if [ -x "$setup" ]; then "$setup" "$domain" >/dev/null; fi
	done
	shopt -u nullglob
}

reset_domains
apply_terminal_setup
