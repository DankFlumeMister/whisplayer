#!/usr/bin/env python3
"""Navidrome system-tray helper.

Launches a Navidrome server as a child process, shows a tray icon, and lets
you open the web UI or stop the server from the tray menu.

Usage (Windows example):

    pythonw navidrome_tray.py \
        --exe "G:\\Navidrome\\navidrome.exe" \
        --workdir "G:\\Navidrome" \
        --url http://localhost:4533

If something is already serving ``--url``/ping the script does NOT spawn a
second instance; it only shows the tray icon (Quit then leaves an externally
started server untouched).

Requires: pip install pystray pillow
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import urllib.request
import webbrowser
from pathlib import Path

import pystray
from PIL import Image, ImageDraw


def make_icon() -> Image.Image:
    """Draws a blue record disc inspired by the Navidrome logo."""
    scale = 4  # supersample for smooth edges
    size = 64 * scale
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    navy = (13, 71, 161, 255)      # outer rim
    blue = (33, 150, 243, 255)     # disc face
    light = (144, 202, 249, 255)   # groove highlight
    white = (255, 255, 255, 255)

    pad = 3 * scale
    d.ellipse([pad, pad, size - pad, size - pad], fill=navy)
    inset = 7 * scale
    d.ellipse([inset, inset, size - inset, size - inset], fill=blue)
    groove = 13 * scale
    d.ellipse([groove, groove, size - groove, size - groove],
              outline=light, width=2 * scale)

    center = size // 2
    hole = 5 * scale
    d.ellipse([center - hole, center - hole,
               center + hole, center + hole], fill=white)
    d.arc([9 * scale, 9 * scale, size - 9 * scale, size - 9 * scale],
          start=200, end=295, fill=(255, 255, 255, 170), width=2 * scale)
    return img.resize((64, 64), Image.LANCZOS)


def server_is_up(url: str) -> bool:
    try:
        with urllib.request.urlopen(url.rstrip("/") + "/ping", timeout=3):
            return True
    except Exception:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Navidrome system-tray helper")
    parser.add_argument(
        "--exe",
        default="navidrome.exe",
        help="path to the navidrome executable",
    )
    parser.add_argument(
        "--workdir",
        default=None,
        help="working directory for the navidrome process (config location)",
    )
    parser.add_argument(
        "--url",
        default="http://localhost:4533",
        help="base URL of the web UI",
    )
    args = parser.parse_args()

    already_up = server_is_up(args.url)
    proc: subprocess.Popen | None = None
    if not already_up:
        exe = Path(args.exe)
        if not exe.is_file():
            print(f"navidrome executable not found: {exe}", file=sys.stderr)
            return 1
        workdir = args.workdir or str(exe.parent)
        print(f"starting {exe} (workdir={workdir}) ...")
        # CREATE_NO_WINDOW keeps a console window from flashing on Windows.
        proc = subprocess.Popen(  # noqa: S603
            [str(exe)],
            cwd=workdir,
            creationflags=0x08000000,
        )

    def open_ui(_icon=None, _item=None) -> None:
        webbrowser.open(args.url)

    def quit_app(icon, _item=None) -> None:
        if proc is not None:
            print("stopping navidrome ...")
            proc.terminate()
        icon.stop()

    menu = pystray.Menu(
        pystray.MenuItem("Open web UI", open_ui, default=True),
        pystray.MenuItem(
            "Quit"
            + (" (stops server)" if proc is not None else " (external server kept)"),
            quit_app,
        ),
    )
    icon = pystray.Icon(
        "navidrome",
        icon=make_icon(),
        title=f"Navidrome - {args.url}",
        menu=menu,
    )
    print(f"tray running; web UI at {args.url}")
    icon.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
