#!/usr/bin/env sh
# Pinned Python venv for the shortcut chain layer (KDL parser), in .tests/venv.
# Uses uv when available, else python3 -m venv + pip.
set -eu

KDL_VERSION="1.2.0" # kdl-py, KDL 1.0 (the dialect zellij 0.45 reads)
VENV="${TEST_VENV_DIR:-.tests/venv}"
PY="$VENV/bin/python"

if "$PY" -I -c "import importlib.metadata as m, sys; sys.exit(m.version('kdl-py') != '$KDL_VERSION')" 2>/dev/null; then
	exit 0
fi

if command -v uv >/dev/null 2>&1; then
	uv venv --quiet --allow-existing "$VENV"
	uv pip install --quiet --python "$PY" "kdl-py==$KDL_VERSION"
else
	python3 -m venv "$VENV"
	"$PY" -m pip install --quiet "kdl-py==$KDL_VERSION"
fi
echo "kdl-py pinned at $KDL_VERSION in $VENV"
