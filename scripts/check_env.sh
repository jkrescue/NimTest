#!/usr/bin/env bash
# GPU / Docker / optional NGC key sanity check for DoMINO NIM workflow.
set -euo pipefail
_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${_REPO}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${_REPO}/.env"
  set +a
fi

ok=0
warn() { echo "[WARN] $*" >&2; }
fail() { echo "[FAIL] $*" >&2; ok=1; }
pass() { echo "[OK]   $*"; }

if command -v nvidia-smi &>/dev/null; then
  pass "nvidia-smi: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || true)"
else
  warn "nvidia-smi not found (GPU / driver check skipped)"
fi

if ! command -v docker &>/dev/null; then
  fail "docker not in PATH"
else
  pass "docker: $(docker --version)"
  if docker info &>/dev/null; then
    pass "docker daemon reachable"
    if docker info 2>/dev/null | grep -qi "HTTP Proxy"; then
      docker info 2>/dev/null | grep -i "Proxy" || true
    else
      warn "docker info shows no HTTP/HTTPS Proxy (docker pull will not use shell https_proxy)"
    fi
  else
    fail "docker daemon not reachable (try: sudo systemctl start docker)"
  fi
fi

if [[ -z "${NGC_API_KEY:-}" ]]; then
  warn "NGC_API_KEY is unset (required for docker login nvcr.io and for NIM container env)"
else
  pass "NGC_API_KEY is set (length ${#NGC_API_KEY})"
fi

if docker info 2>/dev/null | grep -q "Runtimes.*nvidia"; then
  pass "docker: nvidia runtime listed"
elif docker info 2>/dev/null | grep -q "nvidia"; then
  pass "docker info mentions nvidia"
else
  warn "nvidia container runtime not obvious in docker info; you may still use --gpus"
fi

echo "--- df (root) ---"
df -h / 2>/dev/null || true

exit "$ok"
