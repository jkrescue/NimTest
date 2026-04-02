# DoMINO-Automotive-Aero NIM：网络代理路径分步实操

本案例位于仓库根目录下的 `cases/domino-automotive-aero/`；脚本与依赖在仓库根目录的 `scripts/`、`requirements.txt`。  
目标：在**本机 HTTP 代理** + **Docker 守护进程走代理**的前提下，从 `nvcr.io` 拉取镜像、启动 NIM，并在 `nimtest` 下完成健康检查与最小推理。

> 官方 Quickstart：<https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/quickstart-guide.html>  
> 若仅 `export https_proxy=...`，**不会**让 `docker pull` 走代理；必须配置 **Docker daemon** 代理（见步骤 4）。

---

## 步骤 0：磁盘与 Docker 数据目录（强烈建议先做）

根分区约 30GB 时，**无法**容纳约 31GB+ 的未压缩镜像层级；请把 Docker 数据目录放到大盘（与根 README 一致）。

1. 查看空间：

   ```bash
   df -h / /root/autodl-tmp /autodl-pub 2>/dev/null
   ```

2. 创建数据目录（示例用 `/root/autodl-tmp/docker`，约 80GB 可用时请预留余量；更大镜像可改用 `/autodl-pub/...`）：

   ```bash
   sudo mkdir -p /root/autodl-tmp/docker
   ```

3. 配置 **Docker 默认走代理** + `data-root`（二选一）：

   - **一键写入**（覆盖整文件；有其它 `daemon.json` 键时请先备份）：  
     `sudo bash /root/nimtest/scripts/configure_docker_daemon.sh`  
     环境变量：`DOCKER_DATA_ROOT`、`DOCKER_HTTP_PROXY`、`DOCKER_HTTPS_PROXY`、`DOCKER_NO_PROXY`；嵌套环境默认 `DOCKER_DISABLE_IPTABLES=1`（与 `iptables:false` / `bridge:none` 一致）。
   - **手工合并**：参考本目录 [`daemon.json.merge.example.json`](daemon.json.merge.example.json)。

4. 重启 Docker 并确认：

   ```bash
   sudo systemctl restart docker
   # 若无 systemd：pkill dockerd; sudo dockerd &
   docker info | grep -E "Docker Root Dir|HTTP Proxy|HTTPS Proxy"
   ```

---

## 步骤 1：启动本机 HTTP 代理（示例端口 7890）

任选其一：

- **Mihomo / Clash 等**：监听 `127.0.0.1:7890`，且访问 `nvcr.io` 必须走**境外节点**（不要对 `nvcr.io` 直连，否则仍可能 **CND Required**）。根目录 `README.md` 附录 A 有 Mihomo 说明。
- **已有公司代理**：把下文中的 `127.0.0.1:7890` 换成你的 `host:port`。

### 1.1 订阅放在本仓库 `scripts/config.yaml` 时（与 Mihomo 衔接）

该文件约定为 **单行**：你的 **Clash/Mihomo 订阅 URL**（文件名虽为 `.yaml`，内容是链接，不是 Mihomo 运行配置）。模板见 [`scripts/config.yaml.example`](../../scripts/config.yaml.example)；真实文件已写入 `.gitignore`，避免误提交。

**方式 A（推荐）**：在仓库根目录一键安装到 `/root/mihomo`（读取 `scripts/config.yaml` 第一行作为订阅）：

```bash
cd /root/nimtest
chmod +x scripts/install_mihomo.sh
./scripts/install_mihomo.sh
nohup /root/mihomo/mihomo -d /root/mihomo >> /root/mihomo/run.log 2>&1 &
```

**方式 B**：已有 Mihomo 工作区时，把订阅拷成 `subscription.url`（**第一行即订阅**）：

```bash
chmod 600 /root/nimtest/scripts/config.yaml
install -m 600 /root/nimtest/scripts/config.yaml /root/mihomo/subscription.url
cd /root/mihomo && python3 gen_config.py && ./mihomo -d /root/mihomo
```

若目录不在 `/root/mihomo`，可 `export MIHOMO_ROOT=/your/path` 后再执行 `./scripts/install_mihomo.sh`。

自测（**仅验证 shell 流量**，不等于 `docker pull` 已走代理）：

```bash
curl -x http://127.0.0.1:7890 -I https://www.gstatic.com/generate_204
```

---

## 步骤 2：仅配置代理时的 `daemon.json` 片段

若已执行 `scripts/configure_docker_daemon.sh` 或步骤 0 已合并 `daemon.json.merge.example.json`，可跳过本节。

否则在 `/etc/docker/daemon.json` 中增加（与现有 JSON **合并**）：

```json
"proxies": {
  "http-proxy": "http://127.0.0.1:7890",
  "https-proxy": "http://127.0.0.1:7890",
  "no-proxy": "localhost,127.0.0.1,::1"
}
```

代理端口或地址变更时，同步修改此处（或重跑 `configure_docker_daemon.sh` 并指定 `DOCKER_HTTP_PROXY`）。

---

## 步骤 3：重启 Docker 并确认守护进程代理

```bash
sudo systemctl restart docker
docker info | grep -i proxy
```

应能看到 `HTTP Proxy` / `HTTPS Proxy` 指向你的代理。

---

## 步骤 4：仓库环境自检

```bash
cd /root/nimtest   # 或你的 nimtest 克隆路径
chmod +x scripts/check_env.sh scripts/run_nim.sh scripts/diagnose_ngc_pull.sh
./scripts/check_env.sh
```

---

## 步骤 5：NGC 登录（拉 `nvcr.io` 必需）

1. 在 [NGC Personal Keys](https://org.ngc.nvidia.com/setup/personal-keys) 创建 API Key，勾选 **NGC Catalog**、**NVIDIA Private Registry**（名称以控制台为准）。

2. 登录（用户名必须是字面量 **`$oauthtoken`**）：

   ```bash
   export NGC_API_KEY='你的Key'
   printf '%s' "$NGC_API_KEY" | docker login nvcr.io -u '$oauthtoken' --password-stdin
   ```

---

## 步骤 6：拉取镜像

**Tag 以 [Quickstart](https://docs.nvidia.com/nim/physicsnemo/domino-automotive-aero/latest/quickstart-guide.html) / [NGC Catalog](https://catalog.ngc.nvidia.com/orgs/nim/teams/nvidia/containers/domino-automotive-aero) 为准。** 示例：

```bash
export NIM_TAG="${NIM_TAG:-2.0.0}"
docker pull "nvcr.io/nim/nvidia/domino-automotive-aero:${NIM_TAG}"
```

大镜像可后台拉取：

```bash
nohup docker pull "nvcr.io/nim/nvidia/domino-automotive-aero:${NIM_TAG}" > ~/docker-pull-domino.log 2>&1 &
tail -f ~/docker-pull-domino.log
```

若失败，可先跑诊断脚本查看是否 **CND** / **451** 等：

```bash
./scripts/diagnose_ngc_pull.sh "nvcr.io/nim/nvidia/domino-automotive-aero:${NIM_TAG}"
```

---

## 步骤 7：启动 NIM 容器

```bash
cd /root/nimtest
export NGC_API_KEY='你的Key'   # 与登录时相同
./scripts/run_nim.sh "${NIM_TAG:-2.0.0}"
```

自定义镜像或端口：

```bash
export NIM_IMAGE='nvcr.io/nim/nvidia/domino-automotive-aero:2.0.0'
export NIM_PORT=8000
./scripts/run_nim.sh   # 已设 NIM_IMAGE 时第一个参数 tag 可省略
```

保持该终端运行；**另开终端**做步骤 8。

---

## 步骤 8：安装 Python 依赖并验证

```bash
cd /root/nimtest
pip install -r requirements.txt

# 健康检查（轮询 /v1/health/ready，首次启动可能需数分钟）
python scripts/smoke_health.py --url "http://127.0.0.1:${NIM_PORT:-8000}"

# 最小推理：下载 DrivAerML 示例 STL 并推理（需 trimesh + 外网或代理）
export https_proxy=http://127.0.0.1:7890   # 若 Python 下载 HF 需代理时
export http_proxy=http://127.0.0.1:7890
python scripts/infer_domino_minimal.py --url "http://127.0.0.1:${NIM_PORT:-8000}" --download
```

输出 NPZ 默认写入 `cases/domino-automotive-aero/data/infer_output.npz`。

---

## 步骤 9（可选）：无 GPU / 无镜像时打通客户端

```bash
python scripts/mock_domino_nim.py --port 8765 &
python scripts/smoke_health.py --url http://127.0.0.1:8765 --timeout 10
python scripts/infer_domino_minimal.py --url http://127.0.0.1:8765 --minimal-stl
```

---

## 故障对照（精简）

| 现象 | 处理 |
|------|------|
| `CND Required` | 确认 Docker **daemon** 代理；代理规则勿对 `nvcr.io` 直连；或改用国内伙伴镜像（见根 `README.md` 路径 A）。 |
| `docker pull` 慢/失败但 curl 走代理正常 | `docker info` 是否显示 Proxy；是否重启过 dockerd。 |
| 磁盘满 | `data-root` 放到 `/root/autodl-tmp` 或 `/autodl-pub`。 |
| Python 3.12 装依赖失败 | 使用 `requirements-prerequisites-py312.txt`（完整后处理）；最小推理只需 `requirements.txt`。 |

---

## 本目录文件

| 文件 | 说明 |
|------|------|
| `STEP_BY_STEP.md` | 本文（代理路径全流程） |
| `daemon.json.merge.example.json` | `data-root` + `proxies` 合并示例 |
| `env.example` | 环境变量模板（勿提交真实 Key） |
| `data/` | 推理输出与下载 STL 默认落盘目录（见 `.gitignore`） |
