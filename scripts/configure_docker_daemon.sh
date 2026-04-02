#!/usr/bin/env bash
# Overwrites /etc/docker/daemon.json — backup first if you have other keys.
# dockerd uses HTTP/HTTPS proxy for pulls/registry (shell https_proxy alone is not enough).
# Nested/AutoDL: DOCKER_DISABLE_IPTABLES=1 (default) adds iptables:false, ip-forward:false, bridge:none.
# Then restart dockerd (systemctl or: pkill dockerd; dockerd &).
set -euo pipefail

export DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-/root/autodl-tmp/docker}"
export DOCKER_HTTP_PROXY="${DOCKER_HTTP_PROXY:-http://127.0.0.1:7890}"
export DOCKER_HTTPS_PROXY="${DOCKER_HTTPS_PROXY:-$DOCKER_HTTP_PROXY}"
export DOCKER_NO_PROXY="${DOCKER_NO_PROXY:-localhost,127.0.0.1,::1}"
export DOCKER_DISABLE_IPTABLES="${DOCKER_DISABLE_IPTABLES:-1}"

mkdir -p "$DOCKER_DATA_ROOT"

python3 << 'PY'
import json
import os

cfg = {
    "data-root": os.environ["DOCKER_DATA_ROOT"],
    "proxies": {
        "http-proxy": os.environ["DOCKER_HTTP_PROXY"],
        "https-proxy": os.environ["DOCKER_HTTPS_PROXY"],
        "no-proxy": os.environ["DOCKER_NO_PROXY"],
    },
}
if os.environ.get("DOCKER_DISABLE_IPTABLES", "1") == "1":
    cfg["iptables"] = False
    cfg["ip-forward"] = False
    cfg["bridge"] = "none"

path = "/etc/docker/daemon.json"
with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print("Wrote", path)
PY

echo "Restart dockerd, then: docker info | grep -i proxy"
