#!/usr/bin/env python3
"""Minimal local HTTP server mimicking /v1/health/ready and /v1/infer (NPZ body)."""
from __future__ import annotations

import argparse
import io
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

import numpy as np


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: object) -> None:
        print(f"[{self.log_date_time_string()}] {fmt % args}")

    def do_GET(self) -> None:
        path = self.path.split("?")[0].rstrip("/")
        if path == "/v1/health/ready":
            body = json.dumps({"status": "ready"}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self) -> None:
        if not self.path.startswith("/v1/infer"):
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length > 0:
            self.rfile.read(length)

        buf = io.BytesIO()
        coords = np.zeros((4, 3), dtype=np.float32)
        surf = np.zeros((2, 3), dtype=np.float32)
        np.savez(
            buf,
            coordinates=np.expand_dims(coords, 0),
            velocity=np.zeros((1, 4, 3), dtype=np.float32),
            pressure=np.zeros((1, 4, 1), dtype=np.float32),
            turbulent_kinetic_energy=np.zeros((1, 4, 1), dtype=np.float32),
            turbulent_viscosity=np.zeros((1, 4, 1), dtype=np.float32),
            sdf=np.zeros((1, 4, 1), dtype=np.float32),
            surface_coordinates=np.expand_dims(surf, 0),
            pressure_surface=np.zeros((1, 2, 1), dtype=np.float32),
            wall_shear_stress=np.zeros((1, 2, 3), dtype=np.float32),
            drag_force=np.zeros((1, 1), dtype=np.float32),
            lift_force=np.zeros((1, 1), dtype=np.float32),
            bounding_box_dims=np.array([[[0, 0, 0]], [[1, 1, 1]]], dtype=np.float32),
        )
        raw = buf.getvalue()
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8765)
    args = ap.parse_args()
    httpd = HTTPServer((args.host, args.port), _Handler)
    print(f"Mock DoMINO NIM at http://{args.host}:{args.port} (Ctrl+C to stop)")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
