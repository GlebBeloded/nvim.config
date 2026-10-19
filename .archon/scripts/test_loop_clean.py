import contextlib
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import adopt_pick
import loop_clean


def run(*args: str, cwd: str) -> None:
    subprocess.run(args, cwd=cwd, check=True, capture_output=True)


class ChangeMode(unittest.TestCase):
    """loop_clean.py --change: one loop branch per change survives a `make queue` run."""

    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp()
        self.repo = os.path.join(self.tmp, "repo")
        os.mkdir(self.repo)
        self.cwd = os.getcwd()
        env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
        os.environ.update(env, ARCHON_DB=os.path.join(self.tmp, "none.db"))
        run("git", "init", "-q", "-b", "auto", cwd=self.repo)
        run("git", "commit", "-q", "--allow-empty", "-m", "base", cwd=self.repo)
        os.chdir(self.repo)

    def tearDown(self) -> None:
        os.chdir(self.cwd)
        os.environ.pop("ARCHON_DB")

    def branch(self, name: str, commits: int, start: str = "auto") -> str:
        path = os.path.join(self.tmp, name.replace("/", "_"))
        run("git", "worktree", "add", "-q", "-b", name, path, start, cwd=self.repo)
        for i in range(commits):
            run("git", "commit", "-q", "--allow-empty", "-m", f"{name} {i}", cwd=path)
        return path

    def branches(self) -> set[str]:
        return set(loop_clean.all_loop_branches())

    def change(self) -> None:
        loop_clean.clean(sorted(adopt_pick.candidates("c")), True, adopt_pick.pick("c"))

    def test_rerun_that_adopted_drops_the_older_branches(self) -> None:
        # picker-ui: loop/c, then reruns; the last adopted (merged) the earlier one
        self.branch("loop/c", 2)
        self.branch("loop/c-20261014-174246", 0)  # cancelled run, no commits
        run_path = self.branch("loop/c-20261014-185117", 0)
        run("git", "merge", "-q", "--no-ff", "-m", "adopt", "loop/c", cwd=run_path)
        run("git", "commit", "-q", "--allow-empty", "-m", "more", cwd=run_path)
        self.branch("loop/cx", 1)  # another change sharing the prefix
        self.change()
        self.assertEqual(self.branches(), {"loop/c-20261014-185117", "loop/cx"})

    def test_branch_deleted_after_the_listing_is_skipped(self) -> None:
        # run 3561c2d3's ship: loop-clean listed loop/c, then its ref was gone before classify (traceback, exit 1)
        self.branch("loop/c-20261014-185117", 1)
        loop_clean.clean(["loop/c", "loop/c-20261014-185117"], True, "loop/c-20261014-185117")
        self.assertIn("loop/c-20261014-185117", self.branches())

    def test_unmerged_sibling_with_own_work_is_kept(self) -> None:
        self.branch("loop/c", 2)
        self.branch("loop/c-20261014-174246", 1)
        self.change()
        self.assertEqual(self.branches(), {"loop/c", "loop/c-20261014-174246"})

    def test_shipped_branch_with_leftover_junk_is_dropped(self) -> None:
        path = self.branch("loop/c", 1)
        run("git", "merge", "-q", "--no-ff", "-m", "ship", "loop/c", cwd=self.repo)
        with open(os.path.join(path, "junk.txt"), "w") as junk:
            junk.write("x")
        self.change()
        self.assertEqual(self.branches(), set())
        self.assertFalse(os.path.exists(path))

    def test_live_run_branch_is_kept(self) -> None:
        self.branch("loop/c", 2)
        self.branch("loop/c-20261014-174246", 0)
        os.environ["ARCHON_DB"] = os.path.join(self.tmp, "live.db")
        with contextlib.closing(sqlite3.connect(os.environ["ARCHON_DB"])) as conn, conn:
            conn.execute("create table remote_agent_workflow_runs (status text, working_path text)")
            conn.execute("insert into remote_agent_workflow_runs values ('running', '/x/loop/c-20261014-174246')")
        self.change()
        self.assertEqual(self.branches(), {"loop/c", "loop/c-20261014-174246"})


if __name__ == "__main__":
    unittest.main()
