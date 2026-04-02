#!/usr/bin/env bash
# Install MetaCubeX Mihomo to MIHOMO_ROOT (default /root/mihomo), subscription from nimtest/scripts/config.yaml
set -euo pipefail
NIMTEST="$(cd "$(dirname "$0")/.." && pwd)"
MIHOMO_ROOT="${MIHOMO_ROOT:-/root/mihomo}"
VER="${MIHOMO_VERSION:-v1.19.22}"
PKG="mihomo-linux-amd64-compatible-${VER}.gz"
URL="https://github.com/MetaCubeX/mihomo/releases/download/${VER}/${PKG}"

if [[ ! -f "$NIMTEST/scripts/config.yaml" ]]; then
  echo "Missing $NIMTEST/scripts/config.yaml — copy scripts/config.yaml.example and put your subscription URL on line 1." >&2
  exit 1
fi

mkdir -p "$MIHOMO_ROOT/providers"
install -m 600 "$NIMTEST/scripts/config.yaml" "$MIHOMO_ROOT/subscription.url"
cp "$NIMTEST/scripts/mihomo_gen_config.py" "$MIHOMO_ROOT/gen_config.py"
chmod +x "$MIHOMO_ROOT/gen_config.py"

TMP="$(mktemp)"
curl -sL -o "$TMP" "$URL"
gunzip -c "$TMP" > "$MIHOMO_ROOT/mihomo"
rm -f "$TMP"
chmod +x "$MIHOMO_ROOT/mihomo"

cat > "$MIHOMO_ROOT/start.sh" << 'EOS'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 gen_config.py
exec ./mihomo -d "$(pwd)"
EOS
chmod +x "$MIHOMO_ROOT/start.sh"

(cd "$MIHOMO_ROOT" && python3 gen_config.py)
chmod 600 "$MIHOMO_ROOT/config.yaml" "$MIHOMO_ROOT/subscription.url" 2>/dev/null || true

echo "Installed Mihomo $VER -> $MIHOMO_ROOT"
echo "  Start:  cd $MIHOMO_ROOT && ./start.sh"
echo "  Or:    nohup $MIHOMO_ROOT/mihomo -d $MIHOMO_ROOT >> $MIHOMO_ROOT/run.log 2>&1 &"
echo "  Then point Docker daemon proxies to http://127.0.0.1:\${MIHOMO_MIXED_PORT:-7890}"
