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

check: lint types test smoke trace

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

clean:
	rm -rf .tests
