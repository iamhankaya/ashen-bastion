#!/usr/bin/env python3
"""Maketleri PNG'ye çevirir: headless Chrome/Edge (ek bağımlılık yok). python3 shoot.py [ad-öneki]"""
import pathlib, subprocess, sys, shutil
HERE = pathlib.Path(__file__).parent
exe = next((p for p in ("C:/Program Files/Google/Chrome/Application/chrome.exe", "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe") if pathlib.Path(p).exists()), shutil.which("chromium") or shutil.which("google-chrome"))
pre = sys.argv[1] if len(sys.argv) > 1 else ""
for f in sorted(HERE.glob(pre + "*.html")):
    out = f.with_suffix(".png")
    subprocess.run([exe, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1", "--window-size=1080,2400",
                    "--virtual-time-budget=4000", f"--screenshot={out}", f.resolve().as_uri()], check=True, capture_output=True)
    print(out.name)
