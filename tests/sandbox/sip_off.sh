#!/usr/bin/env bash
# Disable SIP in the stopped sandbox VM when `lume sip off` cannot (Lume 0.6.1
# opens the Recovery app menu instead of Utilities on macOS 26.4 Recovery).
# Drives the guest's Recovery over the VM's own VNC server (lume, 127.0.0.1:PORT,
# never the host's Screen Sharing): Options > Continue > language > Utilities >
# Terminal > `csrutil disable`, then a normal boot through the "verify startup
# disk" password prompt. Coordinates are framebuffer pixels (1920x1440). Leaves the VM running.
#   sip_off.sh <vm> <vncdo> <state dir>
set -euo pipefail
VM=$1 VNCDO=$2 STATE=$3
PORT=5999 PASS=$(head -c 12 /dev/urandom | base64 | tr -dc a-z0-9)
SHOTS=$STATE/sip
mkdir -p "$SHOTS"

vnc() {
	lsof -nP -iTCP:$PORT -sTCP:LISTEN | grep -q '^lume ' || { echo "sip_off: port $PORT is not the VM's VNC server" >&2; exit 1; }
	"$VNCDO" -s "127.0.0.1::$PORT" -p "$PASS" "$@" 2>/dev/null
}
step() {
	echo "sip_off: $1" >&2
	sleep "$2"
	vnc capture "$SHOTS/$3.png"
}

lume run "$VM" --recovery-mode true --display none --vnc-port $PORT --vnc-password "$PASS" --detach \
	--log-file "$STATE/recovery.log" >/dev/null
trap 'lume stop "$VM" >/dev/null 2>&1 || true' EXIT
step "boot picker" 25 1-picker
vnc move 1183 627 click 1 pause 0.3 click 1 # Options
step "Options selected" 3 2-options
vnc move 1183 883 click 1 # Continue
step "Recovery booting" 100 3-language
vnc move 1692 1262 click 1 # language: next
step "Recovery Options" 15 4-recovery
vnc move 487 28 click 1 pause 1 move 497 193 click 1 # Utilities > Terminal
step "Terminal" 5 5-terminal
vnc type "csrutil disable" key enter pause 3 type y key enter pause 2 type lume key enter pause 2 type lume key enter
step "csrutil disable" 8 6-csrutil
# a clean halt writes the new policy to NVRAM; `lume stop` alone loses it
vnc type "shutdown -h now" key enter
for _ in $(seq 60); do
	lume get "$VM" --format json | grep -q '"status" : "stopped"' && break
	sleep 2
done
lume stop "$VM" >/dev/null 2>&1 || true
trap - EXIT
lume run "$VM" --display none --vnc-port $PORT --vnc-password "$PASS" --detach --log-file "$STATE/vm.log" >/dev/null
step "normal boot: verify startup disk prompt" 35 7-verify
vnc move 960 893 click 1 pause 0.5 type lume key enter
step "login window (autologin pauses once after a policy change)" 30 8-login
vnc move 960 1286 click 1 pause 0.5 type lume key enter
step "logged in" 15 9-desktop
echo "sip_off: done (screenshots in $SHOTS)" >&2
