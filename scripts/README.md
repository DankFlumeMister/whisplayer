# Navidrome Tray

An optional helper script that runs a [Navidrome](https://www.navidrome.org)
server as a background child process and shows a system-tray icon, so the
console window never appears in your taskbar.

- Left-click / double-click the tray icon → open the web UI
- Right-click menu → *Open web UI* / *Quit*
- If a server is already answering on `--url`/ping, no second instance is
  spawned; Quit then leaves that externally started server untouched.

## Requirements

```bash
pip install pystray pillow
```

Works on Windows (recommended), macOS and Linux wherever `pystray` has a
backend available.

## Usage

```bash
python navidrome_tray.py --exe "G:\Navidrome\navidrome.exe" --workdir "G:\Navidrome"
```

| Flag | Default | Description |
| --- | --- | --- |
| `--exe` | `navidrome.exe` | Path to the navidrome executable |
| `--workdir` | exe's folder | Working directory (where `navidrome.toml` lives) |
| `--url` | `http://localhost:4533` | Base URL used for health checks and the web UI |

Tip: run it with `pythonw.exe` (Windows) to avoid any console window.

## Start automatically at login (Windows)

1. Press `Win+R`, type `shell:startup`, press Enter.
2. Create a shortcut in that folder:
   - Target: `"D:\miniconda\pythonw.exe" "path\to\navidrome_tray.py" --exe "G:\Navidrome\navidrome.exe" --workdir "G:\Navidrome"`
   - Start in: the folder containing `navidrome_tray.py`

After the next sign-in the tray icon appears automatically — no console
window, no taskbar entry.


---

## VTT lyrics support (`navidrome_vtt_support.py`)

Navidrome (up to 0.63.x) parses `.lrc` / `.srt` / `.ttml` / `.yaml` sidecar
lyrics — but **not `.vtt`**, which is the dominant subtitle format for
audio-work (RJ/ASMR) libraries. It also looks for sidecars under the
**extension-swapped** name (`track.wav` → `track.lrc`), so appended-form
files like `track.wav.lrc` are invisible to it.

This tool closes the gap: it parses every `.vtt` sitting next to an audio
track, strips markup (`<i>`, `<c>`, `{n8}`…), and writes a synced `.lrc`
under the extension-swapped name Navidrome expects. Lyrics become available
on the next lyrics request — no rescan required (Navidrome reads sidecars
at request time).

```bash
# preview what would happen
python navidrome_vtt_support.py --root "N:\Music" --dry-run --require-audio

# convert everything (idempotent: newer .vtt regenerates, otherwise kept)
python navidrome_vtt_support.py --root "N:\Music" --require-audio

# also clean up appended-form leftovers from earlier attempts
python navidrome_vtt_support.py --root "N:\Music" --require-audio --remove-misnamed
```

Notes:
- Pure standard library — no dependencies.
- `.vtt` files without a sibling audio track are skipped (`no-audio`).
- If lyrics still don't appear, your Navidrome instance needs one **full
  rescan** after the first mass conversion (quick scans ignore sidecar-only
  changes); afterwards new conversions apply instantly.
- Optional: add `.vtt` to Navidrome's `LyricsPriority` for future
  compatibility, though conversion is what makes it work today.
