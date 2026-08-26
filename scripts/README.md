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
