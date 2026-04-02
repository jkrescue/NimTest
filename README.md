# Physics NeMo · DoMINO-Automotive-Aero NIM 上手说明

本仓库帮助你在 **GPU + Docker** 环境下，把 NVIDIA 文档中的 **DoMINO-Automotive-Aero NIM**（汽车外部空气动力学代理模型，属 Physics NeMo / CFD 场景）跑起来，并完成 **健康检查** 与 **最小推理** 客户端验证。

## 1. 背景与官方入口

| 内容 | 链接 |
|------|------|
| 模型与 NIM 说明 | [Overview](https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/overview.html) |
| 前置条件（硬件 / Docker / NGC / 客户端包版本） | [Prerequisites](https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/prerequisites.html) |
| 拉镜像与启动命令（以页面 tag 为准） | [Quickstart](https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/quickstart-guide.html) |
| NGC 目录（含版本 tag） | [domino-automotive-aero](https://catalog.ngc.nvidia.com/orgs/nim/teams/nvidia/containers/domino-automotive-aero) |

**镜像与体积（量级概念，以 Quickstart 为准）**

- 镜像：`nvcr.io/nim/nvidia/domino-automotive-aero:<tag>`（示例：`2.1.0-41313772`）
- 容器镜像体积很大；**系统盘（常见云实例根分区约 30GB）可能不够**，需关注 `df -h /` 或把 Docker 数据目录放到大盘。

**概念**

- **Physics NeMo**：训练 / 实验框架（开源仓库 [physicsnemo](https://github.com/NVIDIA/physicsnemo)）。
- **NIM**：把特定模型封装成带 **HTTP API** 的推理服务（通常 **Docker 镜像**），在**你自己的 GPU 机器**上运行；不是「只填一个公网 URL」的通用 SaaS。

---

## 2. 推荐总流程（按顺序做）

```text
检查 GPU / Docker / 磁盘
        ↓
选择「镜像获取路径」（第二节）—— 中国 IP 常需：国内伙伴镜像 或 本机代理 + Docker 守护进程代理
        ↓
docker login nvcr.io（或伙伴仓库）
        ↓
docker pull
        ↓
docker run（映射 8000，传入 NGC_API_KEY）
        ↓
GET /v1/health/ready → POST /v1/infer（本仓库脚本）
```

---

## 3. 环境准备

### 3.1 本仓库脚本自检

```bash
chmod +x scripts/check_env.sh
./scripts/check_env.sh
```

需满足：**NVIDIA 驱动 + GPU**、**Docker 可用**、拉 `nvcr.io` 时还需 **`NGC_API_KEY`**（见下节登录）。  
GPU 进容器建议安装并配置 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)。若 `--runtime=nvidia` 报错，可尝试仅使用 `--gpus 1`（视 Docker 版本而定）。

### 3.2 磁盘

```bash
df -h /
```

根分区空间不足时，`docker pull` / 解压会失败；需扩容系统盘、或把 Docker 的 `data-root` 配置到大盘（具体依云平台文档）。

### 3.3 客户端 Python（调用 NIM HTTP API）

官方列表见 [Prerequisites · Client Side Python Dependencies](https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/prerequisites.html)。

- **一键安装（含 xvfb，便于跟官方 PyVista 后处理）**  
  `chmod +x scripts/setup_prerequisites_client.sh && ./scripts/setup_prerequisites_client.sh`
- **仅健康检查 + 最小推理**：`pip install -r requirements.txt`
- **版本说明**：Python **3.12** 无法用文档里的 `scipy==1.10.1` 等老 pin，请用 [`requirements-prerequisites-py312.txt`](requirements-prerequisites-py312.txt)；3.10/3.11 可用 [`requirements-prerequisites-official.txt`](requirements-prerequisites-official.txt)。

---

## 4. 镜像从哪拉（中国 IP 必读）

**分步案例（代理路径 B + `data-root` 示例）**：见 [`cases/domino-automotive-aero/STEP_BY_STEP.md`](cases/domino-automotive-aero/STEP_BY_STEP.md)。

`docker pull nvcr.io/nim/...` 在中国大陆出口 IP 上可能被策略拦截，错误信息含 **`CND Required` / `CND 必需`**，并指向：

- <https://catalog.ngc.nvidia.com/china-nim-distributors>

**两条可行主线（二选一或组合）：**

### 路径 A：使用国内合作伙伴提供的镜像仓库

1. 在伙伴平台完成资质 / 登录，取得 **registry 地址、镜像名:tag、`docker login` 方式**。  
2. 登录伙伴 registry 后拉取，例如：  
   `docker pull <partner-registry>/<repo>:<tag>`  
3. 使用本仓库脚本启动（不再对 `nvcr.io` 执行 login）：

```bash
docker login <partner-registry>   # 按伙伴说明
export NIM_IMAGE='<partner-registry>/<repo>:<tag>'
export SKIP_DOCKER_LOGIN=1
chmod +x scripts/run_nim.sh
./scripts/run_nim.sh   # 第二个参数 tag 仅对默认 nvcr 镜像生效；已设 NIM_IMAGE 时以 NIM_IMAGE 为准
```

`run_nim.sh` 默认把 **主机 `8000` → 容器 `8000`**。改端口：`export NIM_PORT=8001` 再运行脚本。

### 路径 B：本机 HTTP 代理（如 Mihomo）+ **Docker 守护进程**走代理再拉 `nvcr.io`

仅 `export https_proxy=...` **不会让** `docker pull` 走代理；必须让 **Docker daemon** 使用代理。

Mihomo 在本机上的目录结构、`url-test` 策略与端口说明见 **附录 A**。

1. 在本机启动代理，监听例如 `127.0.0.1:7890`，并确保访问 `nvcr.io` 时走**境外出口**（代理策略里不要对 `nvcr.io` 误走 `DIRECT`，否则仍可能触发 CND）。
2. 写入 `/etc/docker/daemon.json`，使 **dockerd 默认使用代理**（`docker pull` / registry 走代理；与 shell `https_proxy` 无关）：
   - **推荐**：`sudo bash scripts/configure_docker_daemon.sh`（含 `data-root` 到大盘、默认 `http://127.0.0.1:7890`；**覆盖整文件**，有其它键请先备份）。
   - 或手工合并，例如：

```json
{
  "data-root": "/root/autodl-tmp/docker",
  "proxies": {
    "http-proxy": "http://127.0.0.1:7890",
    "https-proxy": "http://127.0.0.1:7890",
    "no-proxy": "localhost,127.0.0.1,::1"
  }
}
```

3. **重启 Docker 守护进程**使配置生效；`docker info` 中应能看到 HTTP/HTTPS Proxy。
4. 再执行下节的 `docker login` 与 `docker pull`。

大镜像可后台拉取并跟日志，例如：`nohup docker pull ... > ~/docker-pull-domino.log 2>&1 &`

---

## 5. 登录 NGC 容器仓库（拉 `nvcr.io` 时）

用户名必须是字面量 **`$oauthtoken`**，密码为 **NGC API Key**。

```bash
docker logout nvcr.io   # 可选：换 Key 时建议先登出
export NGC_API_KEY='<你的 NGC API Key>'
printf '%s' "$NGC_API_KEY" | docker login nvcr.io -u '$oauthtoken' --password-stdin
```

**避免每次 export**：在仓库根目录复制模板并编辑 **`/.env`**（已 `.gitignore`，勿提交）：

```bash
cp .env.example .env && nano .env   # 填写 NGC_API_KEY=...
set -a && source .env && set +a       # 当前终端生效
```

`scripts/run_nim.sh` 与 `scripts/check_env.sh` 会**自动** `source` 该 `.env`。

在 [Personal Keys](https://org.ngc.nvidia.com/setup/personal-keys) 创建 Key 时，勾选 **NGC Catalog**、**NVIDIA Private Registry**（名称以控制台为准），否则可能出现认证异常。

---

## 6. 拉取与运行（与 Quickstart 对齐）

**tag 以 [Quickstart](https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/quickstart-guide.html) 为准**；下文仅为示例。

```bash
export NGC_API_KEY='<你的 Key>'   # 运行容器时同样需要
docker pull nvcr.io/nim/nvidia/domino-automotive-aero:2.1.0-41313772

docker run --rm --gpus 1 --shm-size 2g \
  -p 8000:8000 \
  -e NGC_API_KEY \
  -t nvcr.io/nim/nvidia/domino-automotive-aero:2.1.0-41313772
```

若你环境支持且文档要求，可再加 `--runtime=nvidia`。  
日志里可能出现容器内 **8080** 等字样，**客户端请访问你映射到主机的端口**（此处为 `http://127.0.0.1:8000`）。

**一键封装（默认 nvcr 镜像 + tag，可传参改 tag）**

```bash
export NGC_API_KEY='...'
chmod +x scripts/run_nim.sh
./scripts/run_nim.sh [tag]
```

已设 `NIM_IMAGE` / `SKIP_DOCKER_LOGIN` 时行为见第四节路径 A。

---

## 7. 验证服务

**健康检查（需另开终端，容器保持运行）**

```bash
pip install -r requirements.txt
python scripts/smoke_health.py --url http://127.0.0.1:8000
```

**最小推理（DrivAerML 示例 STL，需网络下载 + trimesh）**

```bash
python scripts/infer_domino_minimal.py --url http://127.0.0.1:8000 --download
```

无 NIM、仅验证客户端协议时，可用本地 Mock：

```bash
python scripts/mock_domino_nim.py --port 8765 &
python scripts/smoke_health.py --url http://127.0.0.1:8765 --timeout 10
python scripts/infer_domino_minimal.py --url http://127.0.0.1:8765 --minimal-stl
```

---

## 8. 本仓库脚本一览

| 脚本 | 用途 |
|------|------|
| `scripts/check_env.sh` | GPU / Docker / NGC_KEY / 可选 nvidia-toolkit 检查 |
| `scripts/configure_docker_daemon.sh` | 写入 `daemon.json`：`proxies` + `data-root`（dockerd 默认走代理；覆盖整文件前先备份） |
| `scripts/install_mihomo.sh` | 安装 Mihomo 到 `/root/mihomo`，订阅来自 `scripts/config.yaml` |
| `scripts/run_nim.sh` | `nvcr.io` 登录（可跳过）+ pull + run；支持 `NIM_IMAGE`、`NIM_PORT`、`SKIP_DOCKER_LOGIN` |
| `scripts/smoke_health.py` | 轮询 `/v1/health/ready` |
| `scripts/infer_domino_minimal.py` | 下载/准备 STL，`POST /v1/infer`，解析 NPZ |
| `scripts/mock_domino_nim.py` | 本地假服务，便于无镜像时打通客户端 |
| `scripts/diagnose_ngc_pull.sh` | 试拉镜像并根据输出提示 CND / 451 等 |
| `scripts/diagnose_autodl_docker.sh` | 评估嵌套容器 / Capabilities，小镜像 pull 探针（是否 `operation not permitted`） |
| `scripts/setup_prerequisites_client.sh` | 按官方 Prerequisites 安装 Python 依赖 + xvfb |

---

## 9. 常见问题（按现象查）

| 现象 | 可能原因 | 处理方向 |
|------|-----------|----------|
| **`CND Required` / `CND 必需`** | 中国大陆出口访问 NIM 受限 | 第四节路径 A 或 B；不要只靠 shell `https_proxy` |
| **`docker pull` 仍 CND，但 curl 走代理正常** | Docker daemon 未走代理，或代理对 `nvcr.io` 仍直连 | 检查 `daemon.json` + 重启 dockerd；检查代理规则是否 `DIRECT` |
| **`451`（且已 `docker login` 成功）** | NGC 账号对该资源无 entitlement | NGC 目录权限、组织合约、Key 服务范围；联系管理员或 NVIDIA 支持 |
| **`unauthorized` 拉伙伴仓库** | 未 `docker login` 伙伴 registry 或无权限 | 在伙伴平台完成登录/开通 |
| **`unknown or invalid runtime name: nvidia`** | 未配置 nvidia 容器运行时 | 安装 NVIDIA Container Toolkit，或改用 `--gpus` 方式 |
| **磁盘不足** | 根分区过小 | `df -h /`；扩容或迁移 Docker 数据目录 |
| **Python 3.12 装不上官方 scipy 等** | 官方 pin 不支持 3.12 | 使用 `requirements-prerequisites-py312.txt` |

---

## 10. 合规与安全

- **NGC API Key、订阅链接、伙伴仓库密码**视为机密：勿提交到 Git、勿发到公开聊天；泄露后请轮换。  
- 使用代理与第三方镜像须遵守 **NVIDIA**、**云平台**及当地法规与你的组织政策。

---

## 附录 A：本机 Mihomo（MetaCubeX）配置要点（配合第四节路径 B）

> 说明：以下目录 **`/root/mihomo`** 为在 GPU 实例上**单独放置**的 Mihomo 工作区，**不属于**本 Git 仓库；你可改到其它路径，但下文命令需同步替换。  
> **一键安装（从 `scripts/config.yaml` 读订阅）**：`chmod +x scripts/install_mihomo.sh && ./scripts/install_mihomo.sh`（会下载官方 Mihomo 二进制并生成配置；环境变量 `MIHOMO_ROOT`、`MIHOMO_VERSION` 可覆盖默认）。

### A.1 目录与文件角色

| 路径 | 作用 |
|------|------|
| `subscription.url` | **第一行**为 Clash/Mihomo 的 **HTTP 订阅 URL**（敏感，建议 `chmod 600`） |
| `nimtest/scripts/config.yaml` | **可选**：与本仓库约定一致时，存放**同一订阅 URL（整文件一行）**；已 `.gitignore`，可复制为 `subscription.url`（见案例 [`STEP_BY_STEP.md`](cases/domino-automotive-aero/STEP_BY_STEP.md) §1.1） |
| `gen_config.py` | 读取订阅 URL，生成 `config.yaml`（含 `proxy-providers` + 策略组） |
| `config.yaml` | 由脚本生成，**勿手工提交到 Git**（内含订阅地址） |
| `providers/sub.yaml` | 订阅拉取后的节点缓存（由内核维护） |
| `mihomo` | 官方发布的 Linux amd64 二进制（来源：[MetaCubeX/mihomo Releases](https://github.com/MetaCubeX/mihomo/releases)） |
| `start.sh` | `python3 gen_config.py` 后以前台方式启动：`./mihomo -d <目录>` |
| `README.txt` | 本目录内简要说明（若存在） |

若 GitHub 直连下载失败，可使用你环境可用的 **Release 镜像站**下载 `mihomo-linux-amd64-compatible-*.gz`，解压为可执行文件 `mihomo` 即可。

### A.2 推荐配置逻辑（为何用 `url-test`）

- 若策略组写成 **`select` 且含 `DIRECT`**，在订阅未就绪或误选时，日志容易出现 **`PROXY[DIRECT]`**，访问 `nvcr.io` 仍可能按**中国直连**判定，从而继续触发 **CND**。  
- 当前 `gen_config.py` 采用 **`url-test` + 仅 `use: sub`**：在订阅节点集合里自动测速选用，**不把 `DIRECT` 放进该组**，更符合「拉 NIM 必须走境外出口」这一目标。  
- 文档与更多字段说明见：[Mihomo Wiki](https://wiki.metacubex.one/)。

### A.3 启动与监听端口

```bash
cd /root/mihomo
chmod 600 subscription.url 2>/dev/null || true
python3 gen_config.py
# 前台调试：
#   ./mihomo -d /root/mihomo
# 后台示例：
#   nohup ./mihomo -d /root/mihomo > run.log 2>&1 &
```

- **混合代理（HTTP + SOCKS）**：`127.0.0.1:7890` —— 第四节里 Docker `daemon.json` 的 `http-proxy` / `https-proxy` 应指向此处。  
- **外部控制器（REST）**：`127.0.0.1:9090` —— 可用 `GET /proxies/PROXY` 查看当前策略组与节点；必要时可用 API 固定选用某节点（高级用法，见 Wiki）。

验证代理是否工作（**仅测 shell 流量**，不等于 `docker pull` 已走代理）：

```bash
curl -x http://127.0.0.1:7890 -I https://www.gstatic.com/generate_204
```

### A.4 与 Docker 的衔接（再强调）

1. **先**保证 Mihomo 已启动且 `7890` 监听。  
2. **再**配置 `/etc/docker/daemon.json` 中的 `proxies`（见 **第四节 · 路径 B**），并 **重启 dockerd**。  
3. `docker info` 中应出现 `HTTP Proxy: http://127.0.0.1:7890`（或你实际端口）。  
4. 然后再执行 `docker login` / `docker pull`。

### A.5 运维注意

- 改订阅后：重新写入 `subscription.url` → 执行 `python3 gen_config.py` → **重启** Mihomo 进程。  
- 避免多个 Mihomo 同时抢 `7890`/`9090`：改端口前需同步修改 Docker `daemon.json` 中的代理地址。  
- **订阅链接即凭证**：轮换、勿公开；与 **NGC Key** 同样处理。
