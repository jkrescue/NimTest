#!/usr/bin/env bash
# Try pulling the NIM image and surface CND / 451 / auth hints.
set -euo pipefail

IMAGE="${1:-nvcr.io/nim/nvidia/domino-automotive-aero:2.0.0}"
LOG="${TMPDIR:-/tmp}/docker-pull-diagnose-$$.log"

echo "Pulling: $IMAGE (logging to $LOG)"
set +e
docker pull "$IMAGE" 2>&1 | tee "$LOG"
code=$?
set -e

echo "--- grep hints ---"
grep -E "CND|451|unauthorized|denied|Forbidden|proxy|timeout|TLS" "$LOG" || echo "(no known error keywords matched)"

exit "$code"
