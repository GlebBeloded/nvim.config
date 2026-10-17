## 1. Reword the async advice

Scenarios: `loop: Agent prompts and context pack point probes at make probe`, `loop: Probe prints the snippet's return value`, `loop: Probe exits non-zero on an error`

- [ ] 1.1 Change `ASYNC` in tests/unit/loop/test_probe.lua to "LSP restart and tree and panel renders are async: wait for the end state, not for attachment." and see it fail
- [ ] 1.2 Update `.archon/scripts/context_pack.py` and `.archon/commands/{implement,fix,explore-bug}.md` to the same sentence
- [ ] 1.3 `grep -rn -i "neo-tree\|neotree\|neo_tree" .archon tests/unit/loop docs` prints nothing; reword or drop any leftover
- [ ] 1.4 Run `make loop-test` and `make check` and see them pass
