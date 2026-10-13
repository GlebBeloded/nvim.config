All new cases go in `tests/unit/loop/test_skills.lua` (unit layer, bare child: `H.child_set(child, child.start_bare)`, processes via `H.system`). Reuse the patterns of `test_ship.lua` (`write_files`, `write_executable`) and `test_cleanup.lua` (`stub_env`: stubs first on `PATH`, temp `HOME`, cleared `MAKEFLAGS`; symlinked `Makefile`). Run one case with `make test FILE=tests/unit/loop/test_skills.lua CASE="…"`, then `make fmt` and `make quick` before each commit.

## 1. Preflight script

Scenarios: "Skill preflight fails on an unresolved plugin skill", "Skill preflight passes when every declared skill resolves".

- [x] 1.1 Failing tests first: write "loop: Skill preflight fails on an unresolved plugin skill" and "loop: Skill preflight passes when every declared skill resolves". Helpers: `make_skill_repo(skills)` writes a throwaway repo with `.archon/workflows/w.yaml` (one node declaring `skills`), and `write_claude_stub(bin, plugins)` writes a `claude` stub that prints `plugins` as JSON for `plugin list --json`. Fail case: the plugin has a non-empty `errors`; assert a non-zero exit and that stderr contains `superpowers:writing-plans`. Pass case: the plugin is `enabled`, has empty `errors`, and its `installPath` is a temp dir with `skills/writing-plans/SKILL.md`; the repo has `.claude/skills/openspec-propose/SKILL.md`; assert exit 0. Run `python3 .archon/scripts/skills_check.py .archon/workflows/w.yaml` with the repo as cwd. Run both cases and see them fail because the script is missing.
- [x] 1.2 Before writing the stub's JSON, capture the real shape of `claude plugin list --json` on the host (plugin id key, `enabled`, `installPath`, `errors`), so the stub and the script match Claude Code 2.1.296.
- [x] 1.3 Add `.archon/scripts/skills_check.py`: stdlib plus PyYAML (available to `python3`), with a module docstring like the other scripts. Small functions:
  - `declared_skills(workflow)` walks every node, recursing into `loop.nodes`.
  - `project_skill_ok(name)` checks `.claude/skills/<name>/SKILL.md`.
  - `loaded_plugins()` runs `claude plugin list --json` in cwd once and keeps entries that are enabled with no errors, keyed by plugin name (the id before `@`).
  - `plugin_skill_ok(name, plugins)` checks `<installPath>/skills/<skill>/SKILL.md`.
  - `main` takes one or more workflow paths, prints every unresolved name on stderr in a single message, and exits 1. It exits 0 when all resolve.

  Make both cases pass. Commit.

## 2. Wire the preflight into every workflow

Scenario: "Skill preflight runs before every skill-declaring node".

- [x] 2.1 Failing test first: write "loop: Skill preflight runs before every skill-declaring node". Parse each `.archon/workflows/*.yaml` with `python3 -c 'import json,sys,yaml; print(json.dumps(yaml.safe_load(sys.stdin)))'` via `H.system`, then `vim.json.decode`. Assert:
  - the workflow has a node with `bash` containing `.archon/scripts/skills_check.py`;
  - every node whose `skills:` holds a name with `:` reaches that node through the transitive `depends_on` closure. A node inside `loop.nodes` uses its parent loop node's `depends_on`.

  Collect the violations as `{ workflow, node }` and assert `eq(violations, {})`. Watch it fail for all five workflows.
- [x] 2.2 Add a `skills-check` node, `bash: python3 .archon/scripts/skills_check.py .archon/workflows/<this workflow>.yaml`, with no `depends_on`, to each workflow, and wire the dependencies:
  - `fix-bug`: `explore` depends on `skills-check`;
  - `new-feature`: `explore` depends on `skills-check`;
  - `nvim-deliver`: `plan` depends on `skills-check` (the `build` loop reaches it through `plan-gate`);
  - `work-queue`: `complete` depends on `[pick, skills-check]`;
  - `plugin-update`: `spec` depends on `[changelog, skills-check]`.

  Run `make loop-validate`. Make the case pass. Commit.

## 3. Commands load their skills first

Scenario: "Every declared skill is named and loaded by its command".

- [x] 3.1 Failing test first: write "loop: Every declared skill is named and loaded by its command". Reuse the YAML-to-JSON helper from 2.1. For every node with both `skills:` and `command:` (loop nodes included), read `.archon/commands/<command>.md` with `vim.fn.readfile` and assert:
  - each declared skill appears as `` `<skill>` ``;
  - the text contains the fixed load-first needles, kept in one `LOAD_FIRST_NEEDLES` list (for example `Skill tool`, `before any other step`, `stop`);
  - every `` `superpowers:<x>` `` in the command is in the node's `skills:`.

  Collect the violations per `{ command, problem }` and assert they are empty. Watch it fail.
- [x] 3.2 Give every command that a skill-declaring node uses the same opening step, placed right after the header and before any other instruction: "First, load each of these skills with the Skill tool, before any other step: `…`. If one does not load, stop and report the error naming it." That covers `plan`, `implement`, `review`, `explore-bug`, `explore-feature`, `queue-spec` and `spec-plugin-update`. The test also covers `spec-bug`, `spec-feature` and `verify`, because their nodes declare openspec skills. Keep each command's existing "use X for Y" guidance; only the loading becomes mandatory. Do not change which skills a node uses, only align names (out of scope otherwise). Make the case pass. Commit.

## 4. Install at user scope in loop-setup

Scenario: "Loop setup installs a missing enabled plugin".

- [x] 4.1 Failing test first: write "loop: Loop setup installs a missing enabled plugin". Build a throwaway git repo on `auto` with the checkout's `Makefile` symlinked (as in `test_cleanup.lua`) and `.claude/settings.json` enabling `superpowers@superpowers-marketplace`. Use a `claude` stub that appends its arguments to a log and answers `plugin list --json` with that plugin carrying a non-empty `errors`. Set `ARCHON` to a no-op stub and use a temp `HOME`. Run `make loop-setup` and assert the log contains `plugin install superpowers@superpowers-marketplace --scope user`. Watch it fail.
- [x] 4.2 Add an `install` mode to `skills_check.py` (`skills_check.py --install-plugins`) that reuses `loaded_plugins()`. It reads `enabledPlugins` from `.claude/settings.json` and, for each enabled id that is not loaded without errors, runs `claude plugin install <id> --scope user`. Call it from `loop-setup` before `loop-register`. Make the case pass. Commit.
- [x] 4.3 Host check (manual, once): run `make loop-setup`, then in a fresh worktree run `claude plugin list --json` and `python3 .archon/scripts/skills_check.py .archon/workflows/*.yaml`. Both must show superpowers loaded and the check must exit 0. Record the result in the commit message.

## 5. Docs

No scenario (docs only).

- [ ] 5.1 `docs/workflow.md`, Setup facts: replace the "superpowers plugin … is active" sentence. The new text says:
  - `make loop-setup` installs the plugins that `.claude/settings.json` enables at user scope, because project scope is recorded per path and every Archon worktree is a new path;
  - the `skills-check` node fails a run whose declared skills do not resolve;
  - every command loads its declared skills first;
  - Archon's "Claude skills not found on disk: superpowers:…" warning is expected for plugin skills.

  Do not restate the script's logic (rule 10).
- [ ] 5.2 `make check` green. Run `openspec validate fix-loop-skill-loading --strict --no-interactive`. Commit.
