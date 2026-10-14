"""tests/parallel.lua on a hung case (run 8e207440: a picker test waited for keys and `make check` ran until
the gate's timeout): the worker is killed after TEST_STALL_S without progress, the hung case fails by name,
the cases before it keep their results and the rest of the shard fail as not run."""

import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
HUNG = """local T = MiniTest.new_set()
T["hang: ok first"] = function() end
T["hang: waits forever"] = function()
	vim.fn.getcharstr()
end
T["hang: never reached"] = function() end
return T
"""


class Stall(unittest.TestCase):
    def test_hung_case_fails_by_name(self) -> None:
        test = pathlib.Path(tempfile.mkdtemp(), "test_hang.lua")
        test.write_text(HUNG)
        env = {**os.environ, "JOBS": "1", "TEST_STALL_S": "2", "FILE": str(test)}
        cmd = ["nvim", "--headless", "--noplugin", "-u", "tests/minimal_init.lua", "-l", "tests/parallel.lua"]
        proc = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, timeout=60)
        out = proc.stdout + proc.stderr
        self.assertNotEqual(proc.returncode, 0, out)
        self.assertIn("hang: waits forever: hung: no progress for 2 s", out)
        self.assertIn("hang: never reached: not run", out)
        self.assertNotIn("FAIL in " + str(test) + " | hang: ok first", out)


if __name__ == "__main__":
    unittest.main()
