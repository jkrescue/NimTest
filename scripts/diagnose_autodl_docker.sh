#!/usr/bin/env bash
# 评估当前环境是否适合在本机 docker pull / 解压镜像（嵌套容器常见限制）
set -euo pipefail

echo "========== 1. 是否在容器内 =========="
if [[ -f /.dockerenv ]]; then
  echo "[是] 存在 /.dockerenv — 当前环境很可能是 Docker/K8s 等容器"
else
  echo "[否] 无 /.dockerenv（仍可能是其它虚拟化）"
fi
echo "cgroup (self):"
head -3 /proc/self/cgroup 2>/dev/null || true

echo ""
echo "========== 2. PID1 有效 Capabilities（是否像「裁剪过的容器」）=========="
if [[ -r /proc/1/status ]]; then
  cap_hex=$(grep '^CapEff:' /proc/1/status | awk '{print $2}')
  echo "CapEff (pid 1) = $cap_hex"
  if command -v capsh &>/dev/null; then
    capsh --decode="$cap_hex" 2>/dev/null || true
  fi
  if [[ "$cap_hex" == "0000003fffffffff" ]] || [[ "$cap_hex" == "000001ffffffffff" ]]; then
    echo "[提示] 接近全能力，通常对嵌套 Docker 更友好"
  else
    echo "[提示] 非全能力集；若缺 cap_sys_admin 等，嵌套 Docker 解压 layer 常失败"
  fi
else
  echo "无法读取 /proc/1/status"
fi

echo ""
echo "========== 3. Docker =========="
if ! command -v docker &>/dev/null; then
  echo "[跳过] docker 未安装"
  exit 0
fi
docker info 2>/dev/null | grep -iE 'Server Version|Storage Driver|Docker Root Dir|Security Options|Cgroup' || docker info 2>&1 | head -5

echo ""
echo "========== 4. 功能探针：pull 小镜像（失败即受限）=========="
set +e
out=$(docker pull alpine:3.19 2>&1)
code=$?
set -e
echo "$out" | tail -6
if echo "$out" | grep -q 'operation not permitted'; then
  echo ""
  echo "[结论] pull 在 extract 阶段 operation not permitted → 嵌套/权限不足，无法用本机 Docker 正常拉镜像"
elif [[ "$code" -eq 0 ]]; then
  echo ""
  echo "[结论] 小镜像 pull 成功 → 本机 Docker 存储栈基本可用，可再试大镜像"
else
  echo ""
  echo "[结论] pull 失败 (exit $code)，查看上方错误（网络/鉴权/磁盘等）"
fi
