#!/usr/bin/env bash
# e2e sandbox: a headless macOS VM (Lume) that the e2e layer runs in, so real
# key events are never posted on the host (docs/testing.md "Sandbox VM").
#   sandbox.sh up         install Lume, pull the VM image once, boot headless, provision
#   sandbox.sh down       stop the VM
#   sandbox.sh status     state, IP, provisioning (exit 0 only if running and provisioned)
#   sandbox.sh provision  idempotent guest setup (tools, plugins, Accessibility)
#   sandbox.sh e2e        sync the repo, restore repo-controlled guest state, run the e2e layer
#                         in the guest's GUI session
#                         (SANDBOX_START=0: print a skip line instead of booting a stopped VM)
# Inside a VM, `sandbox.sh e2e` runs the harness directly (make e2e-local).
# Host and guest talk only through Lume: `lume ssh` runs a script file from the shared folder
# (`lume run --shared-dir`), and files travel through that folder. No host ssh/rsync to the guest,
# and no guest command text on a host command line (endpoint security reads both as attacks).
# The commands that change the guest (all but status) are serialized across checkouts by
# $SANDBOX_STATE/lock (tests/sandbox/lock.sh): a second one waits until the first exits.
set -euo pipefail

VM=${SANDBOX_VM:-nvim-e2e}
IMAGE=${SANDBOX_IMAGE:-macos-tahoe-vanilla:latest} # ghcr.io/trycua, ~21 GB download
IMAGE_GB=21
MIN_FREE_GB=25
CPU=4 MEMORY=8GB
STATE=${SANDBOX_STATE:-$HOME/.cache/nvim-e2e-sandbox} # lock, VM log, shared folder (all worktrees)
SHARE=$STATE/share                       # host side of the folder the guest mounts
GSHARE="/Volumes/My Shared Files/share" # the same folder in the guest
GUEST_USER=lume GUEST_PASS=lume
GUEST_REPO=/Users/$GUEST_USER/nvim
GUEST_DATA=/Users/$GUEST_USER/.local/share/nvim
# pinned to the host's versions (docs/testing.md); release builds, no Homebrew bottles
NVIM_VERSION=0.12.5 ZELLIJ_VERSION=0.45.1 ALACRITTY_VERSION=0.17.0
GO_VERSION=1.27.1 GOPLS_VERSION=0.23.0 # the e2e Go fixture (tests/fixtures/build.sh) and gopls
PROVISION_REV=4 # bump when provision() changes
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LOCK=$STATE/lock # held by this process until it exits
# shellcheck source=tests/sandbox/lock.sh
source "$ROOT/tests/sandbox/lock.sh"
export LUME_TELEMETRY_ENABLED=false LUME_UPDATE_CHECK=false

log() { printf 'sandbox: %s\n' "$*" >&2; }
die() {
	log "$*"
	exit 1
}

in_vm() { [ "$(sysctl -n kern.hv_vmm_present 2>/dev/null)" = 1 ]; }

ensure_lume() {
	if ! command -v lume >/dev/null; then
		log "installing Lume (brew install lume)"
		HOMEBREW_NO_AUTO_UPDATE=1 brew install lume >&2
	fi
	lume config telemetry disable >/dev/null 2>&1 || true
}

# $1 field of `lume get --format json` (state, ipAddress, ...); empty if the VM does not exist
vm_field() {
	lume get "$VM" --format json 2>/dev/null | python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except ValueError:
    sys.exit()
d = d[0] if isinstance(d, list) else d
print(d.get(sys.argv[1]) or "")' "$1"
}

# Lume's own view only: a `lume run` process Lume reports as not running is a mismatch that
# `lume ssh` refuses too, so boot_wait handles it instead of treating the VM as up
running() {
	[ "$(vm_field status)" = running ]
}

# the `lume run` process that owns the VM is alive
run_alive() {
	pgrep -qf "libexec/lume run $VM( |\$)"
}

# $1 s multiplied by max(1, 1-min load average / CPU count), as tests/helpers.lua scales deadlines
load_scaled() {
	local load cpus
	load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
	cpus=$(sysctl -n hw.ncpu 2>/dev/null)
	awk -v s="$1" -v l="${load:-0}" -v c="${cpus:-0}" 'BEGIN { f = (c > 0 && l > c) ? l / c : 1; printf "%d\n", s * f + 0.5 }'
}

IP= # cached by boot() / bootstrap_guest() in the main shell
ip() {
	[ -n "$IP" ] && { echo "$IP"; return; }
	local addr mac
	addr=$(vm_field ipAddress)
	if [ -z "$addr" ] && mac=$(vm_field macAddress) && [ -n "$mac" ]; then
		# the DHCP lease of the VM's MAC (vmnet NAT)
		addr=$(awk -v mac="1,$mac" '/ip_address=/ {ip = substr($1, 12)} /hw_address=/ && substr($1, 12) == mac {print ip; exit}' /var/db/dhcpd_leases 2>/dev/null)
	fi
	echo "$addr"
}

# the guest's SSH port accepts TCP, checked without ssh: lume 0.6.1 falls back to the host's
# /usr/bin/ssh (which endpoint security flags) when its own SSH fails, e.g. while the guest boots
port_open() {
	local addr
	addr=$(ip)
	[ -n "$addr" ] && nc -z -G 2 "$addr" 22 >/dev/null 2>&1
}

# until port_open, at most 180 s (load-scaled)
port_wait() {
	local deadline
	deadline=$((SECONDS + $(load_scaled 180)))
	until port_open; do
		[ $SECONDS -lt $deadline ] || return 1
		sleep 2
	done
}

# run "$*" as a bash script in the guest (via a file in the shared folder), output streamed back
gssh() {
	mkdir -p "$SHARE/cmd"
	local script rc=0
	script=$(mktemp "$SHARE/cmd/XXXXXX")
	printf '%s\n' "$*" >"$script"
	lume ssh "$VM" -u "$GUEST_USER" -p "$GUEST_PASS" -t 0 "bash '$GSHARE/cmd/${script##*/}'" || rc=$?
	rm -f "$script"
	return "$rc"
}

# $1 > shared file $2 (relative to the shared folder), for the guest to run or copy
put() {
	mkdir -p "$(dirname "$SHARE/$2")"
	"$1" >"$SHARE/$2"
}

# host dirs/files into the shared folder: plain local copies, then the guest copies from the mount
stage() { rsync -a --delete "$@"; }

create() {
	[ -n "$(vm_field name)" ] && return
	local free
	free=$(df -g "$HOME" | awk 'NR==2 {print $4}')
	if [ $((free - IMAGE_GB * 2)) -lt "$MIN_FREE_GB" ]; then
		die "pulling $IMAGE needs ~$((IMAGE_GB * 2)) GB while it unpacks; ${free} GB free would leave < ${MIN_FREE_GB} GB. Aborted."
	fi
	log "pulling $IMAGE as $VM (~$IMAGE_GB GB, once)"
	lume pull "$IMAGE" "$VM" >&2
	lume set "$VM" --cpu "$CPU" --memory "$MEMORY" >&2
	lume prune >/dev/null 2>&1 || true
}

boot() {
	IP=
	running && return
	mkdir -p "$STATE" "$SHARE"
	if run_alive; then
		log "$VM has a lume run process while Lume reports it $(vm_field status); waiting for it"
	else
		start_run
	fi
	boot_wait
}

# `lume run` in the foreground of a detached long-lived process (not --detach, whose short-lived
# launcher Lume can lose track of); --log-file applies only to --detach, so its output goes to vm.log
start_run() {
	log "booting $VM headless"
	local try
	for try in 1 2 3 4 5; do
		nohup lume run "$VM" --no-display --vnc disabled --shared-dir "$SHARE" >>"$STATE/vm.log" 2>&1 </dev/null &
		disown
		storage_locked || break
		log "$VM still holds its storage after a stop; retrying boot ($try/5)"
		sleep 5
	done
}

# true when the boot just failed because a killed VM process has not released its disk yet
storage_locked() {
	sleep 3
	pgrep -qf "libexec/lume run $VM( |\$)" && return 1
	tail -n 20 "$STATE/vm.log" 2>/dev/null | grep -q "Failed to lock auxiliary storage"
}

# `lume ssh` exit status for "test -d <shared folder>": 0 shared, 1 not shared, else the guest did not answer
share_probe() {
	local out rc=0
	out=$(lume ssh "$VM" -t 10 "test -d '$GSHARE' && echo SHARED || echo UNSHARED" 2>&1) || rc=$?
	case "$out" in
	*UNSHARED*) return 1 ;;
	*SHARED*) return 0 ;;
	esac
	log "lume ssh did not answer (rc=$rc): ${out##*$'\n'}"
	return 2
}

# no caller stops or restarts the shared VM while another holds the lock
require_lock() {
	lock_held_by_me "$LOCK" || die "refusing to $1 $VM without holding $LOCK"
}

# Lume can lose track of a VM (`lume get` says stopped while its `lume run` is alive); then `lume ssh`
# refuses every command. Stop that run and boot again.
restart_vm() {
	require_lock restart
	log "$1; restarting $VM"
	{ port_open && lume ssh "$VM" -t 10 sync >/dev/null 2>&1; } || true # lume stop is a power-off
	lume stop "$VM" >/dev/null 2>&1 || true
	kill_run
	boot
}

# stop the VM's `lume run` process: SIGTERM, SIGKILL after 60 s
kill_run() {
	require_lock stop
	pkill -TERM -f "libexec/lume run $VM( |\$)" 2>/dev/null || true
	for _ in $(seq 60); do run_alive || break; sleep 1; done
	pkill -KILL -f "libexec/lume run $VM( |\$)" 2>/dev/null || true
}

# the guest answers and mounts the shared folder (a VM booted by an older sandbox.sh has none)
ensure_share() {
	local tries=0 rc
	port_wait || die "$VM's SSH port did not open within 180 s ($STATE/vm.log)"
	while :; do
		rc=0; share_probe || rc=$?
		case $rc in
		0) return ;;
		1) restart_vm "$VM runs without the shared folder ($SHARE)"; return ;;
		esac
		tries=$((tries + 1))
		[ $tries -lt 3 ] || { restart_vm "Lume lost track of $VM (lume ssh refuses it)"; return; }
		sleep 3
	done
}

# until the guest answers `lume ssh`, tried only once its SSH port is open (see port_open). A `lume run` that Lume reports as not running for over
# SANDBOX_MISMATCH_S s (default 20, load-scaled) never answers: kill it and boot once more ($1 = 1)
boot_wait() {
	local retry=${1:-1} deadline=$((SECONDS + 180)) grace since=
	grace=$(load_scaled "${SANDBOX_MISMATCH_S:-20}")
	until port_open && lume ssh "$VM" -t 10 true >/dev/null 2>&1; do
		run_alive || die "$VM stopped while booting ($STATE/vm.log)"
		if running; then
			since=
		elif [ -z "$since" ]; then
			since=$SECONDS
		elif [ $((SECONDS - since)) -ge "$grace" ]; then
			local state
			state=$(vm_field status)
			[ "$retry" = 1 ] || die "Lume still reports $VM ${state:-unknown} while its lume run process is alive, after one restart; giving up ($STATE/vm.log)"
			log "Lume reports $VM ${state:-unknown} while its lume run process is alive for ${grace} s; killing it and booting once more"
			kill_run
			start_run
			boot_wait 0
			return
		fi
		[ $SECONDS -lt $deadline ] || die "$VM did not answer SSH within 180 s ($STATE/vm.log)"
		sleep 2
	done
}

# passwordless sudo for the guest user (provisioning needs it); lume ssh logs in with the password
guest_sudo_script() {
	cat <<EOF
echo $GUEST_PASS | sudo -S sh -c 'echo "$GUEST_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/nvim-e2e && chmod 440 /etc/sudoers.d/nvim-e2e'
EOF
}

bootstrap_guest() {
	IP=$(ip)
	ensure_share
	gssh "sudo -n true" >/dev/null 2>&1 && return
	put guest_sudo_script sudo.sh
	gssh "bash '$GSHARE/sudo.sh'" >/dev/null 2>&1 || true
	rm -f "$SHARE/sudo.sh"
	gssh "sudo -n true" >/dev/null || die "passwordless sudo in $VM failed"
}

provisioned() { [ "$(gssh "cat ~/.nvim-e2e-provisioned 2>/dev/null" 2>/dev/null)" = "$PROVISION_REV" ]; }

# guest script (bash, as the guest user with NOPASSWD sudo); idempotent
guest_provision_script() {
	cat <<EOF
set -euo pipefail
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 NONINTERACTIVE=1
step() { printf 'sandbox(guest): %s\n' "\$*"; }
# Homebrew (installs the Xcode Command Line Tools: swiftc, git, python3)
if [ ! -x /opt/homebrew/bin/brew ]; then
	step "installing Homebrew + Command Line Tools (several minutes, once)"
	/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "\$(/opt/homebrew/bin/brew shellenv)"
grep -q 'brew shellenv' ~/.zprofile 2>/dev/null || echo 'eval "\$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
for f in tmux python@3 uv rsync; do brew list --formula "\$f" >/dev/null 2>&1 || { step "brew install \$f"; brew install -q "\$f"; }; done
# the font terminal/alacritty asks for (else Alacritty logs a WARN per start)
brew list --cask font-hack-nerd-font >/dev/null 2>&1 || { step "font-hack-nerd-font"; brew install -q --cask font-hack-nerd-font; }
mkdir -p ~/opt ~/bin
grep -q 'HOME/bin' ~/.zprofile || echo 'export PATH="\$HOME/bin:\$PATH"' >> ~/.zprofile
fetch() { curl -fsSL --retry 3 -o "\$2" "\$1"; }
if [ "\$(~/bin/nvim --version 2>/dev/null | head -1)" != "NVIM v$NVIM_VERSION" ]; then
	step "neovim $NVIM_VERSION"
	rm -rf ~/opt/nvim-macos-arm64 && fetch https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/nvim-macos-arm64.tar.gz /tmp/nvim.tgz
	tar -xzf /tmp/nvim.tgz -C ~/opt && xattr -cr ~/opt/nvim-macos-arm64 && ln -sf ~/opt/nvim-macos-arm64/bin/nvim ~/bin/nvim
fi
if [ "\$(~/bin/zellij --version 2>/dev/null)" != "zellij $ZELLIJ_VERSION" ]; then
	step "zellij $ZELLIJ_VERSION"
	fetch https://github.com/zellij-org/zellij/releases/download/v$ZELLIJ_VERSION/zellij-aarch64-apple-darwin.tar.gz /tmp/zellij.tgz
	tar -xzf /tmp/zellij.tgz -C ~/bin && xattr -c ~/bin/zellij
fi
if [ "\$(~/bin/go version 2>/dev/null | cut -d' ' -f3)" != "go$GO_VERSION" ]; then
	step "go $GO_VERSION"
	rm -rf ~/opt/go && fetch https://go.dev/dl/go$GO_VERSION.darwin-arm64.tar.gz /tmp/go.tgz
	tar -xzf /tmp/go.tgz -C ~/opt && ln -sf ~/opt/go/bin/go ~/bin/go
fi
if [ "\$(~/bin/gopls version 2>/dev/null | head -1 | cut -d' ' -f2)" != "v$GOPLS_VERSION" ]; then
	step "gopls $GOPLS_VERSION (builds once, ~1-2 min)"
	GOBIN=~/bin GOTOOLCHAIN=local GOTELEMETRY=off ~/bin/go install golang.org/x/tools/gopls@v$GOPLS_VERSION
fi
app=/Applications/Alacritty.app
if [ "\$(\$app/Contents/MacOS/alacritty --version 2>/dev/null | cut -d' ' -f2)" != "$ALACRITTY_VERSION" ]; then
	step "Alacritty $ALACRITTY_VERSION"
	fetch https://github.com/alacritty/alacritty/releases/download/v$ALACRITTY_VERSION/Alacritty-v$ALACRITTY_VERSION.dmg /tmp/alacritty.dmg
	mnt=\$(mktemp -d) && hdiutil attach -quiet -nobrowse -mountpoint "\$mnt" /tmp/alacritty.dmg
	sudo rm -rf \$app && sudo cp -R "\$mnt/Alacritty.app" /Applications/ && hdiutil detach -quiet "\$mnt"
	sudo xattr -cr \$app
fi
ln -sf \$app/Contents/MacOS/alacritty ~/bin/alacritty
# guest stays awake and unlocked (the image's unattended setup does most of this)
sudo pmset -a sleep 0 displaysleep 0 disksleep 0 >/dev/null
defaults -currentHost write com.apple.screensaver idleTime 0
EOF
}

# autologin of the guest user (/etc/kcpassword: the password XOR-ed with Apple's key,
# padded to 12 bytes); a policy change (SIP) clears it, and e2e needs a GUI session
guest_autologin_script() {
	cat <<EOF
set -eu
sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser $GUEST_USER
perl -e '@k = (0x7D,0x89,0x52,0x23,0xD2,0xBC,0xDD,0xEA,0xA3,0xB9,0x1F); @p = unpack("C*", "$GUEST_PASS"); push @p, 0 while @p % 12; print pack("C*", map { \$p[\$_] ^ \$k[\$_ % 11] } 0..\$#p)' | sudo tee /etc/kcpassword >/dev/null
sudo chmod 600 /etc/kcpassword
EOF
}

console_user() { gssh "stat -f %Su /dev/console" 2>/dev/null; }

# until the guest user's GUI session is up (autologin), at most $1 s
wait_gui() {
	local deadline=$((SECONDS + ${1:-60}))
	until [ "$(console_user)" = "$GUEST_USER" ]; do
		[ $SECONDS -lt $deadline ] || return 1
		sleep 1
	done
}

# Accessibility (+ PostEvent) for what posts the key events in the guest. The
# system TCC.db is writable only with SIP off; the clients cover the whole
# responsibility chain of `launchctl asuser` from sshd (verified by `keys trusted`).
guest_tcc_script() {
	cat <<'EOF'
set -eu
db="/Library/Application Support/com.apple.TCC/TCC.db"
if ! csrutil status | grep -q disabled; then echo "SIP enabled"; exit 3; fi
now=$(date +%s)
for client in "$@"; do
	for service in kTCCServiceAccessibility kTCCServicePostEvent; do
		type=1; case "$client" in */*) ;; *) type=0 ;; esac
		sudo sqlite3 "$db" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, indirect_object_identifier, flags, last_modified) VALUES ('$service', '$client', $type, 2, 4, 1, 'UNUSED', 0, $now);"
	done
done
sudo killall tccd 2>/dev/null || true
EOF
}

TCC_CLIENTS=(
	/usr/libexec/sshd-keygen-wrapper /usr/libexec/sshd-session /usr/sbin/sshd /bin/bash /bin/sh /bin/zsh
	"/Users/$GUEST_USER/opt/nvim-macos-arm64/bin/nvim" "$GUEST_REPO/.tests/e2e/keys"
	io.alacritty
)

# Each sync stages into a new folder: the guest's VirtioFS mount can serve a cached old copy of a path the
# host rewrote (a stale init.lua broke e2e), but never of a path it has not seen.
sync_dir() {
	local dir
	dir=$(mktemp -d "$SHARE/sync.XXXXXX")
	echo "${dir##*/}"
}

sync_repo() {
	local d
	d=$(sync_dir)
	stage --exclude .git --exclude /.tests --exclude '/.archon/' "$ROOT/" "$SHARE/$d/repo/"
	# test deps the host already pinned (mini.nvim); the guest builds keys and the venv itself
	mkdir -p "$SHARE/$d/deps"
	[ ! -d "$ROOT/.tests/deps" ] || stage "$ROOT/.tests/deps/" "$SHARE/$d/deps/"
	gssh "rsync -a --delete --exclude /.tests '$GSHARE/$d/repo/' $GUEST_REPO/ && mkdir -p $GUEST_REPO/.tests && rsync -a --delete '$GSHARE/$d/deps/' $GUEST_REPO/.tests/deps/"
	rm -rf "${SHARE:?}/$d"
	sync_plugins
}

# host ~/.local/share/nvim/{lazy,site} into the guest, again when lazy-lock.json changes
sync_plugins() {
	local data=${NVIM_TEST_DATA_DIR:-$HOME/.local/share/nvim} stamp d
	stamp=$(shasum "$ROOT/lazy-lock.json" | cut -c1-12)
	[ "$(gssh "cat $GUEST_DATA/.lock-stamp 2>/dev/null")" = "$stamp" ] && return
	log "syncing plugins (lazy-lock.json $stamp)"
	d=$(sync_dir)
	stage "$data/lazy" "$data/site" "$SHARE/$d/"
	gssh "mkdir -p $GUEST_DATA && rsync -a --delete '$GSHARE/$d/lazy' '$GSHARE/$d/site' $GUEST_DATA/ && echo $stamp > $GUEST_DATA/.lock-stamp"
	rm -rf "${SHARE:?}/$d"
}

# the guest state the checkout controls (tests/sandbox/guest_restore.sh)
restore_guest() { gssh "$GUEST_REPO/tests/sandbox/guest_restore.sh"; }

provision() {
	require_lock provision # it stops and reboots the VM
	bootstrap_guest
	local t0=$SECONDS
	# as a file: brew and the Homebrew installer would eat a script piped into bash's stdin
	put guest_provision_script provision.sh
	gssh "bash '$GSHARE/provision.sh' </dev/null"
	# the zellij config loads the navigator plugin from its absolute host path
	local plugin_dir
	plugin_dir=$(grep -o 'file:[^"]*vim-zellij-navigator.wasm' "$ROOT/terminal/zellij/config.kdl" | head -1 | sed 's|^file:||; s|/[^/]*$||')
	gssh "sudo mkdir -p '$plugin_dir' && sudo chown -R $GUEST_USER '${plugin_dir%%/.config/*}'"
	stage "$ROOT/terminal/zellij/plugins/vim-zellij-navigator.wasm" "$SHARE/"
	gssh "cp '$GSHARE/vim-zellij-navigator.wasm' '$plugin_dir/'"
	sync_repo
	gssh "cd $GUEST_REPO && zsh -lc 'tests/e2e/build.sh >/dev/null && make -s deps deps-shortcuts'"
	if ! gssh "csrutil status" | grep -q disabled; then
		log "disabling SIP in the guest (lume sip off: 3 boots over VNC, ~3 min, once)"
		# lume sip drives Recovery with vncdo: a private venv, nothing installed globally
		if [ ! -x "$STATE/venv/bin/vncdo" ]; then
			python3 -m venv "$STATE/venv" && "$STATE/venv/bin/pip" install -q vncdotool >&2
		fi
		gssh "sync" || true # lume stop is a power-off
		lume stop "$VM" >/dev/null
		if ! PATH="$STATE/venv/bin:$PATH" lume sip off "$VM" --yes --screenshot-dir "$STATE/sip" >&2; then
			log "lume sip off failed; driving Recovery directly (tests/sandbox/sip_off.sh)"
			lume stop "$VM" >/dev/null 2>&1 || true
			"$ROOT/tests/sandbox/sip_off.sh" "$VM" "$STATE/venv/bin/vncdo" "$STATE"
		fi
		boot
		bootstrap_guest
		gssh "csrutil status" | grep -q disabled || die "SIP is still enabled in the guest (screenshots: $STATE/sip)"
	fi
	put guest_autologin_script autologin.sh
	gssh "bash '$GSHARE/autologin.sh'"
	if ! wait_gui 5; then
		log "no GUI session; restarting the guest into autologin"
		gssh "sync; sudo shutdown -h now" || true
		for _ in $(seq 60); do running || break; sleep 1; done
		lume stop "$VM" >/dev/null 2>&1 || true
		boot
		bootstrap_guest
		wait_gui 90 || die "the guest did not log in $GUEST_USER (autologin); see: lume attach $VM --display vnc"
	fi
	put guest_tcc_script tcc.sh
	gssh "bash '$GSHARE/tcc.sh' $(printf '%q ' "${TCC_CLIENTS[@]}") </dev/null"
	gssh "echo $PROVISION_REV > ~/.nvim-e2e-provisioned"
	log "provisioned in $((SECONDS - t0)) s"
	gui "$GUEST_REPO/.tests/e2e/keys trusted" || die "Accessibility is not granted in the guest (see above: the responsible app); open VNC (lume attach $VM --display vnc), System Settings > Privacy & Security > Accessibility, enable it, then: make sandbox-provision"
}

# run a command in the guest's logged-in GUI session (Aqua), output streamed back
gui() {
	gssh "uid=\$(id -u); cd $GUEST_REPO && sudo launchctl asuser \$uid sudo -u $GUEST_USER -H zsh -lc $(printf %q "$1")"
}

start_vm() {
	in_vm && die "already inside a VM"
	ensure_lume
	create
	boot
	bootstrap_guest
}

up() {
	start_vm
	if ! provisioned; then provision; fi
	status
}

status() {
	if ! command -v lume >/dev/null || [ -z "$(vm_field name)" ]; then
		echo "sandbox: $VM not created (make sandbox-up)"
		return 1
	fi
	if ! running; then
		echo "sandbox: $VM $(vm_field status) (make sandbox-up)"
		return 1
	fi
	if provisioned; then
		echo "sandbox: $VM running at $(ip), provisioned (rev $PROVISION_REV)"
	else
		echo "sandbox: $VM running at $(ip), NOT provisioned (make sandbox-provision)"
		return 1
	fi
}

e2e() {
	if in_vm; then
		exec make -s -C "$ROOT" e2e-local
	fi
	[ "${E2E:-}" = 0 ] && {
		echo "e2e: SKIPPED: E2E=0"
		return
	}
	sandbox_lock "$LOCK"
	if ! command -v lume >/dev/null || ! running; then
		if [ "${SANDBOX_START:-1}" != 1 ]; then
			echo "e2e: SKIPPED: sandbox down — make sandbox-up"
			return
		fi
		up >/dev/null
	fi
	bootstrap_guest
	if ! provisioned; then provision >&2; fi
	sync_repo
	restore_guest # per run, not in provision(): independent of PROVISION_REV
	wait_gui 60 || die "no GUI session in the guest after 60 s (make sandbox-provision)"
	local vars=""
	for v in CASE E2E_FOCUS; do
		[ -n "${!v:-}" ] && vars="$vars $v=$(printf %q "${!v}")"
	done
	gui "make -s e2e-local$vars"
}

cmd=${1:-status}
case "$cmd" in
status | e2e) "$cmd" ;;
up)
	sandbox_lock "$LOCK"
	up
	;;
provision)
	sandbox_lock "$LOCK"
	start_vm
	provision
	status
	;;
down)
	sandbox_lock "$LOCK"
	if command -v lume >/dev/null && { running || run_alive; }; then
		require_lock stop
		{ bootstrap_guest && gssh "sync"; } || true # lume stop is a power-off
		lume stop "$VM" >/dev/null 2>&1 || true
		# the owning `lume run` stops the VM on SIGTERM (when lume get lost track of it)
		pkill -TERM -f "libexec/lume run $VM( |\$)" || true
		for _ in $(seq 30); do { running || run_alive; } || break; sleep 1; done
	fi
	echo "sandbox: $VM stopped"
	;;
ssh)
	shift
	sandbox_lock "$LOCK"
	gssh "$@"
	;;
*) die "usage: sandbox.sh up|down|status|provision|e2e|ssh <cmd>" ;;
esac
