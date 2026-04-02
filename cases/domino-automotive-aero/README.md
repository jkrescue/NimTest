# 案例：DoMINO-Automotive-Aero NIM（代理拉取 + nimtest 内验证）

- **分步操作（含 Docker 守护进程代理、data-root）**：请阅读 [`STEP_BY_STEP.md`](STEP_BY_STEP.md)。
- **仓库总览与路径 A（国内伙伴镜像）**：仓库根目录 [`README.md`](../../README.md)。
- **默认数据目录**：[`data/`](data/)（推理 NPZ、下载的 STL；大文件勿提交 Git）。

快速跳转：

1. [`daemon.json.merge.example.json`](daemon.json.merge.example.json) — 与现有 `/etc/docker/daemon.json` 合并时使用。
2. [`env.example`](env.example) — 环境变量模板。

验证命令（NIM 已启动后，在仓库根执行）：

```bash
python scripts/smoke_health.py --url http://127.0.0.1:8000
python scripts/infer_domino_minimal.py --url http://127.0.0.1:8000 --download
```
