"""Trial archive: archive the change in a scratch copy of openspec/ and validate the main specs it
produces (`openspec validate --specs --strict`), so a delta that breaks them (e.g. an overlong
requirement) is caught by spec-gate before any code is written, and by the build gate after.
As a script: spec_trial.py <change>; exit 0 when the archived specs are valid, else prints the tail."""

import os
import pathlib
import shutil
import subprocess
import sys
import tempfile


def run(cmd: list[str]) -> tuple[bool, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode == 0, proc.stdout + proc.stderr


def archived_specs_ok(change: str) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory() as tmp:
        shutil.copytree("openspec", pathlib.Path(tmp) / "openspec")
        cwd = os.getcwd()
        os.chdir(tmp)
        try:
            ok, out = run(["openspec", "archive", change, "--yes"])
            if ok:
                ok, out = run(["openspec", "validate", "--specs", "--strict", "--no-interactive"])
        finally:
            os.chdir(cwd)
    return ok, out


if __name__ == "__main__":
    ok, out = archived_specs_ok(sys.argv[1])
    if not ok:
        print("\n".join(out.splitlines()[-40:]))
    sys.exit(0 if ok else 1)
