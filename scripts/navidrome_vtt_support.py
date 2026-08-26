#!/usr/bin/env python3
"""Navidrome VTT support: batch-convert .vtt sidecar lyrics to .lrc.

Navidrome (<= 0.63.x) parses .lrc / .srt / .ttml sidecar lyrics but not
.vtt — which is the dominant subtitle format for audio works. This tool
walks a music library, parses every .vtt file that sits next to an audio
track and writes a sibling .lrc so Navidrome (and every Subsonic client)
can serve synced lyrics.

Sidecar naming matters: Navidrome looks for the AUDIO FILE NAME with the
extension swapped ("track.wav" -> "track.lrc"). Appended names such as
"track.wav.lrc" are invisible to it, so this tool writes the swapped form
and can optionally clean up appended-form leftovers (--remove-misnamed).

Pure standard library; cross-platform; idempotent by default (a newer
.vtt regenerates its .lrc, otherwise existing .lrc files are kept).

Usage:
    python navidrome_vtt_support.py --root "N:\\Music"            # convert
    python navidrome_vtt_support.py --root . --dry-run            # preview
    python navidrome_vtt_support.py --root . --force              # reconvert
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TIMING_RE = re.compile(
    r"(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})\s*-->\s*"
    r"(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2})[.,](\d{1,3})"
)
MARKUP_RE = re.compile(r"</?[A-Za-z][^>]*>")
POSITION_RE = re.compile(r"\{\\[^}]*\}")
AUDIO_EXTS = {
    ".mp3", ".wav", ".flac", ".m4a", ".aac", ".ogg", ".opus", ".wma",
}


def parse_ts(hours: str | None, minutes: str, seconds: str, fraction: str) -> int:
    h = int(hours) if hours else 0
    return h * 3_600_000 + int(minutes) * 60_000 + int(seconds) * 1_000 + int(
        fraction.ljust(3, "0")
    )


def clean_line(line: str) -> str:
    line = POSITION_RE.sub("", line)
    line = MARKUP_RE.sub("", line)
    return line.strip()


def parse_vtt(text: str) -> list[tuple[int, int, list[str]]]:
    if text.startswith("\ufeff"):
        text = text[1:]
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    cues: list[tuple[int, int, list[str]]] = []
    for block in text.split("\n\n"):
        lines = [line.strip() for line in block.split("\n")]
        timing_idx = next(
            (i for i, line in enumerate(lines) if "-->" in line), -1
        )
        if timing_idx < 0:
            continue
        match = TIMING_RE.search(lines[timing_idx])
        if not match:
            continue
        start = parse_ts(match[1], match[2], match[3], match[4])
        end = parse_ts(match[5], match[6], match[7], match[8])
        body = [clean_line(line) for line in lines[timing_idx + 1:]]
        body = [line for line in body if line]
        if not body:
            continue
        cues.append((start, max(end, start), body))
    cues.sort(key=lambda cue: cue[0])
    return cues


def to_lrc(cues: list[tuple[int, int, list[str]]]) -> str:
    out: list[str] = []
    for start, _end, text_lines in cues:
        stamp = "[%02d:%05.2f]" % (start // 60_000, (start % 60_000) / 1000.0)
        for line in text_lines:
            out.append(stamp + line)
    return "\n".join(out) + "\n"


def sibling_audio(vtt_path: Path) -> Path | None:
    """Audio file for an appended-form sidecar (xxx.wav.vtt -> xxx.wav)."""
    name = vtt_path.name
    if not name.lower().endswith(".vtt"):
        return None
    audio = vtt_path.with_name(name[:-4])
    if audio.suffix.lower() in AUDIO_EXTS and audio.exists():
        return audio
    return None


def swap_ext_lrc(vtt_path: Path) -> Path:
    """Navidrome-visible location: audio name with .lrc extension."""
    audio = sibling_audio(vtt_path)
    base = audio if audio is not None else vtt_path.with_suffix("")
    return base.with_suffix(".lrc")


def appended_form_lrc(vtt_path: Path) -> Path:
    return vtt_path.with_suffix(".lrc")


def convert(vtt_path: Path, force: bool, dry_run: bool) -> str:
    lrc_path = swap_ext_lrc(vtt_path)
    if lrc_path == vtt_path:
        return "same-path"
    if lrc_path.exists() and not force:
        if lrc_path.stat().st_mtime >= vtt_path.stat().st_mtime:
            return "skip-fresh"
    cues = parse_vtt(vtt_path.read_text(encoding="utf-8", errors="replace"))
    if not cues:
        return "no-cues"
    lrc = to_lrc(cues)
    if dry_run:
        return "would-convert"
    lrc_path.write_text(lrc, encoding="utf-8")
    return "converted"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert .vtt sidecar lyrics to Navidrome-readable .lrc"
    )
    parser.add_argument("--root", default=".", help="music library root")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument(
        "--require-audio",
        action="store_true",
        help="only convert .vtt files that sit next to an audio track",
    )
    parser.add_argument(
        "--remove-misnamed",
        action="store_true",
        help="delete useless appended-form files (xxx.wav.lrc) left by "
             "earlier runs",
    )
    args = parser.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    stats: dict[str, int] = {}
    root = Path(args.root)
    for vtt in sorted(root.rglob("*.vtt")):
        if args.require_audio and sibling_audio(vtt) is None:
            result = "no-audio"
        else:
            try:
                result = convert(vtt, args.force, args.dry_run)
                if args.remove_misnamed:
                    misnamed = appended_form_lrc(vtt)
                    if misnamed.exists():
                        misnamed.unlink()
                        result += "+removed-misnamed"
            except (OSError, ValueError) as exc:
                result = f"error: {exc}"
        key = result.split(":")[0].split("+")[0]
        stats[key] = stats.get(key, 0) + 1
        if result.startswith("error") or "+removed" in result:
            print(f"{result} <- {vtt}")

    print("--- summary ---")
    for key, count in sorted(stats.items()):
        print(f"{key}: {count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
