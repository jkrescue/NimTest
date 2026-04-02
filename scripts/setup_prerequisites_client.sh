#!/usr/bin/env bash
# Install official-style client deps; pick py312 file on Python 3.12+.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PY_MM="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
REQ="requirements-prerequisites-official.txt"
if python3 -c 'import sys; exit(0 if sys.version_info >= (3, 12) else 1)'; then
  REQ="requirements-prerequisites-py312.txt"
fi

echo "Using $REQ (Python ${PY_MM})"
pip install -r "$REQ"

if command -v apt-get &>/dev/null; then
  echo "Optional: xvfb for PyVista off-screen (sudo may be required)"
  sudo apt-get update -qq && sudo apt-get install -y xvfb || true
else
  echo "apt-get not found; install xvfb via your OS package manager if using PyVista headless."
fi

echo "Done."
