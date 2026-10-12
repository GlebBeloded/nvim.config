#!/usr/bin/env bash
# e2e sandbox: a headless macOS VM (Lume) that the e2e layer runs in, so real
# key events are never posted on the host (docs/testing.md "Sandbox VM").
#   sandbox.sh up         install Lume, pull the VM image once, boot headless, provision
#   sandbox.sh down       stop the VM
#   sandbox.sh status     state, IP, provisioning (exit 0 only if running and provisioned)
#   sandbox.sh provision  idempotent guest setup over SSH (tools, plugins, Accessibility)
#   sandbox.sh e2e        sync the repo, run the e2e layer in the guest's GUI session
#                         (SANDBOX_START=0: print a skip line instead of booting a stopped VM)
# Inside a VM, `sandbox.sh e2e` runs the harness directly (make e2e-local).
set -euo pipefail

VM=${SANDBOX_VM:-nvim-e2e}
IMAGE=${SANDBOX_IMAGE:-macos-tahoe-vanilla:latest} # ghcr.io/trycua, ~21 GB download
IMAGE_GB=21
MIN_FREE_GB=25
CPU=4 MEMORY=8GB
STATE=${SANDBOX_STATE:-$HOME/.cache/nvim-e2e-sandbox} # ssh key, control sockets (shared by worktrees)
GUEST_USER=lume GUEST_PASS=lume
GUEST_REPO=/Users/$GUEST_USER/nvim
GUEST_DATA=/Users/$GUEST_USER/.local/share/nvim
# pinned to the host's versions (docs/testing.md); release builds, no Homebrew bottles
NVIM_VERSION=0.12.5 ZELLIJ_VERSION=0.45.1 ALACRITTY_VERSION=0.17.0
PROVISION_REV=4 # bump when provision() changes
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
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

# `lume get` can report a running VM as stopped (seen after a detached run); the
# `lume run` process owning the VM is the ground truth
running() {
	[ "$(vm_field status)" = running ] || pgrep -qf "libexec/lume run $VM( |\$)"
}

IP= # cached by boot() / bootstrap_ssh() in the main shell
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

ssh_opts() {
	echo -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
		-o ConnectTimeout=5 -o ControlMaster=auto -o "ControlPath=/tmp/nve2e-%C" -o ControlPersist=300 \
		-i "$STATE/id_ed25519"
}

# guest shell command over key-based ssh (after provision), stdout/stderr streamed
gssh() {
	# shellcheck disable=SC2046,SC2029 # ssh_opts is a word list; the command runs in the guest
	ssh $(ssh_opts) "$GUEST_USER@$(ip)" "$@"
}

grsync() {
	rsync -a --delete -e "ssh $(ssh_opts)" "$@"
}

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
	log "booting $VM headless"
	mkdir -p "$STATE"
	lume run "$VM" --no-display --detach --log-file "$STATE/vm.log" >/dev/null
	boot_wait
}

boot_wait() {
	local deadline=$((SECONDS + 180))
	until [ -n "$(ip)" ] && lume ssh "$VM" -t 10 true >/dev/null 2>&1; do
		pgrep -qf "libexec/lume run $VM( |\$)" || die "$VM stopped while booting ($STATE/vm.log)"
		[ $SECONDS -lt $deadline ] || die "$VM did not answer SSH within 180 s ($STATE/vm.log)"
		sleep 2
	done
}

# key-based SSH + passwordless sudo, via lume's password SSH (lume/lume)
bootstrap_ssh() {
	mkdir -p "$STATE"
	IP=$(ip)
	[ -f "$STATE/id_ed25519" ] || ssh-keygen -q -t ed25519 -N '' -C nvim-e2e-sandbox -f "$STATE/id_ed25519"
	gssh true 2>/dev/null && return
	local key
	key=$(cat "$STATE/id_ed25519.pub")
	lume ssh "$VM" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF '$key' ~/.ssh/authorized_keys 2>/dev/null || echo '$key' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys" >/dev/null
	lume ssh "$VM" "echo $GUEST_PASS | sudo -S sh -c 'echo \"$GUEST_USER ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/nvim-e2e && chmod 440 /etc/sudoers.d/nvim-e2e'" >/dev/null 2>&1
	gssh true || die "key-based SSH to $VM failed"
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

sync_repo() {
	grsync --exclude .git --exclude /.tests/ --exclude '/.archon/' "$ROOT/" "$GUEST_USER@$(ip):$GUEST_REPO/"
	# test deps the host already pinned (mini.nvim); the guest builds keys and the venv itself
	[ -d "$ROOT/.tests/deps" ] && grsync "$ROOT/.tests/deps/" "$GUEST_USER@$(ip):$GUEST_REPO/.tests/deps/"
	sync_plugins
}

# host ~/.local/share/nvim/{lazy,site} into the guest, again when lazy-lock.json changes
sync_plugins() {
	local data=${NVIM_TEST_DATA_DIR:-$HOME/.local/share/nvim} stamp
	stamp=$(shasum "$ROOT/lazy-lock.json" | cut -c1-12)
	[ "$(gssh "cat $GUEST_DATA/.lock-stamp 2>/dev/null")" = "$stamp" ] && return
	log "syncing plugins (lazy-lock.json $stamp)"
	gssh "mkdir -p $GUEST_DATA"
	grsync "$data/lazy" "$data/site" "$GUEST_USER@$(ip):$GUEST_DATA/"
	gssh "echo $stamp > $GUEST_DATA/.lock-stamp"
}

provision() {
	bootstrap_ssh
	local t0=$SECONDS
	# as a file: brew and the Homebrew installer would eat a script piped into bash's stdin
	guest_provision_script | gssh "cat > /tmp/nvim-e2e-provision.sh"
	gssh "bash /tmp/nvim-e2e-provision.sh </dev/null"
	# the zellij config loads the navigator plugin from its absolute host path
	local plugin_dir
	plugin_dir=$(grep -o 'file:[^"]*vim-zellij-navigator.wasm' "$ROOT/terminal/zellij/config.kdl" | head -1 | sed 's|^file:||; s|/[^/]*$||')
	gssh "sudo mkdir -p '$plugin_dir' && sudo chown -R $GUEST_USER '${plugin_dir%%/.config/*}'"
	grsync "$ROOT/terminal/zellij/plugins/vim-zellij-navigator.wasm" "$GUEST_USER@$(ip):$plugin_dir/"
	sync_repo
	# the app menu must leave Cmd+Q and Cmd+H to the terminal (org.alacritty defaults)
	gssh "$GUEST_REPO/terminal/macos_menu_keys.sh >/dev/null"
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
		bootstrap_ssh
		gssh "csrutil status" | grep -q disabled || die "SIP is still enabled in the guest (screenshots: $STATE/sip)"
	fi
	guest_autologin_script | gssh "bash -s"
	if ! wait_gui 5; then
		log "no GUI session; restarting the guest into autologin"
		gssh "sync; sudo shutdown -h now" || true
		for _ in $(seq 60); do running || break; sleep 1; done
		lume stop "$VM" >/dev/null 2>&1 || true
		boot
		bootstrap_ssh
		wait_gui 90 || die "the guest did not log in $GUEST_USER (autologin); see: lume attach $VM --display vnc"
	fi
	guest_tcc_script | gssh "cat > /tmp/nvim-e2e-tcc.sh"
	gssh "bash /tmp/nvim-e2e-tcc.sh $(printf '%q ' "${TCC_CLIENTS[@]}") </dev/null"
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
	bootstrap_ssh
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
	if [ -f "$STATE/id_ed25519" ] && provisioned; then
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
	if ! command -v lume >/dev/null || ! running; then
		if [ "${SANDBOX_START:-1}" != 1 ]; then
			echo "e2e: SKIPPED: sandbox down — make sandbox-up"
			return
		fi
		up >/dev/null
	fi
	bootstrap_ssh
	if ! provisioned; then provision >&2; fi
	sync_repo
	wait_gui 60 || die "no GUI session in the guest after 60 s (make sandbox-provision)"
	local vars=""
	for v in CASE E2E_FOCUS; do
		[ -n "${!v:-}" ] && vars="$vars $v=$(printf %q "${!v}")"
	done
	gui "make -s e2e-local$vars"
}

cmd=${1:-status}
case "$cmd" in
up | status | e2e) "$cmd" ;;
provision)
	start_vm
	provision
	status
	;;
down)
	if command -v lume >/dev/null && running; then
		{ bootstrap_ssh && gssh "sync"; } || true # lume stop is a power-off
		lume stop "$VM" >/dev/null 2>&1 || true
		# the owning `lume run` stops the VM on SIGTERM (when lume get lost track of it)
		pkill -TERM -f "libexec/lume run $VM( |\$)" || true
		for _ in $(seq 30); do running || break; sleep 1; done
	fi
	echo "sandbox: $VM stopped"
	;;
ssh)
	shift
	gssh "$@"
	;;
*) die "usage: sandbox.sh up|down|status|provision|e2e|ssh <cmd>" ;;
esac
