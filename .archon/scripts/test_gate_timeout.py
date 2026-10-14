"""gate.py on an overloaded host (run 8e207440: `make check` ran past the node timeout and was killed with
no log): a check past CHECK_TIMEOUT_S ends as `infra` with its partial log kept, and is no attempt."""

import json
import os
import pathlib
import subprocess
import tempfile
import unittest

GATE = pathlib.Path(__file__).with_name("gate.py")
GIT = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}


class GateTimeout(unittest.TestCase):
    def test_check_past_the_timeout_is_infra_with_its_log(self) -> None:
        repo, scratch, artifacts = (tempfile.mkdtemp() for _ in range(3))
        env = {**os.environ, **GIT}
        pathlib.Path(repo, "README.md").write_text("x")
        for args in (["init", "-q", "-b", "auto"], ["add", "-A"], ["commit", "-q", "-m", "i"], ["checkout", "-q", "-b", "run"]):
            subprocess.run(["git", *args], cwd=repo, env=env, check=True, capture_output=True)
        make = pathlib.Path(scratch, "make")
        make.write_text("#!/bin/sh\necho 'ok   lint 0.1 s'\nsleep 30\n")
        make.chmod(0o755)
        env.update(
            PATH=f"{scratch}:{env['PATH']}", ARTIFACTS_DIR=artifacts, BASE_BRANCH="auto", INPUTS_CHANGE="", CHECK_TIMEOUT_S="1"
        )
        proc = subprocess.run(["python3", str(GATE)], cwd=repo, env=env, capture_output=True, text=True, timeout=20)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        out = json.loads(proc.stdout)
        self.assertEqual((out["green"], out["infra"]), (False, "check timed out"))
        self.assertIn("make check timed out after 1 s", out["failures"])
        log = pathlib.Path(artifacts, "check-1.log").read_text()
        self.assertIn("ok   lint", log)
        self.assertIn("check: TIMEOUT after 1 s", log)
        self.assertEqual(pathlib.Path(artifacts, "attempts").read_text(), "0")


if __name__ == "__main__":
    unittest.main()
