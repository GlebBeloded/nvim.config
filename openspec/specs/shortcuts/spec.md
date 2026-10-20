# shortcuts Specification

## Purpose
The user-facing contract "physical shortcut → intended action" for the whole key path Alacritty → zellij → Neovim on macOS (Alacritty 0.17, zellij 0.45, Neovim 0.12). Alacritty `[[keyboard.bindings]]` with `chars` turn Command shortcuts into byte sequences, zellij (`keybinds clear-defaults=true`, default mode `normal`) may consume a key or hand it to the vim-zellij-navigator plugin, and Neovim maps what arrives. The Alacritty and zellij configs are external and unversioned; they are read from `$ALACRITTY_CONFIG_DIR` / `$ZELLIJ_CONFIG_DIR`, else `<repo>/terminal/<tool>`, else `~/.config/<tool>`. This spec describes current behaviour, including collisions.

Unlike other capabilities, these scenarios are not verified in a headless child Neovim alone. They run in three layers (docs/testing.md): **chain** (static: parse the real configs, route keys, check maparg in a child Neovim), **stack** (real zellij with the user's keybinds in a tmux pty, real Neovim config, bytes fed with `tmux send-keys -H`) and **e2e** (a dedicated real Alacritty instance with the repo's config, real macOS key events posted to its process; skipped without Accessibility permission).

## Requirements

### Requirement: Shortcut table
The chain SHALL route every shortcut in the shortcut table (section "Shortcut table" below) as listed, with zellij in `normal` mode and the focused zellij pane running Neovim in normal mode. Cmd+9 SHALL have no normal-mode mapping. Cmd+Shift+F SHALL invoke `require("gleb.picker").grep_live`. Cmd+Shift+A SHALL send `\eA`, pass through zellij, arrive as `<M-A>`, and invoke `require("gleb.find_action").open`.

#### Scenario: Alacritty bindings match the shortcut table
- **WHEN** the effective Alacritty bindings (imports followed) are parsed
- **THEN** every `chars` binding outside Vi mode has a `chars` row with the same bytes, every `chars` row has such a binding, and every `kitty` row's bytes equal Alacritty's kitty flag-1 encoding of the shortcut

#### Scenario: Every Alacritty chars binding can match a key press
- **WHEN** the effective Alacritty bindings (imports followed) are parsed
- **THEN** no `chars` binding outside Vi mode has `Shift` in its mods together with a non-letter character key (`Minus`, `Equals`, `Slash`, `LBracket`, `RBracket`, `Key0`–`Key9` and other punctuation keys), because Alacritty 0.17 matches the shifted character (`_`, `+`, ...) and such a binding never fires; each offending binding is reported with its key, mods and bytes

#### Scenario: zellij routes every shortcut as in the table
- **WHEN** the zellij keybinds are resolved for `normal` mode and each row's bytes are decoded the way zellij parses them
- **THEN** the route is the row's *zellij* column

#### Scenario: Locked mode passes every shortcut through
- **WHEN** the zellij keybinds are resolved for `locked` mode
- **THEN** every row's bytes are written to the pane unchanged

#### Scenario: Neovim receives the key in the table
- **WHEN** the bytes zellij writes to the Neovim pane for a row are decoded the way Neovim's TUI decodes them
- **THEN** the key is the row's *Neovim receives* column

#### Scenario: Neovim mappings match the table
- **WHEN** the full config is loaded, VeryLazy has fired, and `vim.fn.maparg(<received key>, "n", false, true)` is read for each row
- **THEN** it matches the row's *Mapping* column except that Cmd+9 has no mapping, including Cmd+Shift+F invoking `require("gleb.picker").grep_live` and Cmd+Shift+A invoking `require("gleb.find_action").open`

### Requirement: Collisions
The chain SHALL have exactly the zellij `normal`-mode bindings in the collision table (section "Collision table" below) shadowing a global Neovim mapping (any mode): keys zellij consumes, and navigator keys whose written bytes differ from the key that was sent.

#### Scenario: Collision report matches the collision table
- **WHEN** every `normal`-mode zellij binding is decoded to Neovim key notation and looked up with `maparg` in modes `n x s o i c t` of the full config
- **THEN** the shadowed keys are exactly the collision table

### Requirement: Real zellij delivers shortcuts
The stack SHALL behave as the shortcut table when real zellij 0.45 runs the user's keybinds (session serialization off, fixed two-pane layout: Neovim with the real config on the left, `cat` on the right) inside a tmux pty and the rows' bytes are written with `tmux send-keys -H`.

#### Scenario: Every passed shortcut reaches its Neovim key through zellij
- **WHEN** a recorder mapping is set in Neovim normal mode for each row's *Neovim receives* key and the row's bytes are sent
- **THEN** the recorder for exactly that key fires

#### Scenario: Consumed shortcuts never reach Neovim
- **WHEN** a recorder mapping is set for the key that was sent and the bytes of Cmd+J, Cmd+K, Cmd+[ and Cmd+] are sent
- **THEN** no recorder fires and the Neovim pane stays focused

#### Scenario: Ctrl+Return reaches Neovim through the kitty keyboard protocol
- **WHEN** Neovim has negotiated the kitty keyboard protocol with zellij (Neovim queries `CSI ? u`, zellij answers) and `\e[13;5u` is sent
- **THEN** Neovim receives `<C-CR>`, not `<CR>` (zellij would downgrade it for a non-kitty pane)

#### Scenario: Cmd+H moves to the left Neovim split
- **WHEN** two Neovim windows exist side by side, the cursor is in the right one, and `\x08` is sent
- **THEN** the current Neovim window is the left one and zellij focus stays on the Neovim pane

#### Scenario: Cmd+Shift+J moves to the Neovim split below
- **WHEN** two Neovim windows exist stacked, the cursor is in the top one, and `\eJ` is sent
- **THEN** the current Neovim window is the bottom one (the navigator rewrites resize to `<M-j>`)

#### Scenario: Cmd+L at the rightmost Neovim split moves zellij focus right
- **WHEN** Neovim has one window and `\x0c` is sent
- **THEN** zellij focus moves to the `cat` pane on the right

#### Scenario: Cmd+H in a non-Neovim pane moves zellij focus left
- **WHEN** the `cat` pane is focused and `\x08` is sent
- **THEN** zellij focus moves to the Neovim pane on the left

### Requirement: The stack harness retries transient zellij CLI failures
The stack harness SHALL read zellij state through `zellij action` calls that retry zellij's transient CLI failures (`There is no active session!`, or `list-clients` with no client row) until a valid answer or a bounded deadline, so a case fails only when the session or its client is really gone.

#### Scenario: The stack harness retries a transient zellij CLI failure
- **WHEN** `focused_pane()` of a `tests.shortcuts.stack` Stack is called with `zellij` stubbed on `PATH` so that `action list-clients` first exits 1 printing `There is no active session!`, then exits 0 with only the header line, then prints a client row on `terminal_0`
- **THEN** it returns `terminal_0` and the stub was called 3 times

#### Scenario: The stack harness fails when the zellij session stays gone
- **WHEN** `focused_pane()` is called with `zellij` stubbed on `PATH` so that every `action list-clients` exits 1 printing `There is no active session!`
- **THEN** it raises an error containing `There is no active session!` within the harness deadline

#### Scenario: The stack harness keeps a zellij CLI retry within the outer wait
- **WHEN** `M.wait_for` polls `focused_pane()` with a 300 ms timeout, the Stack has the default CLI deadline, and every stubbed `action list-clients` exits 1 printing `There is no active session!`
- **THEN** it raises an error containing `There is no active session!` in under 2 s

### Requirement: The stack harness shows what blocks Neovim
When Neovim reports a blocking mode (a startup error or hit-enter prompt), the stack and e2e harness SHALL fail the RPC call with the mode and the last non-blank lines of the Neovim pane as zellij draws it, instead of only the mode.

#### Scenario: The stack harness shows the screen that blocks Neovim
- **WHEN** `lua()` of a `tests.shortcuts.stack` Stack is called while Neovim reports mode `r` as blocking and the stubbed `zellij action dump-screen` prints `E5113: kmap is nil` above `Press ENTER or type command to continue`
- **THEN** it raises an error containing `blocked in mode r`, `E5113: kmap is nil` and the prompt line

### Requirement: The app menu leaves Cmd+Q and Cmd+H to the terminal
The repo SHALL provide an idempotent macOS setup step that moves Alacritty's app-menu key equivalents for "Quit alacritty" to Cmd+Option+Control+Q and "Hide alacritty" to Cmd+Option+Control+H in the `org.alacritty` defaults domain while keeping every other entry. The host SHALL apply it with a make target, and the sandbox VM SHALL apply it before e2e.

#### Scenario: Menu key setup moves Quit and Hide off Cmd+Q and Cmd+H
- **WHEN** the setup step runs against an empty defaults plist
- **THEN** its `NSUserKeyEquivalents` is exactly `"Quit alacritty" = "@~^q"` and `"Hide alacritty" = "@~^h"`

#### Scenario: Menu key setup is idempotent and keeps other entries
- **WHEN** the setup step runs twice against a defaults plist whose `NSUserKeyEquivalents` already holds `"Hide alacritty" = "@\Uf70f"` and `"Minimize" = "@m"`
- **THEN** `NSUserKeyEquivalents` is `"Quit alacritty" = "@~^q"`, `"Hide alacritty" = "@~^h"` and `"Minimize" = "@m"`, and the second run exits 0

### Requirement: Real key presses in the sandbox VM deliver shortcuts
The e2e layer SHALL deliver physical key presses to Neovim as the shortcut table says, in a dedicated Alacritty instance with the repo config and app-menu setup, running real zellij with the stack layer's layout. Events SHALL be posted only inside the sandbox macOS VM. Cmd+Shift+Q is system-owned and SHALL never be pressed.

#### Scenario: Every passed shortcut reaches its Neovim key from a real key press
- **WHEN** a recorder mapping is set in Neovim normal mode for each row's *Neovim receives* key and each row's shortcut except Cmd+Shift+Q is pressed in the Alacritty window
- **THEN** the recorder for exactly that key fires

#### Scenario: Consumed shortcuts never reach Neovim from a real key press
- **WHEN** a recorder mapping is set for the keys they encode and Cmd+J, Cmd+K, Cmd+[ and Cmd+] are pressed
- **THEN** no recorder fires and the Neovim pane stays focused

#### Scenario: Ctrl+Return reaches Neovim as <C-CR> from a real key press
- **WHEN** recorders are set for `<C-CR>` and `<CR>` and Ctrl+Return is pressed
- **THEN** only the `<C-CR>` recorder fires

#### Scenario: Cmd+Q reaches Neovim as <M-q> from a real key press
- **WHEN** a recorder is set for `<M-q>` and Cmd+Q is pressed
- **THEN** exactly `<M-q>` is recorded and the Alacritty process is still running with its window visible

#### Scenario: Cmd+H moves to the left Neovim split from a real key press
- **WHEN** two Neovim windows exist side by side, the cursor is in the right one, and Cmd+H is pressed
- **THEN** the current Neovim window is the left one, zellij focus stays on the Neovim pane and the Alacritty window is visible

#### Scenario: Cmd+H in a non-Neovim pane moves zellij focus left from a real key press
- **WHEN** the `cat` pane is focused and Cmd+H is pressed
- **THEN** zellij focus moves to the Neovim pane on the left

#### Scenario: Cmd+H never reaches Neovim from a real key press
- **WHEN** the app-menu setup is deliberately absent, two Neovim windows exist side by side, the cursor is in the right one, a recorder is set for `<C-H>`, and Cmd+H is pressed in a fresh Alacritty window
- **THEN** no recorder fires and the current Neovim window is still the right one

#### Scenario: Cmd+Shift+- and Cmd+Shift+= reach Neovim as <S-D--> and <S-D-=> from a real key press
- **WHEN** recorders are set for `<S-D-->`, `<S-D-=>`, `<M-_>` and `<M-+>` and Cmd+Shift+- then Cmd+Shift+= are pressed
- **THEN** exactly `<S-D-->` then `<S-D-=>` are recorded

#### Scenario: Cmd+Shift+- and Cmd+Shift+= close and open all folds from a real key press
- **WHEN** a buffer with at least two top-level folds is open with all folds open, Cmd+Shift+- is pressed, then Cmd+Shift+= is pressed
- **THEN** after Cmd+Shift+- every top-level fold is closed (`foldclosed()` of each fold's first line is not -1), and after Cmd+Shift+= none is

#### Scenario: Ctrl+Up grows the current Neovim split from a real key press
- **WHEN** two Neovim windows exist stacked, the cursor is in the top one, and Ctrl+Up is pressed
- **THEN** the current window is 2 rows taller

#### Scenario: Cmd+L at the rightmost Neovim split moves zellij focus right from a real key press
- **WHEN** Neovim has one window and Cmd+L is pressed
- **THEN** zellij focus moves to the `cat` pane on the right

#### Scenario: Ctrl+H in a non-Neovim pane moves zellij focus left from a real key press
- **WHEN** the `cat` pane is focused and Ctrl+H is pressed
- **THEN** zellij focus moves to the Neovim pane on the left

#### Scenario: Ctrl+Q quits zellij and closes the Alacritty window
- **WHEN** Ctrl+Q is pressed
- **THEN** the zellij session ends and the Alacritty process exits

#### Scenario: Cmd+Option+Control+Q quits Alacritty from a real key press
- **WHEN** Cmd+Option+Control+Q is pressed in a freshly started Alacritty window
- **THEN** the Alacritty process exits

#### Scenario: Cmd+Q quits Alacritty from a real key press
- **WHEN** the app-menu setup is deliberately absent and Cmd+Q is pressed in a freshly started Alacritty window
- **THEN** the Alacritty process exits

#### Scenario: Controlled no-setup regressions do not mutate when e2e cannot run
- **WHEN** the e2e preflight skips or fails before a controlled no-setup regression
- **THEN** no defaults command runs and no Alacritty instance starts

#### Scenario: Controlled no-setup regressions restore menu keys after lifecycle failures
- **WHEN** the fresh Alacritty instance fails to start or stop during a controlled no-setup regression
- **THEN** the versioned menu-key setup still runs before the failure is reported

#### Scenario: Cmd+Shift+Q is never pressed: the key helper refuses it
- **WHEN** `keys press <pid> cmd+shift+q` runs
- **THEN** it exits with status 2 and prints `keys press: refused, cmd+shift+q is a denied system-wide chord` without posting an event

### Requirement: The sandbox VM restores repo-controlled guest state before each e2e run
Before the e2e layer starts, `tests/sandbox/sandbox.sh e2e` SHALL restore the guest state the repo controls (the `org.alacritty` defaults domain and the terminal setup the checked-out branch applies) to exactly what the checked-out branch defines, so an e2e result never depends on which branch ran in the VM before.

#### Scenario: Guest restore drops Alacritty defaults the branch does not define
- **WHEN** the guest restore step runs against an `org.alacritty` domain (a temp plist) that holds `NSUserKeyEquivalents` `"Quit alacritty" = "@~^q"` and `"Hide alacritty" = "@~^h"`, in a checkout whose `terminal/` defines no menu key setup
- **THEN** reading `NSUserKeyEquivalents` from that domain fails (the key does not exist)

#### Scenario: Guest restore applies the branch's own terminal setup
- **WHEN** the guest restore step runs against an empty `org.alacritty` domain (a temp plist) in a checkout whose `terminal/` defines a setup script writing a key to that domain
- **THEN** the domain holds exactly the key that script writes and nothing an earlier run left there

#### Scenario: sandbox.sh e2e restores guest state after syncing and before the e2e layer
- **WHEN** `tests/sandbox/sandbox.sh e2e` runs with `lume`, `ssh` and `rsync` stubbed (VM running, provisioned, GUI session up)
- **THEN** the logged guest commands contain the repo sync, then the guest restore step, then `make -s e2e-local`, in that order

### Requirement: Concurrent sandbox runs never share the guest
Every `tests/sandbox/sandbox.sh` command that changes the guest (`up`, `provision`, `down`, `e2e`, `ssh`) SHALL hold one host-side lock (`$SANDBOX_STATE/lock`, an `mkdir` lock that records its owner) for its whole run, so an e2e run's sync, guest restore and `make e2e-local` all see only its own checkout. A run that finds the lock held waits and says so. A lock whose owner process no longer exists is reclaimed.

#### Scenario: The sandbox lock is taken when free and released by its owner
- **WHEN** `sandbox_lock <dir>` from `tests/sandbox/lock.sh` runs in a bash process with no lock at `<dir>`, and that process then exits
- **THEN** while it runs, `<dir>` exists and its `owner` file names that process's pid; after it exits, `<dir>` no longer exists

#### Scenario: A second sandbox lock waits for the first and says so
- **WHEN** one bash process holds `sandbox_lock <dir>` and a second process calls `sandbox_lock <dir>`, and the first process exits 2 s later
- **THEN** the second process prints `sandbox: waiting for` and the first's pid on stderr, does not return from `sandbox_lock` before the first exits, and then holds `<dir>` with its own pid as owner

#### Scenario: A sandbox lock left by a dead process is reclaimed
- **WHEN** `<dir>` exists with an `owner` file naming a pid that no longer runs, and `sandbox_lock <dir>` is called
- **THEN** it returns within 2 s, prints `sandbox: reclaiming stale lock` on stderr, and `<dir>/owner` names the caller's pid

#### Scenario: A sandbox lock wait gives up after SANDBOX_LOCK_TIMEOUT
- **WHEN** a live process holds `<dir>` and another calls `sandbox_lock <dir>` with `SANDBOX_LOCK_TIMEOUT=1`
- **THEN** the caller exits non-zero within 5 s, with the holder's pid in its stderr, and `<dir>/owner` still names the holder

#### Scenario: sandbox.sh down never stops the VM while another checkout holds the sandbox lock
- **WHEN** one process holds `$SANDBOX_STATE/lock` for 2 s and `tests/sandbox/sandbox.sh down` runs with `lume`, `pgrep` and `pkill` stubbed (VM running)
- **THEN** it prints `sandbox: waiting for sandbox lock held by pid <holder>` on stderr, its only `lume stop` comes after the holder left, and the lock is released when it exits

#### Scenario: sandbox.sh e2e talks to the guest only through Lume
- **WHEN** `tests/sandbox/sandbox.sh e2e` runs with `lume`, `ssh` and `rsync` stubbed (VM running, provisioned, GUI session up)
- **THEN** it never runs `ssh` on the host, and no `lume ssh` command line carries a guest command (each runs a script file from the shared folder)

#### Scenario: sandbox.sh e2e holds the sandbox lock from the sync to the end of the e2e layer
- **WHEN** `tests/sandbox/sandbox.sh e2e` runs with `lume`, `ssh` and `rsync` stubbed (VM running, provisioned, GUI session up), and the stubs log whether `$SANDBOX_STATE/lock` exists at each call
- **THEN** the lock exists at the repo sync and at `make -s e2e-local`, and after `sandbox.sh` exits it no longer exists

#### Scenario: sandbox.sh e2e waits while another checkout holds the sandbox lock
- **WHEN** a live process holds `$SANDBOX_STATE/lock` and `tests/sandbox/sandbox.sh e2e` starts with the same stubs, and the holder exits 2 s later
- **THEN** no `rsync` is logged while the holder lives, stderr says `sandbox: waiting for`, and after the holder exits the run syncs, restores and runs `make -s e2e-local`, then exits 0

### Requirement: Concurrent make check runs on one host run one at a time
`tests/check.sh` (`make check`) SHALL hold one host-wide check lock (`$CHECK_LOCK_DIR`, default `~/.cache/nvim-check-lock`, the `tests/sandbox/lock.sh` mkdir lock) for its whole run, so checks of different checkouts never skew each other's timing layers. A check that finds it held waits and says so. A check started inside a check uses its holder's lock. `CHECK_LOCK=0` runs unlocked. The sandbox lock is taken only inside it.

#### Scenario: make check holds the check lock for its whole run
- **WHEN** `tests/check.sh a b +c` runs with `make` stubbed to log whether `$CHECK_LOCK_DIR` exists at each target
- **THEN** it exists at every target, and after `check.sh` exits it no longer exists

#### Scenario: A second make check waits for the check lock and says so
- **WHEN** one `tests/check.sh` holds the check lock while its stubbed target runs for 2 s, and a second `tests/check.sh a` starts with the same `$CHECK_LOCK_DIR`
- **THEN** the second prints `check: waiting for the check lock held by pid <holder> (` on stderr, starts `a` only after the holder's target ended, and exits 0

#### Scenario: A make check run inside a make check does not wait for its own lock
- **WHEN** a stubbed target of a running `tests/check.sh` runs `tests/check.sh inner` with `CHECK_LOCK_TIMEOUT=1`
- **THEN** the inner check runs `inner` with the lock still held, never prints `waiting for`, and both exit 0

#### Scenario: CHECK_LOCK=0 runs make check without the check lock
- **WHEN** a live process holds `$CHECK_LOCK_DIR` and `tests/check.sh a` runs with `CHECK_LOCK=0`
- **THEN** it runs `a` and exits 0 while the holder still runs, without printing `waiting for`, and the lock still names the holder

### Requirement: The sandbox recovers a VM Lume lost track of
`tests/sandbox/sandbox.sh` SHALL start the VM as a long-lived `lume run` (no `--detach`) and treat it as running only when `lume get` says so. When its `lume run` process lives but Lume reports it not running for over `SANDBOX_MISMATCH_S` s (default 20, load-scaled), it SHALL kill that process, boot once more, and then give up with an error naming the mismatch.

#### Scenario: sandbox.sh never pulls an image when lume get blips
- **WHEN** `sandbox.sh e2e` runs with Lume stubbed so `lume get` fails twice while `lume ls` lists the VM
- **THEN** it exits 0 and never runs `lume pull`

#### Scenario: sandbox.sh restarts a VM Lume reports stopped while its lume run lives
- **WHEN** `tests/sandbox/sandbox.sh e2e` runs with stubs where Lume reports the VM stopped while its `lume run` process is alive, and a new `lume run` boots normally
- **THEN** it kills that process (`pkill -TERM`) before its only `lume run`, which has no `--detach`, and runs the e2e layer

#### Scenario: sandbox.sh never restarts a booting VM while Lume answers nothing
- **WHEN** `tests/sandbox/sandbox.sh e2e` runs with a live `lume run` process, the guest's SSH port closed for its first checks and `lume get` failing for its first 24 calls (a busy Lume)
- **THEN** it exits 0 with no `killing it and booting once more`, no `pkill` and no second `lume run`, and runs the e2e layer

#### Scenario: sandbox.sh gives up when Lume loses track of the VM again after one restart
- **WHEN** `tests/sandbox/sandbox.sh e2e` runs with the VM stopped and stubs where every `lume run` stays alive while Lume reports the VM stopped
- **THEN** it runs `lume run`, kills it, runs `lume run` once more, then exits non-zero with `after one restart; giving up` and no e2e layer

### Requirement: The sandbox calls lume ssh only once the guest's SSH port is open
After booting the VM, `tests/sandbox/sandbox.sh` SHALL poll the guest's port 22 with `nc -z` (no ssh) until it accepts TCP, within the boot deadline, before any `lume ssh` (boot wait, shared-folder probe), because Lume falls back to the host's `/usr/bin/ssh` when its own SSH fails.

#### Scenario: sandbox.sh calls lume ssh after a boot only once the guest's SSH port is open
- **WHEN** `tests/sandbox/sandbox.sh e2e` runs with the VM stopped and stubs where `nc` reports the port closed twice, then open
- **THEN** `lume run` comes first, the two closed `nc -z -G 2 <ip> 22` checks precede the first open one, no `lume ssh` comes before that open check, and the e2e layer runs

### Requirement: Test harness deadlines scale with host load
The stack harness deadlines (`M.wait_for` default, zellij CLI retry) and the smoke startup budget SHALL be multiplied by the host load factor `max(1, 1-min load average / CPU count)` from `tests/helpers.lua`. An idle host (load ≤ CPU count) keeps the unscaled values exactly.

#### Scenario: The load factor is 1 on an idle host
- **WHEN** `H.load_factor()` is called in a child with `vim.uv.loadavg` returning `7, 7, 7` and `vim.uv.available_parallelism` returning `14`
- **THEN** it returns `1`

#### Scenario: The load factor is the load per CPU on a busy host
- **WHEN** `H.load_factor()` is called with `vim.uv.loadavg` returning `70, 60, 50` and `vim.uv.available_parallelism` returning `14`
- **THEN** it returns `5`

#### Scenario: The stack harness wait stretches with host load
- **WHEN** `M.wait_for` from `tests.shortcuts.stack` polls a predicate that turns true 600 ms after the call, with timeout 300 ms and `vim.uv.loadavg` returning a load of 3 times `available_parallelism()`
- **THEN** it returns without error

#### Scenario: The stack harness wait keeps its timeout on an idle host
- **WHEN** `M.wait_for` polls a predicate that turns true 600 ms after the call, with timeout 300 ms and `vim.uv.loadavg` returning `0, 0, 0`
- **THEN** it raises an error containing `stack: timed out waiting for`

#### Scenario: The smoke startup budget scales with host load only when busy
- **WHEN** `startup_budget(400)` from `tests/smoke/budget.lua` is called with a load factor of 1, then of 3
- **THEN** it returns `400`, then `1200`

### Requirement: Cmd chords reach Neovim as <D-…>
Cmd+O, Cmd+I, Cmd+D and Cmd+A SHALL have no Alacritty binding and no zellij `normal`-mode binding, so Alacritty sends its kitty flag-1 encoding with the Super bit (`\e[<codepoint>;9u`), zellij passes it to the Neovim pane, and Neovim receives `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>`. The shortcut table lists them as `kitty` rows.

#### Scenario: Cmd chords reach Neovim through real zellij
- **WHEN** recorders are set in Neovim normal mode for `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>`, `<M-o>`, `<M-i>`, `<M-d>`, `<M-a>`, `o`, `i`, `d`, `a` and the bytes `\e[111;9u`, `\e[105;9u`, `\e[100;9u`, `\e[97;9u` are sent in that order
- **THEN** exactly `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>` are recorded, in that order

#### Scenario: Cmd+O, Cmd+I, Cmd+D and Cmd+A reach Neovim as <D-…> from a real key press
- **WHEN** recorders are set in Neovim normal mode for `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>`, `<M-o>`, `<M-i>`, `<M-d>`, `<M-a>`, `o`, `i`, `d`, `a` and Cmd+O, Cmd+I, Cmd+D, Cmd+A are pressed in that order in the Alacritty window
- **THEN** exactly `<D-o>`, `<D-i>`, `<D-d>`, `<D-a>` are recorded, in that order, and the Alacritty process is still running

### Requirement: Find Action shortcut delivery
Cmd+Shift+A SHALL open Find Action through a real zellij stack and from a real macOS key press in the sandbox VM.

#### Scenario: Cmd+Shift+A opens Find Action through real zellij
- **WHEN** Cmd+Shift+A bytes are sent through the real zellij stack to Neovim
- **THEN** the Find Action palette opens

#### Scenario: Cmd+Shift+A opens Find Action from a real key press
- **WHEN** Cmd+Shift+A is posted to the sandbox Alacritty process as a real macOS key press
- **THEN** the Find Action palette opens in Neovim

### Requirement: Shortcut table action identities
For each Neovim mapping row, the shortcut table's *Mapping* column SHALL name the registered action id, or `none`; `settings/keymap.json` SHALL assign the row's *Neovim receives* lhs to that id. Terminal bytes, zellij routing, received keys, and physical shortcut meanings SHALL remain unchanged.

#### Scenario: Shortcut table names action ids
- **WHEN** every shortcut-table row with a Neovim received key is inspected
- **THEN** its *Mapping* value is `none` or a registered action id whose configured lhs is the row's *Neovim receives* value

#### Scenario: Shortcut meanings survive registry migration
- **WHEN** each passed shortcut is sent through the real zellij stack to a full Neovim config after `VeryLazy`
- **THEN** invoking the received key produces the behavior of the action id in that row

## Shortcut table
Columns of the table the "Shortcut table" requirement refers to:
- *Source* `chars`: an Alacritty `chars` binding sends the bytes verbatim. `kitty`: no binding; Alacritty's own encoding while zellij has pushed kitty keyboard flag 1 (zellij always does at startup).
- *zellij*: `pass` (unbound, bytes written to the pane), `navigator <name> <payload>` (vim-zellij-navigator writes its own bytes to the Neovim pane), or the zellij action that consumes the key.
- *Neovim receives*: the key the Neovim pane decodes, `—` when nothing arrives.
- *Mapping*: the registered action id assigned to that global normal-mode key, `none` (no mapping), or `—`.
- Cmd+Shift+Q is the system Log Out shortcut, so it is unreachable from a key press unless Log Out is remapped in System Settings > Keyboard > Shortcuts; its row and binding stay for that case.

| Shortcut | Source | Alacritty sends | zellij | Neovim receives | Mapping |
|---|---|---|---|---|---|
| Cmd+E | chars | `\ee` | pass | `<M-e>` | file_tree.toggle |
| Cmd+G | chars | `\eg` | pass | `<M-g>` | changes.review |
| Cmd+B | chars | `\eb` | pass | `<M-b>` | none |
| Cmd+Q | chars | `\eq` | pass | `<M-q>` | none |
| Cmd+Shift+Q | chars | `\eQ` | pass | `<M-Q>` | none |
| Cmd+R | chars | `\er` | pass | `<M-r>` | lsp.rename |
| Cmd+C | chars | `\ec` | pass | `<M-c>` | none |
| Cmd+/ | chars | `\e/` | pass | `<M-/>` | comments.toggle |
| Cmd+F | chars | `\ef` | ToggleFloatingPanes | — | — |
| Cmd+Shift+F | chars | `\eF` | pass | `<M-F>` | search.live_grep |
| Cmd+Shift+A | chars | `\eA` | pass | `<M-A>` | find_action.open |
| Cmd+W | chars | `\ew` | pass | `<M-w>` | diag.next |
| Cmd+Shift+W | chars | `\eW` | pass | `<M-W>` | none |
| Cmd+H | chars | `\x08` | navigator move_focus_or_tab left | `<C-H>` | window.move_left |
| Cmd+Shift+H | chars | `\eH` | navigator resize left | `<M-h>` | none |
| Cmd+J | chars | `\ej` | MoveFocus down | — | — |
| Cmd+Shift+J | chars | `\eJ` | navigator resize down | `<M-j>` | window.move_down |
| Cmd+K | chars | `\ek` | MoveFocus up | — | — |
| Cmd+Shift+K | chars | `\eK` | navigator resize up | `<M-k>` | window.move_up |
| Cmd+L | chars | `\x0c` | navigator move_focus_or_tab right | `<C-L>` | window.move_right |
| Cmd+Shift+L | chars | `\eL` | navigator resize right | `<M-l>` | none |
| Cmd+- | chars | `\e-` | pass | `<M-->` | fold.close_one |
| Cmd+= | chars | `\e=` | pass | `<M-=>` | fold.open_one |
| Cmd+Shift+- | kitty | `\e[45;10u` | pass | `<S-D-->` | fold.close_all |
| Cmd+Shift+= | kitty | `\e[61;10u` | pass | `<S-D-=>` | fold.open_all |
| Cmd+[ | chars | `\e[` | GoToPreviousTab | — | — |
| Cmd+] | chars | `\e]` | GoToNextTab | — | — |
| Cmd+9 | chars | `\e9` | pass | `<M-9>` | none |
| Shift+Return | chars | `\e[13;2u` | pass | `<S-CR>` | ai.vibe |
| Option+Return | chars | `\e}` | pass | `<M-}>` | none |
| Option+Shift+Return | chars | `\e{` | pass | `<M-{>` | none |
| Option+Q | chars | `\eq` | pass | `<M-q>` | none |
| Option+F | chars | `\e%` | pass | `<M-%>` | none |
| Option+H | chars | `\e!` | pass | `<M-!>` | none |
| Option+J | chars | `\e#` | pass | `<M-#>` | none |
| Option+K | chars | `\e$` | pass | `<M-$>` | none |
| Option+L | chars | `\e@` | pass | `<M-@>` | none |
| Option+Shift+H | chars | `\e^` | pass | `<M-^>` | none |
| Option+Shift+J | chars | `\e*` | pass | `<M-*>` | none |
| Option+Shift+K | chars | `\e(` | pass | `<M-(>` | none |
| Option+Shift+L | chars | `\e&` | pass | `<M-&>` | none |
| Ctrl+Option+H | chars | `\eΩ` | pass | `<M-Ω>` | none |
| Ctrl+Option+J | chars | `\eç` | pass | `<M-ç>` | none |
| Ctrl+Option+K | chars | `\e∫` | pass | `<M-∫>` | none |
| Ctrl+Option+L | chars | `\e≈` | pass | `<M-≈>` | none |
| Ctrl+H | kitty | `\e[104;5u` | navigator move_focus_or_tab left | `<C-H>` | window.move_left |
| Ctrl+L | kitty | `\e[108;5u` | navigator move_focus_or_tab right | `<C-L>` | window.move_right |
| Ctrl+Q | kitty | `\e[113;5u` | Quit | — | — |
| Ctrl+Return | kitty | `\e[13;5u` | pass | `<C-CR>` | lsp.code_action |
| Ctrl+Up | kitty | `\e[1;5A` | pass | `<C-Up>` | window.increase_height |
| Ctrl+Down | kitty | `\e[1;5B` | pass | `<C-Down>` | window.decrease_height |
| Ctrl+Left | kitty | `\e[1;5D` | pass | `<C-Left>` | window.decrease_width |
| Ctrl+Right | kitty | `\e[1;5C` | pass | `<C-Right>` | window.increase_width |
| Cmd+O | kitty | `\e[111;9u` | pass | `<D-o>` | none |
| Cmd+I | kitty | `\e[105;9u` | pass | `<D-i>` | none |
| Cmd+D | kitty | `\e[100;9u` | pass | `<D-d>` | none |
| Cmd+A | kitty | `\e[97;9u` | pass | `<D-a>` | none |

Known gaps this table pins down: Cmd+J/Cmd+K never reach Neovim (the later `shared_except "locked" "scroll"` block rebinds `Alt j`/`Alt k` to zellij `MoveFocus`); Cmd+Shift+H/J/K/L reach Neovim as lowercase `<M-h/j/k/l>` (the navigator's resize writes `ESC <dir>`), so the `<A-H/J/K/L>` resize maps are unreachable and Cmd+Shift+J/K move the cursor between splits; Ctrl+Q quits zellij.

## Collision table
| zellij key | zellij action | Shadowed Neovim key | Neovim modes |
|---|---|---|---|
| alt j | MoveFocus down | `<M-j>` | n x |
| alt k | MoveFocus up | `<M-k>` | n x |
| alt shift h | navigator resize left | `<M-H>` | n |
| alt shift j | navigator resize down | `<M-J>` | n |
| alt shift k | navigator resize up | `<M-K>` | n |
| alt shift l | navigator resize right | `<M-L>` | n |
| ctrl q | Quit | `<C-Q>` | n |
| ctrl s | SwitchToMode scroll | `<C-S>` | i s |
