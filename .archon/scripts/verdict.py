"""End of one build iteration: passed when every gate holds (tests, spec, tasks, /opsx:verify without
CRITICAL, AI review approves). The loop stops when passed or after MAX_ATTEMPTS, so an exhausted fix
loop reaches the escalation check instead of failing the run.
"""

import json
import os

MAX_ATTEMPTS = 3


def value(name: str, default):
    raw = os.environ.get("INPUTS_" + name.upper(), "")
    try:
        return json.loads(raw) if raw != "" else default
    except json.JSONDecodeError:
        return raw


gates = {
    "tests": value("green", False) is True,
    "spec": value("spec_ok", False) is True,
    "tasks": value("tasks_done", False) is True,
    "verify": int(value("critical", -1)) == 0,
    "review": value("approve", False) is True,
}
passed = all(gates.values())
attempt = int(value("attempt", 0))
exhausted = not passed and attempt >= MAX_ATTEMPTS
print(
    json.dumps(
        {
            "done": passed or exhausted,
            "passed": passed,
            "exhausted": exhausted,
            "attempt": attempt,
            "failed_gates": ",".join(k for k, ok in gates.items() if not ok),
            "weakened_scenario": value("weakened_scenario", False) is True,
            "weakened_test": value("weakened_test", False) is True,
        }
    )
)
