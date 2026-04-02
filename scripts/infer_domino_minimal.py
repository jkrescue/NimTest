#!/usr/bin/env python3
"""
Minimal POST /v1/infer against DoMINO-Automotive-Aero NIM (Quickstart-aligned).
"""
from __future__ import annotations

import argparse
import io
import os
import struct
import sys
from pathlib import Path

import httpx
import numpy as np

REPO_ROOT = Path(__file__).resolve().parent.parent
CASE_DATA = REPO_ROOT / "cases" / "domino-automotive-aero" / "data"

DRIVAER_URL = (
    "https://huggingface.co/datasets/neashton/drivaerml/resolve/main/run_1/drivaer_1.stl"
)


def _proxy_from_env() -> str | None:
    return os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy") or os.environ.get(
        "HTTP_PROXY"
    ) or os.environ.get("http_proxy")


def write_minimal_stl(path: Path) -> None:
    """Single-triangle binary STL (one solid)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    name = b"nimtest-minimal-stl"
    header = name + b" " * (80 - len(name))
    n = 1
    normal = (0.0, 0.0, 1.0)
    v1 = (0.0, 0.0, 0.0)
    v2 = (1.0, 0.0, 0.0)
    v3 = (0.0, 1.0, 0.0)
    facet = struct.pack("<12fH", *normal, *v1, *v2, *v3, 0)
    with open(path, "wb") as f:
        f.write(header)
        f.write(struct.pack("<I", n))
        f.write(facet)


def download_drivaer_stl(dest_dir: Path) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)
    raw = dest_dir / "drivaer_1.stl"
    client_kw: dict = {"timeout": 600.0}
    if px := _proxy_from_env():
        client_kw["proxy"] = px
    with httpx.Client(**client_kw) as client:
        r = client.get(DRIVAER_URL, follow_redirects=True)
        r.raise_for_status()
        raw.write_bytes(r.content)
    return raw


def to_single_solid_stl(src: Path, dst: Path) -> None:
    import trimesh

    dst.parent.mkdir(parents=True, exist_ok=True)
    m = trimesh.load_mesh(str(src))
    if isinstance(m, trimesh.Scene):
        m = trimesh.util.concatenate(list(m.geometry.values()))
    m.export(str(dst))


def run_infer(
    base_url: str,
    stl_path: Path,
    stream_velocity: str,
    stencil_size: str,
    point_cloud_size: str,
    timeout: float,
    out_npz: Path,
) -> None:
    infer_url = f"{base_url.rstrip('/')}/v1/infer"
    data = {
        "stream_velocity": stream_velocity,
        "stencil_size": stencil_size,
        "point_cloud_size": point_cloud_size,
    }
    client_kw = {"timeout": timeout}
    if px := _proxy_from_env():
        client_kw["proxy"] = px
    with httpx.Client(**client_kw) as client:
        with open(stl_path, "rb") as stl_file:
            files = {"design_stl": (stl_path.name, stl_file, "application/octet-stream")}
            r = client.post(infer_url, data=data, files=files)

    if r.status_code != 200:
        print(r.text[:2000], file=sys.stderr)
        raise SystemExit(f"Inference failed HTTP {r.status_code}")

    out_npz.parent.mkdir(parents=True, exist_ok=True)
    out_npz.write_bytes(r.content)

    with np.load(io.BytesIO(r.content)) as output_data:
        keys = list(output_data.keys())
    print("Output NPZ keys:", keys)
    print("Wrote:", out_npz)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--url", default="http://127.0.0.1:8000")
    p.add_argument(
        "--download",
        action="store_true",
        help="Download DrivAerML drivaer_1.stl and merge to single solid (needs trimesh)",
    )
    p.add_argument(
        "--minimal-stl",
        action="store_true",
        help="Use a tiny synthetic STL (for mock / smoke)",
    )
    p.add_argument("--stl-path", type=Path, default=None, help="Use this STL instead of download/minimal")
    p.add_argument("--stream-velocity", default="30.0")
    p.add_argument("--stencil-size", default="1")
    p.add_argument("--point-cloud-size", default="500000")
    p.add_argument("--timeout", type=float, default=600.0)
    p.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Where to save response NPZ (default: cases/.../data/infer_output.npz)",
    )
    args = p.parse_args()

    out = args.output or (CASE_DATA / "infer_output.npz")

    if args.stl_path is not None:
        stl = args.stl_path.resolve()
        if not stl.is_file():
            print("STL not found:", stl, file=sys.stderr)
            return 1
    elif args.minimal_stl:
        stl = CASE_DATA / "minimal_single_solid.stl"
        write_minimal_stl(stl)
        print("Wrote minimal STL:", stl)
    elif args.download:
        raw_dir = CASE_DATA / "drivaerml_stls"
        single_dir = CASE_DATA / "drivaerml_single_solid_stls"
        raw = download_drivaer_stl(raw_dir)
        stl = single_dir / "drivaer_1_single_solid.stl"
        if not stl.is_file():
            to_single_solid_stl(raw, stl)
        print("Using STL:", stl)
    else:
        print("Choose one of: --download, --minimal-stl, or --stl-path", file=sys.stderr)
        return 1

    run_infer(
        args.url,
        stl,
        args.stream_velocity,
        args.stencil_size,
        args.point_cloud_size,
        args.timeout,
        out,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
