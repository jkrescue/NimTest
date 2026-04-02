#!/usr/bin/env bash
# Login (optional) + pull + run DoMINO-Automotive-Aero NIM.
# Env: NGC_API_KEY (required), NIM_IMAGE, NIM_PORT, SKIP_DOCKER_LOGIN, USE_NVIDIA_RUNTIME=1
# Auto-loads repo-root .env if present (set NGC_API_KEY there to avoid re-exporting).
set -euo pipefail
_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${_REPO}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${_REPO}/.env"
  set +a
fi

TAG="${1:-${NIM_TAG:-2.0.0}}"
DEFAULT_IMAGE="nvcr.io/nim/nvidia/domino-automotive-aero:${TAG}"
IMG="${NIM_IMAGE:-$DEFAULT_IMAGE}"
PORT="${NIM_PORT:-8000}"

if [[ -z "${NGC_API_KEY:-}" ]]; then
  echo "ERROR: set NGC_API_KEY for container runtime and nvcr login." >&2
  exit 1
fi

if [[ "${SKIP_DOCKER_LOGIN:-0}" != "1" ]]; then
  if [[ "$IMG" == nvcr.io/* ]]; then
    printf '%s' "$NGC_API_KEY" | docker login nvcr.io -u '$oauthtoken' --password-stdin
  fi
else
  echo "SKIP_DOCKER_LOGIN=1 — skipping docker login"
fi

echo "Pulling $IMG ..."
docker pull "$IMG"

RUNTIME_ARGS=(--gpus 1 --shm-size 2g)
if [[ "${USE_NVIDIA_RUNTIME:-0}" == "1" ]]; then
  RUNTIME_ARGS=(--runtime=nvidia "${RUNTIME_ARGS[@]}")
fi

echo "Starting NIM on host port ${PORT} -> container 8000 ..."
exec docker run --rm "${RUNTIME_ARGS[@]}" \
  -p "${PORT}:8000" \
  -e NGC_API_KEY \
  -t "$IMG"
