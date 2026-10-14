import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import adopt_pick  # noqa: E402


def run(*args: str, cwd: str) -> None:
    subprocess.run(args, cwd=cwd, check=True, capture_output=True)


class AdoptPick(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = tempfile.mkdtemp()
        self.cwd = os.getcwd()
        env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
        os.environ.update(env)
        run("git", "init", "-q", "-b", "auto", cwd=self.repo)
        run("git", "commit", "-q", "--allow-empty", "-m", "base", cwd=self.repo)
        os.chdir(self.repo)

    def tearDown(self) -> None:
        os.chdir(self.cwd)

    def branch(self, name: str, commits: int) -> None:
        run("git", "checkout", "-q", "-b", name, "auto", cwd=self.repo)
        for i in range(commits):
            run("git", "commit", "-q", "--allow-empty", "-m", f"{name} {i}", cwd=self.repo)
        run("git", "checkout", "-q", "auto", cwd=self.repo)

    def test_most_work_wins_over_the_oldest_branch(self) -> None:
        # run 9c94cd75 left loop/picker-ui (3 commits), a later run its stamped branch (11): adopt the later
        self.branch("loop/c", 3)
        self.branch("loop/c-20261014-174246", 11)
        self.branch("loop/c-20261014-185117", 1)
        self.branch("loop/cx", 20)  # another change sharing the prefix
        self.assertEqual(adopt_pick.pick("c"), "loop/c-20261014-174246")

    def test_no_branch_adopts_nothing(self) -> None:
        self.assertEqual(adopt_pick.pick("c"), "")


if __name__ == "__main__":
    unittest.main()
