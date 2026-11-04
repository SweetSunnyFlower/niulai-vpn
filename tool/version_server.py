#!/usr/bin/env python3
"""Tiny local mock server for testing the app update endpoint."""

import json
import os
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/vpn":
            host = self.headers.get("Host", "127.0.0.1:8090")
            payload = {
                "version": "1.0.1",
                "force_update": True,
                "download_url": f"http://{host}/vpn-1.0.1.apk",
                "release_notes": "测试 APP 内下载安装包。",
            }
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if self.path == "/vpn-1.0.1.apk":
            apk_path = Path(__file__).resolve().parent / "apk" / "vpn-1.0.1.apk"
            if not apk_path.exists():
                self.send_response(404)
                self.end_headers()
                return
            body = apk_path.read_bytes()
            self.send_response(200)
            self.send_header(
                "Content-Type", "application/vnd.android.package-archive"
            )
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        else:
            self.send_response(404)
            self.end_headers()
            return

    def log_message(self, format, *args):
        print(format % args)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8090"))
    server = HTTPServer(("0.0.0.0", port), Handler)
    print(f"mock version server listening on 0.0.0.0:{port}")
    server.serve_forever()
