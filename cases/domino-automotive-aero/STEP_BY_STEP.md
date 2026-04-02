# 代理路径：从订阅到跑通 NIM

面向 **路径 B**：本机 HTTP 代理 + **Docker 守护进程**走代理拉 `nvcr.io`。概念与伙伴镜像路径见仓库根目录 [`README.md`](../../README.md)。

**要点**：只有配置 **dockerd** 的 `proxies`（或 `configure_docker_daemon.sh`）才能让 `docker pull` 走代理；shell 里的 `https_proxy` 不够。

---

## 1. 代理（Mihomo）

1. `cp ../../scripts/config.yaml.example ../../scripts/config.yaml`，**单行**填入 Clash 订阅 URL（已 `.gitignore`）。  
2. 安装并启动：

```bash
cd /path/to/nimtest
chmod +x scripts/install_mihomo.sh && ./scripts/install_mihomo.sh
nohup /root/mihomo/mihomo -d /root/mihomo >> /root/mihomo/run.log 2>&1 &
```

已有 Mihomo 时：把同一 URL 写入工作目录 `subscription.url`（首行），`python3 gen_config.py` 后启动。  
自定义目录：`export MIHOMO_ROOT=/your/path` 再执行 `install_mihomo.sh`。

3. 确认监听：`curl -x http://127.0.0.1:7890 -I https://www.gstatic.com/generate_204`（仅验证 shell，不等于 dockerd 已走代理）。

---

## 2. Docker：代理 + 数据目录

在**仓库根目录**执行（或把 `scripts/` 换成相对路径）：

```bash
cd /path/to/nimtest
sudo bash scripts/configure_docker_daemon.sh   # 可先备份现有 /etc/docker/daemon.json
sudo systemctl restart docker                  # 或自行重启 dockerd
docker info | grep -E 'Root Dir|Proxy'
```

需要改端口或盘路径：`DOCKER_HTTP_PROXY`、`DOCKER_DATA_ROOT` 等见脚本头部注释。手工合并可参考本目录 [`daemon.json.merge.example.json`](daemon.json.merge.example.json)。

---

## 3. NGC 与镜像

```bash
cd /path/to/nimtest
./scripts/check_env.sh
# 登录（或写入 .env 后手动 login）
printf '%s' "$NGC_API_KEY" | docker login nvcr.io -u '$oauthtoken' --password-stdin

export NIM_TAG="${NIM_TAG:-2.0.0}"
docker pull "nvcr.io/nim/nvidia/domino-automotive-aero:${NIM_TAG}"
# 大镜像可：nohup docker pull ... > ~/docker-pull.log 2>&1 &
```

失败时：`./scripts/diagnose_ngc_pull.sh "nvcr.io/nim/nvidia/domino-automotive-aero:${NIM_TAG}"`。

---

## 4. 启动 NIM 与客户端

容器终端保持运行，**另开终端**：

```bash
cd /path/to/nimtest
export NGC_API_KEY=...    # 或使用 .env
./scripts/run_nim.sh "${NIM_TAG:-2.0.0}"

pip install -r requirements.txt
python scripts/smoke_health.py --url "http://127.0.0.1:${NIM_PORT:-8000}"
# 下载 HF STL 若需代理：
export https_proxy=http://127.0.0.1:7890
python scripts/infer_domino_minimal.py --url "http://127.0.0.1:${NIM_PORT:-8000}" --download
```

输出默认：`cases/domino-automotive-aero/data/infer_output.npz`。

**无 GPU / 无镜像**：`mock_domino_nim.py` + `infer_domino_minimal.py --minimal-stl`（见根 `README.md`）。

---

## 5. 故障速查

| 现象 | 处理 |
|------|------|
| `CND Required` | dockerd 代理 + 订阅节点勿直连 `nvcr.io`；或改路径 A |
| 有 Proxy 仍拉不动 | 重启 dockerd；核对 `docker info` |
| `operation not permitted` 解压层 | 多为容器内 Docker 受限（见根 README · AutoDL） |
| 磁盘 | 换大盘 `DOCKER_DATA_ROOT` |

本目录其余文件：`daemon.json.merge.example.json`、`env.example`、`data/`（输出目录，大文件勿提交）。
