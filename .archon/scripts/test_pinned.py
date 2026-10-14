"""pinned.py and spec_gate.py agree on the pinned set (fixtures from runs ad2c675d/c8a3a540 and 09320f96).

Run: python3 -m unittest discover -s .archon/scripts -p 'test_*.py'
"""

import os
import pathlib
import sys
import tempfile
import textwrap
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pinned  # noqa: E402
import spec_gate  # noqa: E402

RUN_SPEC = """\
# run Specification

## Requirements

### Requirement: Run dispatches by readable project marker
The config SHALL make `:Run` execute the browser command when `index.html` is readable, otherwise execute `cargo run` from the nearest ancestor containing `Cargo.toml` when `Cargo.lock` is readable.

#### Scenario: Run ignores a directory without a supported project marker
- **WHEN** `:Run` is executed in a directory where neither `index.html` nor `Cargo.lock` is readable
- **THEN** neither the browser command nor `cargo run` is executed

#### Scenario: Run executes cargo run when Cargo.lock is readable
- **WHEN** `:Run` is executed where `Cargo.lock` is readable inside a Cargo project whose nearest `Cargo.toml` ancestor path may contain spaces, and `index.html` is not readable
- **THEN** `cargo run` is executed from that Cargo project root with the path preserved

#### Scenario: Run opens the browser when index.html is readable
- **WHEN** `:Run` is executed in a directory where `index.html` is readable
- **THEN** the browser command is executed for `index.html`
"""

RUN_LUA = """\
local function root()
	return vim.fs.root(0, "Cargo.toml")
end
if vim.fn.filereadable("index.html") == 1 then
elseif vim.fn.filereadable("Cargo.lock") == 1 then
end
"""

# fix-run-cargo-root-from-cwd as queued (dced0e6)
RUN_PROPOSAL = """\
## Why
`vim.fs.root(0, "Cargo.toml")` searches from the current buffer.

## What Changes
- Search the Cargo root from the cwd (`vim.fs.root(vim.fn.getcwd(), "Cargo.toml")`), falling back to the cwd itself.

## Capabilities
### Modified Capabilities
None. `skip_specs: true`.

## Impact
- Code: `lua/gleb/run/init.lua`, `tests/unit/run/test_run.lua`.
"""

# the line the spec step wrote for the one pin it was given (archived proposal)
RUN_IMPACT_15 = (
    "- `run: Run executes cargo run when Cargo.lock is readable` still holds because the fix makes Cargo root"
    " discovery follow the cwd where the readable marker was found, after a readable `Cargo.lock` selected"
    " the Cargo runner and not `index.html`.\n"
)

FILE_TREE_SPEC = """\
# file-tree Specification

## Requirements

### Requirement: git status tree mappings

#### Scenario: gr keeps its global meaning in git status tree
- **WHEN** the `git_status` tree buffer is current and `vim.fn.maparg("gr", "n", false, true)` is read
- **THEN** the result is the global mapping (`buffer` is 0) whose callback invokes Telescope `lsp_references`
"""

KEYMAPS_SPEC = """\
# keymaps Specification

## Requirements

### Requirement: LSP keymaps

#### Scenario: gr bound to Telescope references
- **WHEN** the full config is loaded, the callback for normal-mode `gr` is invoked
- **THEN** the callback calls Telescope `lsp_references`
"""

KEYMAPS_LUA = """\
local function lsp_references()
	require("telescope.builtin").lsp_references({ include_current_line = true })
end
map("n", "gr", lsp_references, "LSP: References")
"""

# the adopted branch loop/fix-lsp-references-current-line (e48b0ba), git diff -U0 -- lua/
LSP_DIFF = """\
--- a/lua/gleb/keymaps.lua
+++ b/lua/gleb/keymaps.lua
@@ -103,0 +104,4 @@
+local function lsp_references()
+	require("telescope.builtin").lsp_references({ include_current_line = true })
+end
+
@@ -108 +112 @@
-map("n", "gr", require("telescope.builtin").lsp_references, "LSP: References")
+map("n", "gr", lsp_references, "LSP: References")
"""

LSP_PROPOSAL = """\
## Why
`gr` drops every reference on the cursor's line.

## What Changes
- `gr`: `lsp_references({ include_current_line = true })` (a small named function in `keymaps.lua`).

## Capabilities
### Modified Capabilities
- `lsp`: `Go references workflow` lists the declaration under the cursor too.

## Impact
- Code: `lua/gleb/keymaps.lua`.
- Core keymaps: `gr` same key; the picker also lists references on the cursor's line.
"""


class Repo:
    """A temp cwd holding openspec/specs, openspec/changes/<change> and lua/."""

    def __init__(self, specs: dict[str, str], lua: dict[str, str], change: str, proposal: str):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        for cap, text in specs.items():
            self.write(f"openspec/specs/{cap}/spec.md", text)
        for path, text in lua.items():
            self.write(f"lua/{path}", text)
        self.change = change
        self.proposal(proposal)

    def write(self, rel: str, text: str) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def proposal(self, text: str) -> None:
        self.write(f"openspec/changes/{self.change}/proposal.md", text)


class PinnedSetTest(unittest.TestCase):
    def setUp(self):
        self.cwd = os.getcwd()
        self.env = mock.patch.dict(os.environ, {"LOOP_CHANGES_DIR": ""})
        self.env.start()

    def tearDown(self):
        os.chdir(self.cwd)
        self.env.stop()

    def enter(self, repo: Repo, diff: str = "") -> None:
        os.chdir(repo.root)
        patch = mock.patch.object(pinned, "branch_diff", return_value=diff)
        patch.start()
        self.addCleanup(patch.stop)
        self.addCleanup(repo.tmp.cleanup)

    def gate(self, change: str) -> dict:
        with mock.patch.object(spec_gate, "checks", return_value=[]):
            return spec_gate.gate(change)

    def test_impact_line_for_a_pin_pins_nothing_new(self):
        """ad2c675d/c8a3a540: the spec step was told run/spec.md:15; its Impact line for :15 names
        `Cargo.lock` and `index.html`, which made the gate demand :11 and :19 too."""
        repo = Repo({"run": RUN_SPEC}, {"gleb/run/init.lua": RUN_LUA}, "fix-run-cargo-root-from-cwd", RUN_PROPOSAL)
        self.enter(repo)
        told = pinned.pinned(repo.change)
        self.assertEqual(told, ["run: Run executes cargo run when Cargo.lock is readable (openspec/specs/run/spec.md:12)"])
        repo.proposal(RUN_PROPOSAL + RUN_IMPACT_15)
        self.assertEqual(pinned.pinned(repo.change), [])
        self.assertEqual(self.gate(repo.change), {"ok": True, "log": ""})

    def test_gate_checks_the_set_the_pinned_node_prints(self):
        """09320f96: an adopted branch with every task ticked changes the `gr` mapping; the gate's red log
        lists exactly what the pinned node gives the spec-retry step, and Impact lines clear it."""
        repo = Repo(
            {"file-tree": FILE_TREE_SPEC, "keymaps": KEYMAPS_SPEC},
            {"gleb/keymaps.lua": KEYMAPS_LUA},
            "fix-lsp-references-current-line",
            LSP_PROPOSAL,
        )
        self.enter(repo, LSP_DIFF)
        told = pinned.pinned(repo.change)
        self.assertEqual([p.split(" (")[0] for p in told], [
            "file-tree: gr keeps its global meaning in git status tree",
            "keymaps: gr bound to Telescope references",
        ])
        result = self.gate(repo.change)
        self.assertFalse(result["ok"])
        self.assertEqual(result["log"], "pinned.py failed (exit 1):\n" + pinned.check_report(told))
        repo.proposal(LSP_PROPOSAL + textwrap.dedent("""\
            - `file-tree: gr keeps its global meaning in git status tree` still holds: `gr` stays global and calls `lsp_references`.
            - `keymaps: gr bound to Telescope references` still holds: `lsp_references` now includes the current line.
            """))
        self.assertEqual(pinned.pinned(repo.change), [])
        self.assertEqual(self.gate(repo.change), {"ok": True, "log": ""})


if __name__ == "__main__":
    unittest.main()
