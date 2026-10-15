# Test pyramid for this Neovim config. See docs/testing.md.
#   make check   - every layer below, concurrently (tests/check.sh); E2E=1 for the merge gate
#   make quick   - only what the changes vs $(BASE) touch (tests/quick.sh); the inner loop
#   make probe   - run a Lua snippet in a full-config test child (tests/probe.lua)

# not NVIM: Neovim exports $NVIM (its server address) to :terminal jobs
NVIM_BIN ?= nvim
LUA_DIRS := lua/ init.lua tests/
VIMRUNTIME ?= $(shell $(NVIM_BIN) --clean --headless --cmd 'echo $$VIMRUNTIME | q' 2>&1)
export VIMRUNTIME

MINITEST = $(NVIM_BIN) --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.runner').run('$(1)')"
NVIM_LUA = $(NVIM_BIN) -u tests/minimal_init.lua -l
# sharded over JOBS (default cores - 2) workers, one merged report
PARALLEL = $(NVIM_LUA) tests/parallel.lua $(1)
BASE ?= auto
export BASE
# e2e (runs in the sandbox VM): unset = only if the VM is running, 1 = boot the VM if needed, 0 = skip
export E2E
# plugin-update runs the tests on its private plugin copy (.archon/scripts/plugin_update.py)
ifneq ($(wildcard .tests/xdg/data/nvim/lazy),)
export NVIM_TEST_DATA_DIR ?= $(CURDIR)/.tests/xdg/data/nvim
endif

.PHONY: check quick install deps fmt lint types test test-unit test-integration test-screen test-readiness \
	screenshots smoke smoke-health smoke-startup trace probe specs render colorize clean

# timing-sensitive layers run alone after the rest, so other layers do not skew them
check:
	@SANDBOX_START=$${E2E:-0} tests/check.sh lint types test trace specs chain stack e2e smoke-health loop-test +smoke-startup +test-readiness

quick:
	@tests/quick.sh

install:
	brew install stylua selene lua-language-server

deps:
	@tests/bootstrap.sh

fmt:
	stylua $(LUA_DIRS)

# --- static -------------------------------------------------------------------
lint:
	stylua --check $(LUA_DIRS)
	selene $(LUA_DIRS)

types: deps
	@tests/types.sh

# --- mini.test layers (FILE=path, CAPS=cap[,cap], CASE=substring narrow the run) ---
test: deps
	@$(call PARALLEL,)

test-unit: deps
	@$(call PARALLEL,unit)

test-integration: deps
	@$(call PARALLEL,integration)

test-screen: deps
	@$(call PARALLEL,screen)

test-readiness: deps
	@FILE=tests/integration/lsp/test_readiness.lua $(call MINITEST,integration)

screenshots: deps
	@UPDATE_SCREENSHOTS=1 $(call MINITEST,screen)

# --- smoke, traceability, dev helpers --------------------------------------------
smoke: deps
	@$(NVIM_LUA) tests/smoke/run.lua

smoke-health: deps
	@$(NVIM_LUA) tests/smoke/run.lua health

smoke-startup: deps
	@$(NVIM_LUA) tests/smoke/run.lua startup

trace: deps
	@$(NVIM_LUA) tests/trace.lua $(if $(VERBOSE),,--quiet)

# make probe SCRIPT=<file.lua> | PROBE='lua code' [PROBE_TIMEOUT=ms]: run Lua in a full-config test child
probe: export SCRIPT := $(SCRIPT)
probe: export PROBE := $(PROBE)
probe: deps
	@$(NVIM_LUA) tests/probe.lua

# main specs pass strict validation (what a trial archive needs)
specs:
	@openspec validate --specs --strict --no-interactive

# colored capture in a private tmux (MONO=1: plain mini.test screenshot)
render: deps
	@$(NVIM_BIN) --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.render').run()"

# design-doc renders with mask + legend in the real colorscheme's colors
colorize: deps
	@$(NVIM_BIN) --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.render.colorize').run()"

# --- shortcut layers: Alacritty -> zellij -> Neovim (docs/testing.md) ----------
# (CAPS narrows only the mini.test layers above)
.PHONY: deps-shortcuts chain stack e2e e2e-local sandbox-up sandbox-down sandbox-status sandbox-provision menu-keys

deps-shortcuts:
	@tests/shortcuts/bootstrap.sh

chain: deps deps-shortcuts
	@CAPS= $(call MINITEST,chain)
	@$(NVIM_LUA) tests/shortcuts/report.lua

stack: deps deps-shortcuts
	@CAPS= $(call MINITEST,stack)

# real Alacritty + zellij + Neovim, real key events, inside the sandbox VM only (tests/sandbox/sandbox.sh):
# on the host it boots the VM if needed (SANDBOX_START=0: skip when it is down), syncs and runs e2e-local there
# a sandbox that fails before any test starts (no e2e.started marker) is stopped and the run tried once more
E2E_STARTED = $${SANDBOX_STATE:-$$HOME/.cache/nvim-e2e-sandbox}/e2e.started
e2e:
	@rm -f "$(E2E_STARTED)"; tests/sandbox/sandbox.sh e2e || { test -f "$(E2E_STARTED)" && exit 1; \
		echo "sandbox: e2e setup failed before any test ran; stopping the VM and trying once more" >&2; \
		tests/sandbox/sandbox.sh down >/dev/null 2>&1; tests/sandbox/sandbox.sh e2e; }

e2e-local: deps deps-shortcuts
	@CAPS= E2E=$${E2E:-1} $(call MINITEST,e2e)

sandbox-up:
	@tests/sandbox/sandbox.sh up

sandbox-down:
	@tests/sandbox/sandbox.sh down

sandbox-status:
	@tests/sandbox/sandbox.sh status

sandbox-provision:
	@tests/sandbox/sandbox.sh provision

# host: move Alacritty's app-menu Quit/Hide off Cmd+Q/Cmd+H (org.alacritty defaults), then relaunch Alacritty
menu-keys:
	@terminal/macos_menu_keys.sh

clean:
	rm -rf .tests

# --- local AI loop (docs/workflow.md): thin wrappers around Archon workflows in .archon/workflows/ ---
ARCHON ?= archon
STAMP := $(shell date +%Y%m%d-%H%M%S)
# After a run, drop worktrees whose branch is merged into auto (a run cannot delete its own).
# Archon judges "merged" against local/auto without fetching it, so refresh it with the run's merge first.
CLEANUP = { git fetch -q local; $(ARCHON) isolation cleanup --merged; } >/dev/null 2>&1 || true
# make queue then keeps one loop branch per change: loop_clean.py --change drops the superseded reruns.

.PHONY: loop-setup loop-register loop-validate self-check loop-test loop-clean fix feature queue drain update outdated console loop-report loop-status preview

loop-setup: # self-remote: Archon cuts worktrees from <remote>/auto, and auto stays local
	@git remote get-url local >/dev/null 2>&1 || git remote add local "$$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$$||')"
	@git fetch -q local
	@python3 .archon/scripts/skills_check.py --install-plugins .archon/workflows/*/*.yaml
	@$(MAKE) -s loop-register
	@$(ARCHON) doctor | grep -E '✓|✗' || true

# Archon registers the repo once (DB row + workspaces/<owner>/<repo>/source link). A registration
# made from a since-deleted worktree breaks every run, so point both back at this checkout.
ARCHON_SOURCE = $(HOME)/.archon/workspaces/GlebBeloded/nvim.config/source
loop-register:
	@[ ! -L "$(ARCHON_SOURCE)" ] || [ "$$(readlink "$(ARCHON_SOURCE)")" = "$(CURDIR)" ] || { \
		ln -sfn "$(CURDIR)" "$(ARCHON_SOURCE)"; \
		sqlite3 "$(HOME)/.archon/archon.db" "update remote_agent_codebases set default_cwd='$(CURDIR)' where name='GlebBeloded/nvim.config'"; \
		echo "loop-register: Archon registration repointed to $(CURDIR)"; }

loop-validate:
	@$(ARCHON) validate workflows

# make self-check CHANGE=<id>: the gate's cheap checks, for implement/fix before they hand back (no tests, no e2e):
# the hard rules gate.py checks first (integrity.py, pinned.py --check), lint, types, strict validate of the
# change, then of the main specs after a trial archive (gate.py)
self-check:
	@test -n "$(CHANGE)" || { echo 'usage: make self-check CHANGE=<change id>' >&2; exit 2; }
	@python3 .archon/scripts/integrity.py
	@python3 .archon/scripts/pinned.py --check "$(CHANGE)"
	@$(MAKE) -s lint types
	@openspec validate "$(CHANGE)" --strict --no-interactive
	@python3 .archon/scripts/spec_trial.py "$(CHANGE)"

# dry-run fixtures (.archon/workflows/<workflow>/fixtures/*.stubs.yaml): no AI, no run, ~13 s;
# exec-code fixtures see the fixture-owned changes, never the live queue
loop-test: deps # test_stall.py runs the mini.test runner
	@.archon/scripts/loop_changed_test.sh
	@python3 -m unittest discover -q -s .archon/scripts -p 'test_*.py'
	@LOG_LEVEL=error LOOP_CHANGES_DIR=.archon/workflows/work-queue/fixtures/changes $(ARCHON) workflow test

fix: loop-setup # make fix BUG="what is wrong"  (or BUG=<openspec change id>)
	@test -n "$$BUG" || { echo 'usage: make fix BUG="..."'; exit 2; }
	@if [ -d "openspec/changes/$$BUG" ]; then exec $(MAKE) -s queue CHANGE="$$BUG"; fi; \
	$(ARCHON) workflow run fix-bug --base auto --branch loop/fix-$(STAMP) "$$BUG"; status=$$?; $(CLEANUP); exit $$status

feature: loop-setup # make feature IDEA="what to build"
	@test -n "$$IDEA" || { echo 'usage: make feature IDEA="..."'; exit 2; }
	$(ARCHON) workflow run new-feature --base auto --branch loop/feat-$(STAMP) "$$IDEA"; status=$$?; $(CLEANUP); exit $$status

queue: loop-setup # make queue [CHANGE=<id>]: work the next (or the given) change in openspec/changes/
	@id=$$(INPUTS_CHANGE="$$CHANGE" python3 .archon/scripts/queue_pick.py | python3 -c 'import json,sys; print(json.load(sys.stdin)["change"])'); \
	test -n "$$id" || { echo "Queue is empty: no untaken change in openspec/changes/"; exit 0; }; \
	echo "Working on $$id"; branch=loop/$$id; adopt=; \
	if git show-ref -q --verify "refs/heads/loop/$$id"; then branch=loop/$$id-$(STAMP); fi; \
	adopt=$$(python3 .archon/scripts/adopt_pick.py "$$id"); \
	[ -z "$$adopt" ] || echo "Adopting $$adopt"; \
	$(ARCHON) workflow run work-queue --base auto --branch $$branch --input change=$$id --input adopt=$$adopt "Work queued change $$id"; status=$$?; $(CLEANUP); \
	python3 .archon/scripts/loop_clean.py --change "$$id" --apply || true; exit $$status

drain: loop-setup # make drain [N=<max runs>]: work queued changes one by one until empty, N runs or a pause
	@python3 .archon/scripts/drain.py $(if $(N),--max $(N))

loop-clean: # remove worktree + branch of shipped/superseded loop/* runs; dry run unless APPLY=1
	@python3 .archon/scripts/loop_clean.py $(if $(filter 1,$(APPLY)),--apply)

update: loop-setup # make update PLUGIN=<name>: update one plugin, test it, ship or adapt the config
	@test -n "$$PLUGIN" || { echo 'usage: make update PLUGIN=<name>  (make outdated lists them)'; exit 2; }
	$(ARCHON) workflow run plugin-update --base auto --branch loop/update-$$PLUGIN-$(STAMP) --input plugin=$$PLUGIN "Update plugin $$PLUGIN"; status=$$?; $(CLEANUP); exit $$status

outdated: # plugins with commits past lazy-lock.json (read-only, on a private plugin copy)
	@INPUTS_MODE=outdated python3 .archon/scripts/plugin_update.py

console: # Archon web console (runs, gates, logs): http://localhost:3090
	$(ARCHON) serve

loop-report:
	@if [ -n "$(RUN)" ]; then python3 .archon/scripts/loop_report.py --run "$(RUN)"; \
	else python3 .archon/scripts/loop_report.py; fi

loop-status:
	@$(ARCHON) workflow status; $(ARCHON) workflow runs --limit 10
	@$(MAKE) -s loop-report

preview: # make preview CHANGE=<id> [OPEN=1]: prints the absolute path of openspec/changes/<id>/preview.html
	@test -d "openspec/changes/$(CHANGE)" || { echo "usage: make preview CHANGE=<change id>" >&2; exit 2; }
	@out=$$($(NVIM_BIN) --clean -l ops/preview/preview.lua "$(CURDIR)/openspec/changes/$(CHANGE)") && echo "$$out" && \
	if [ -n "$(OPEN)" ]; then open "$$out"; fi
