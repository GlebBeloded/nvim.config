# Test pyramid for this Neovim config. See docs/testing.md.
#   make check   - everything below, in pyramid order (the Claude Stop hook runs this)

NVIM ?= nvim
LUA_DIRS := lua/ init.lua tests/
VIMRUNTIME ?= $(shell $(NVIM) --clean --headless --cmd 'echo $$VIMRUNTIME | q' 2>&1)
export VIMRUNTIME

MINITEST = $(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.runner').run('$(1)')"
NVIM_LUA = $(NVIM) -u tests/minimal_init.lua -l

.PHONY: check install deps fmt lint types test test-unit test-integration test-screen \
	screenshots smoke trace render colorize clean

check: lint types test smoke trace chain stack

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

# --- mini.test layers (FILE=path, CASE=substring narrow the run) ----------------
test: deps
	@$(call MINITEST,)

test-unit: deps
	@$(call MINITEST,unit)

test-integration: deps
	@$(call MINITEST,integration)

test-screen: deps
	@$(call MINITEST,screen)

screenshots: deps
	@UPDATE_SCREENSHOTS=1 $(call MINITEST,screen)

# --- smoke, traceability, dev helpers --------------------------------------------
smoke: deps
	@$(NVIM_LUA) tests/smoke/run.lua

trace: deps
	@$(NVIM_LUA) tests/trace.lua $(if $(VERBOSE),,--quiet)

# colored capture in a private tmux (MONO=1: plain mini.test screenshot)
render: deps
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.render').run()"

# design-doc renders with mask + legend in the real colorscheme's colors
colorize: deps
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua require('tests.render.colorize').run()"

# --- shortcut layers: Alacritty -> zellij -> Neovim (docs/testing.md) ----------
.PHONY: deps-shortcuts chain stack e2e-gui

deps-shortcuts:
	@tests/shortcuts/bootstrap.sh

chain: deps deps-shortcuts
	@$(call MINITEST,chain)
	@$(NVIM_LUA) tests/shortcuts/report.lua

stack: deps deps-shortcuts
	@$(call MINITEST,stack)

e2e-gui: deps deps-shortcuts
	@$(call MINITEST,gui)

clean:
	rm -rf .tests

# --- local AI loop (docs/loop.md): thin wrappers around Archon workflows in .archon/workflows/ ---
ARCHON ?= archon
STAMP := $(shell date +%Y%m%d-%H%M%S)
LAUNCHD_LABEL := dev.gleb.nvim.weekly-upkeep
LAUNCHD_PLIST := $(HOME)/Library/LaunchAgents/$(LAUNCHD_LABEL).plist
# After a run, drop worktrees whose branch is merged into auto (a run cannot delete its own).
CLEANUP = $(ARCHON) isolation cleanup --merged >/dev/null 2>&1 || true

.PHONY: loop-setup loop-validate fix feature queue upkeep console loop-status preview schedule unschedule

loop-setup: # self-remote: Archon cuts worktrees from <remote>/auto, and auto stays local
	@git remote get-url local >/dev/null 2>&1 || git remote add local "$$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/.git$$||')"
	@git fetch -q local
	@$(ARCHON) doctor | grep -E '✓|✗' || true

loop-validate:
	@$(ARCHON) validate workflows

fix: loop-setup # make fix BUG="what is wrong"  (or BUG=<openspec change id>)
	@test -n "$$BUG" || { echo 'usage: make fix BUG="..."'; exit 2; }
	$(ARCHON) workflow run fix-bug --base auto --branch loop/fix-$(STAMP) "$$BUG"; status=$$?; $(CLEANUP); exit $$status

feature: loop-setup # make feature IDEA="what to build"
	@test -n "$$IDEA" || { echo 'usage: make feature IDEA="..."'; exit 2; }
	$(ARCHON) workflow run new-feature --base auto --branch loop/feat-$(STAMP) "$$IDEA"; status=$$?; $(CLEANUP); exit $$status

queue: loop-setup # make queue [CHANGE=<id>]: work the next (or the given) change in openspec/changes/
	@id=$$(INPUTS_CHANGE="$$CHANGE" python3 .archon/scripts/queue_pick.py | python3 -c 'import json,sys; print(json.load(sys.stdin)["change"])'); \
	test -n "$$id" || { echo "Queue is empty: no untaken change in openspec/changes/"; exit 0; }; \
	echo "Working on $$id"; \
	$(ARCHON) workflow run work-queue --base auto --branch loop/$$id --input change=$$id "Work queued change $$id"; status=$$?; $(CLEANUP); exit $$status

upkeep: loop-setup # make upkeep [DRY=1]: weekly plugin update (what launchd runs)
	$(ARCHON) workflow run weekly-upkeep $(if $(DRY),--dry-run --default-stubs,--base auto --branch loop/upkeep-$(STAMP)) "Weekly plugin upkeep"; status=$$?; $(CLEANUP); exit $$status

console: # Archon web console (runs, gates, logs): http://localhost:3090
	$(ARCHON) serve

loop-status:
	@$(ARCHON) workflow status; $(ARCHON) workflow runs --limit 10

preview: # make preview CHANGE=<id> [OPEN=1]: openspec/changes/<id>/preview.html
	@test -d "openspec/changes/$(CHANGE)" || { echo "usage: make preview CHANGE=<change id>" >&2; exit 2; }
	@out=$$($(NVIM) --clean -l ops/preview/preview.lua "openspec/changes/$(CHANGE)") && echo "$$out" && \
	if [ -n "$(OPEN)" ]; then open "$$out"; fi

schedule: # weekly-upkeep every Monday 09:00 via launchd (opt-in)
	@mkdir -p $(dir $(LAUNCHD_PLIST)) $(HOME)/Library/Logs
	@sed -e 's|@REPO@|$(CURDIR)|g' -e 's|@HOME@|$(HOME)|g' -e 's|@LABEL@|$(LAUNCHD_LABEL)|g' \
		ops/launchd/weekly-upkeep.plist.in > $(LAUNCHD_PLIST)
	@plutil -lint $(LAUNCHD_PLIST)
	launchctl bootstrap gui/$$(id -u) $(LAUNCHD_PLIST)
	@echo "Scheduled. Logs: ~/Library/Logs/nvim-weekly-upkeep.log. Run now: launchctl kickstart gui/$$(id -u)/$(LAUNCHD_LABEL)"

unschedule:
	-launchctl bootout gui/$$(id -u)/$(LAUNCHD_LABEL)
	rm -f $(LAUNCHD_PLIST)
