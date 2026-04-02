# DoMINO-Automotive-Aero NIM 使用说明

在 **GPU + Docker** 上运行 NVIDIA **DoMINO-Automotive-Aero NIM**（汽车外气动 CFD 代理模型），并用本仓库脚本做健康检查与最小推理。

| 资源 | 链接 |
|------|------|
| 文档总览 / Quickstart / Prerequisites | [Overview](https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/overview.html) · [Quickstart](https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/quickstart-guide.html) · [Prerequisites](https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/prerequisites.html) |
| NGC 镜像与 tag | [domino-automotive-aero](https://catalog.ngc.nvidia.com/orgs/nim/teams/nvidia/containers/domino-automotive-aero) |

镜像约 **30GB+**，根分区常仅 ~30GB，需保证 **Docker 数据目录**有足够空间（见下文 `data-root`）。**Tag 以 Quickstart / NGC 为准**（示例：`2.0.0`）。

---

## 流程概览

1. 满足 GPU、Docker、[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)（按需）。  
2. **中国大陆访问 `nvcr.io`**：国内伙伴镜像 **或** 本机代理 + **Docker 守护进程代理**（shell 里 `export https_proxy` **不会**让 `docker pull` 走代理）。  
3. `docker login nvcr.io`（见下）→ `docker pull` → `docker run`（或 `./scripts/run_nim.sh`）。  
4. `smoke_health.py` → `infer_domino_minimal.py`。

**代理 + Mihomo 逐步命令**：[`cases/domino-automotive-aero/STEP_BY_STEP.md`](cases/domino-automotive-aero/STEP_BY_STEP.md)。

---

## 镜像获取（中国网络）

- **CND / 策略拦截**：[国内分销商说明](https://catalog.ngc.nvidia.com/china-nim-distributors)。

**路径 A — 伙伴仓库**  
取得 registry 与镜像名后：

```bash
docker login <partner-registry>
export NIM_IMAGE='<partner>/<repo>:<tag>'
export SKIP_DOCKER_LOGIN=1
./scripts/run_nim.sh
```

**路径 B — 本机 HTTP 代理（如 Mihomo `127.0.0.1:7890`）**  
让 **dockerd** 走代理，并建议把数据放大盘：

```bash
sudo bash scripts/configure_docker_daemon.sh   # 覆盖写入 /etc/docker/daemon.json，有自定义项请先备份
sudo systemctl restart docker                  # 无 systemd 则自行重启 dockerd
docker info | grep -i proxy
```

代理端口非 7890 时设置 `DOCKER_HTTP_PROXY` 后再执行脚本。示例合并文件见 [`cases/domino-automotive-aero/daemon.json.merge.example.json`](cases/domino-automotive-aero/daemon.json.merge.example.json)。

**Mihomo**：`cp scripts/config.yaml.example scripts/config.yaml` 填入订阅（单行 URL，已 `.gitignore`）→ `./scripts/install_mihomo.sh` → 后台启动见 `STEP_BY_STEP.md`。`gen_config.py` 使用 **url-test**、不把 `DIRECT` 放进拉 NIM 的策略组，减少 CND。

---

## NGC 登录与 `.env`

用户名必须为字面量 **`$oauthtoken`**，密码为 **NGC API Key**（[Personal Keys](https://org.ngc.nvidia.com/setup/personal-keys)，勾选 Catalog / Private Registry 等权限）。

```bash
printf '%s' "$NGC_API_KEY" | docker login nvcr.io -u '$oauthtoken' --password-stdin
```

持久化：`cp .env.example .env`，填写 `NGC_API_KEY`；`run_nim.sh` / `check_env.sh` 会自动 `source` 仓库根目录 `.env`。

---

## 拉取与运行

```bash
docker pull nvcr.io/nim/nvidia/domino-automotive-aero:2.0.0   # tag 以官方为准

docker run --rm --gpus 1 --shm-size 2g -p 8000:8000 -e NGC_API_KEY -t \
  nvcr.io/nim/nvidia/domino-automotive-aero:2.0.0
```

一键（自动读 `.env`，tag 可传参或使用 `NIM_TAG`）：`./scripts/run_nim.sh [tag]`。改端口：`export NIM_PORT=8001`。需要可加 `export USE_NVIDIA_RUNTIME=1`。

---

## 验证

```bash
pip install -r requirements.txt
python scripts/smoke_health.py --url http://127.0.0.1:8000
python scripts/infer_domino_minimal.py --url http://127.0.0.1:8000 --download
```

无镜像时：`mock_domino_nim.py` + `--minimal-stl`（见脚本内说明）。

**Python 依赖**：最小调用只需 `requirements.txt`；官方全套 + PyVista 见 `setup_prerequisites_client.sh`；3.12 用 `requirements-prerequisites-py312.txt`。

---

## AutoDL 等「容器实例」

[AutoDL 文档](https://www.autodl.com/docs/env/)写明：**容器实例内不支持使用 Docker**；若 `docker pull` 在解压层报 **`operation not permitted`** / **`unshare: operation not permitted`**，多为平台限制而非配置错误。可跑 `./scripts/diagnose_autodl_docker.sh` 做小镜像探针；需 Docker 时请改用平台支持的 **裸金属** 或其它主机。

---

## 脚本索引

| 脚本 | 说明 |
|------|------|
| `check_env.sh` | GPU / Docker / 代理提示 / `.env` |
| `configure_docker_daemon.sh` | 写入 `daemon.json`（代理 + `data-root` 等） |
| `install_mihomo.sh` | 安装 Mihomo 到 `/root/mihomo` |
| `run_nim.sh` | login（可跳过）+ pull + run |
| `smoke_health.py` / `infer_domino_minimal.py` / `mock_domino_nim.py` | 健康检查 / 推理 / 本地 Mock |
| `diagnose_ngc_pull.sh` / `diagnose_autodl_docker.sh` | 拉镜像诊断 / 容器内 Docker 探针 |
| `setup_prerequisites_client.sh` | 官方客户端依赖 + xvfb |

---

## 常见问题

| 现象 | 处理 |
|------|------|
| `CND Required` | 路径 A 或 B；dockerd 必须走代理；代理勿对 `nvcr.io` 直连 |
| `docker pull` CND 但 curl 走代理正常 | `docker info` 是否含 Proxy；是否重启 dockerd |
| `451` 且已 login | NGC 权益 / 组织合约 |
| `unknown runtime: nvidia` | 安装 NVIDIA Container Toolkit 或仅用 `--gpus` |
| 磁盘不足 | 扩容或调整 `data-root` |
| Python 3.12 与官方 pin 冲突 | `requirements-prerequisites-py312.txt` |

**安全**：勿将 NGC Key、订阅 URL、伙伴密码提交到 Git 或公开渠道。
