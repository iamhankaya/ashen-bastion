#!/usr/bin/env python3
"""Gemini (Interactions API, gemini-omni-1.1-flash) ile referans görselden kısa video üretir.

Kullanım: python3 tools/art/gen_video.py --image ref.png --prompt "..." --out art/source/<ad>/video/x.mp4
GEMINI_API_KEY ortamda olmalı. Çıktı mp4 repoya girmez (.gitignore: art/source/*/video/).
"""
import argparse
import base64
import json
import mimetypes
import os
import sys
import urllib.request

URL = "https://generativelanguage.googleapis.com/v1beta/interactions"
MODEL = "gemini-omni-1.1-flash"


def build_input(prompt, images):
    parts = [{"type": "text", "text": prompt}]
    for p in images:
        mime = mimetypes.guess_type(p)[0] or "image/png"
        with open(p, "rb") as f:
            parts.append({"type": "image", "mime_type": mime, "data": base64.b64encode(f.read()).decode()})
    return parts


def extract_video(resp):
    for step in resp.get("steps", []):
        for c in step.get("content", []):
            if c.get("type") == "video":
                return base64.b64decode(c["data"])
    return None


def generate(prompt, images, model=MODEL, key=None):
    key = key or os.environ["GEMINI_API_KEY"]
    body = json.dumps({"model": model, "input": build_input(prompt, images)}).encode()
    req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json", "x-goog-api-key": key})
    with urllib.request.urlopen(req, timeout=600) as r:
        return extract_video(json.load(r))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", action="append", default=[])
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    data = generate(a.prompt, a.image)
    if not data:
        sys.exit("video dönmedi")
    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    with open(a.out, "wb") as f:
        f.write(data)
    print("saved", a.out, len(data))


if __name__ == "__main__":
    main()
