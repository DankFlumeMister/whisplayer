#!/usr/bin/env python3
"""Minimal read-only WebDAV server exposing a local music library.

Purpose
-------
Whisplayer's WebDAV source speaks plain WebDAV, so it can point at any
compliant server: ``rclone serve webdav``, a NAS's built-in service, nginx, or
this script. This script exists for the case where the music lives on a plain
folder with no WebDAV front-end available.

Scope (deliberately narrow)
---------------------------
* Methods: ``OPTIONS``, ``PROPFIND`` (depth 0 and 1), ``HEAD``, ``GET``.
* ``GET`` only hands out image files unless ``--allow-audio`` is passed.
* The whole tree is read-only; no write method is implemented at all.
* A shared token is required on every request.

Because it is interchangeable with any other WebDAV server, the app is never
locked to this script.

HTTP ``Range`` (206 Partial Content) is implemented because an audio player
needs it: without range support a client has to download a whole file before
it can start, and seeking is impossible. Single ranges are served; a
multi-range request is answered with the full body (RFC 9110 allows a server
to ignore ``Range``), and an unsatisfiable single range yields 416.

Usage
-----
    python tools/webdav_server.py --root D:\\Music --port 8765 --token SECRET

    # optional
    --host 0.0.0.0        bind address (default 0.0.0.0)
    --allow-audio         also serve non-image files (off by default)
    --quiet               suppress per-request logging

Tests: ``python -m unittest tools.test_webdav_server``

Standard library only — no third-party dependencies.
"""

from __future__ import annotations

import argparse
import base64
import email.utils
import html
import logging
import mimetypes
import os
import posixpath
import re
import stat
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SERVER_NAME = "whisplayer-covers/1.0"

IMAGE_SUFFIXES = frozenset(
    {
        ".jpg",
        ".jpeg",
        ".png",
        ".webp",
        ".gif",
        ".bmp",
        ".avif",
    }
)

XML_DECL = '<?xml version="1.0" encoding="utf-8"?>\n'

log = logging.getLogger("webdav")


# --------------------------------------------------------------------------
# path handling
# --------------------------------------------------------------------------
class OutsideRoot(Exception):
    """Raised when a requested path escapes the served root."""


def _decode_href(href_path: str) -> str:
    """Percent-decode a request path (always '/'-separated, UTF-8)."""
    return urllib.parse.unquote(href_path)


def resolve(root: str, url_path: str) -> str:
    """Map a request path to an absolute filesystem path under *root*.

    Raises [OutsideRoot] for anything that escapes *root*, including ``..``
    segments and symlinks that point outside the tree.
    """
    decoded = _decode_href(url_path)
    # Normalise to a POSIX-relative path before touching the filesystem so
    # Windows drive letters and backslashes cannot smuggle in an absolute path.
    cleaned = posixpath.normpath(decoded.replace("\\", "/"))
    cleaned = cleaned.lstrip("/")
    if cleaned == "." or cleaned == "":
        return root
    if cleaned.startswith("../") or cleaned == "..":
        raise OutsideRoot(cleaned)
    candidate = os.path.join(root, *cleaned.split("/"))
    real_root = os.path.realpath(root)
    real_candidate = os.path.realpath(candidate)
    if real_candidate != real_root and not real_candidate.startswith(
        real_root + os.sep
    ):
        raise OutsideRoot(cleaned)
    return candidate


_RANGE_RE = re.compile(r"^bytes=(\d*)-(\d*)$")

# Sentinel returned by [parse_range] when a single range cannot be satisfied.
UNSATISFIABLE = "unsatisfiable"


def parse_range(header: str | None, size: int) -> tuple[int, int] | str | None:
    """Translate a ``Range`` header into an inclusive ``(start, end)`` pair.

    Returns:
      * ``(start, end)``  — a satisfiable single byte range.
      * ``UNSATISFIABLE`` — one range was requested but lies outside the file;
        the caller must answer 416.
      * ``None``          — no range (or a multi-range, which we decline to
        split); the caller sends the whole body with 200.
    """
    if not header:
        return None
    header = header.strip()
    if "," in header:
        # multipart/byteranges is not implemented — serve the full body.
        return None
    match = _RANGE_RE.match(header)
    if match is None:
        return None
    start_raw, end_raw = match.group(1), match.group(2)
    if start_raw == "" and end_raw == "":
        return None
    if size <= 0:
        return UNSATISFIABLE
    if start_raw == "":
        # "bytes=-N": the trailing N bytes.
        suffix = int(end_raw)
        if suffix <= 0:
            return UNSATISFIABLE
        return (max(0, size - suffix), size - 1)
    start = int(start_raw)
    if start >= size:
        return UNSATISFIABLE
    if end_raw == "":
        return (start, size - 1)
    end = int(end_raw)
    if end < start:
        return UNSATISFIABLE
    return (start, min(end, size - 1))


def href_for(url_path: str, is_dir: bool) -> str:
    """Percent-encoded href for a response, with a trailing slash for dirs.

    [url_path] must be a *decoded* path. Passing an already-encoded request
    path here encodes it a second time, turning ``%20`` into ``%2520``; the
    client then resolves that back to a literal ``%20`` and asks for a file
    that does not exist. That failure only shows up once a parent directory
    contains a space or non-ASCII character, which is why shallow trees look
    fine while deep ones silently 404.
    """
    parts = [urllib.parse.quote(part, safe="") for part in url_path.split("/") if part]
    joined = "/".join(parts)
    if not joined:
        # The served root. Without this the trailing-slash rule below would
        # emit "//", which is a valid but non-canonical path that some clients
        # resolve inconsistently.
        return "/"
    return f"/{joined}/" if is_dir else f"/{joined}"


# --------------------------------------------------------------------------
# PROPFIND rendering
# --------------------------------------------------------------------------
def _xml_escape(text: str) -> str:
    return html.escape(text, quote=True)


def _rfc1123(mtime: float) -> str:
    return email.utils.formatdate(mtime, usegmt=True)


def _propstat(props: list[tuple[str, str]], status: str = "HTTP/1.1 200 OK") -> str:
    if not props:
        return ""
    body = "".join(f"<D:{name}>{value}</D:{name}>" for name, value in props)
    return f"<D:propstat><D:prop>{body}</D:prop><D:status>{status}</D:status></D:propstat>"


def _entry_props(path: str, is_dir: bool) -> list[tuple[str, str]]:
    st = os.stat(path)
    name = os.path.basename(path.rstrip("/\\")) or "/"
    props: list[tuple[str, str]] = [
        (
            "resourcetype",
            "<D:collection/>" if is_dir else "",
        ),
        ("displayname", _xml_escape(name)),
        ("getlastmodified", _rfc1123(st.st_mtime)),
    ]
    if not is_dir:
        props.append(("getcontentlength", str(st.st_size)))
        ctype = mimetypes.guess_type(path)[0] or "application/octet-stream"
        props.append(("getcontenttype", ctype))
        props.append(("getetag", f'"{int(st.st_mtime)}-{st.st_size}"'))
    return props


def render_propfind(abs_path: str, url_path: str, depth: int) -> bytes:
    """207 Multi-Status body for *abs_path*, children included when depth == 1.

    [url_path] must be the **decoded** path: it is both echoed back in ``href``
    (after re-encoding) and joined with the on-disk child names, which are
    themselves decoded.
    """
    responses: list[str] = []
    is_dir = os.path.isdir(abs_path)

    def add(path: str, href: str, dirent: bool) -> None:
        responses.append(
            f"<D:response><D:href>{_xml_escape(href)}</D:href>"
            f"{_propstat(_entry_props(path, dirent))}</D:response>"
        )

    add(abs_path, href_for(url_path, is_dir), is_dir)
    if is_dir and depth == 1:
        try:
            names = sorted(os.listdir(abs_path))
        except OSError:
            names = []
        for name in names:
            child_abs = os.path.join(abs_path, name)
            child_url = f"{url_path.rstrip('/')}/{name}"
            try:
                add(child_abs, href_for(child_url, os.path.isdir(child_abs)), os.path.isdir(child_abs))
            except OSError:
                # Broken symlink / permission error — skip silently.
                continue
    body = (
        XML_DECL
        + '<D:multistatus xmlns:D="DAV:">'
        + "".join(responses)
        + "</D:multistatus>"
    )
    return body.encode("utf-8")


# --------------------------------------------------------------------------
# handler
# --------------------------------------------------------------------------
class WebDavHandler(BaseHTTPRequestHandler):
    server_version = SERVER_NAME
    protocol_version = "HTTP/1.1"

    # --- helpers ---------------------------------------------------------
    @property
    def _root(self) -> str:
        return self.server.root  # type: ignore[attr-defined]

    @property
    def _token(self) -> str:
        return self.server.token  # type: ignore[attr-defined]

    @property
    def _allow_audio(self) -> bool:
        return self.server.allow_audio  # type: ignore[attr-defined]

    def _authorized(self) -> bool:
        header = self.headers.get("Authorization", "")
        if header.startswith("Bearer "):
            return header[len("Bearer ") :].strip() == self._token
        if header.startswith("Basic "):
            try:
                raw = base64.b64decode(header[len("Basic ") :]).decode("utf-8")
            except Exception:
                return False
            # Username is ignored; the password carries the shared token.
            _, _, password = raw.partition(":")
            return password == self._token
        return False

    def _send(
        self,
        status: int,
        body: bytes = b"",
        headers: dict[str, str] | None = None,
        include_body: bool = True,
        content_length: int | None = None,
    ) -> None:
        self.send_response(status)
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        # HTTP/1.1 keep-alive makes Content-Length mandatory and exact: a
        # mismatch hangs the connection. Callers that answer HEAD or 206 pass
        # [content_length] because the body they hold is shorter than the
        # resource they describe.
        self.send_header(
            "Content-Length",
            str(len(body) if content_length is None else content_length),
        )
        self.end_headers()
        if include_body and body:
            self.wfile.write(body)

    def _unauthorized(self) -> None:
        self._send(
            401,
            b"Unauthorized",
            {
                "WWW-Authenticate": 'Basic realm="whisplayer-covers"',
                "Content-Type": "text/plain; charset=utf-8",
            },
        )

    def _log(self, status: int, note: str = "") -> None:
        log.info(
            "%s %s %s %s",
            self.command,
            self.path,
            status,
            note,
        )

    # --- methods ---------------------------------------------------------
    def do_OPTIONS(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if not self._authorized():
            self._unauthorized()
            return
        self._send(
            200,
            b"",
            {
                "DAV": "1",
                "Allow": "OPTIONS, PROPFIND, GET, HEAD",
                "MS-Author-Via": "DAV",
            },
            include_body=False,
            content_length=0,
        )
        self._log(200)

    def do_PROPFIND(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if not self._authorized():
            self._unauthorized()
            return
        # Drain a request body if the client sent one (allprop / propname).
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)

        depth_raw = (self.headers.get("Depth") or "1").strip().lower()
        depth = 1 if depth_raw in ("1", "infinity") else 0
        # self.path is still percent-encoded; resolve() decodes it itself,
        # but the hrefs we emit must be built from the decoded form.
        raw_path = urllib.parse.urlparse(self.path).path or "/"
        display_path = urllib.parse.unquote(raw_path)
        try:
            abs_path = resolve(self._root, raw_path)
        except OutsideRoot as exc:
            self._send(403, b"Forbidden", {"Content-Type": "text/plain"})
            self._log(403, str(exc))
            return
        if not os.path.exists(abs_path):
            self._send(404, b"Not Found", {"Content-Type": "text/plain"})
            self._log(404)
            return
        # Depth "infinity" is not implemented; answer as depth 1.
        body = render_propfind(abs_path, display_path, 1 if depth else 0)
        self._send(
            207,
            body,
            {"Content-Type": 'application/xml; charset="utf-8"'},
        )
        self._log(207, f"depth={depth}")

    def _serve_file(self, include_body: bool) -> None:
        if not self._authorized():
            self._unauthorized()
            return
        url_path = urllib.parse.urlparse(self.path).path or "/"
        try:
            abs_path = resolve(self._root, url_path)
        except OutsideRoot as exc:
            self._send(403, b"Forbidden", {"Content-Type": "text/plain"})
            self._log(403, str(exc))
            return
        if not os.path.isfile(abs_path):
            self._send(404, b"Not Found", {"Content-Type": "text/plain"})
            self._log(404)
            return
        suffix = os.path.splitext(abs_path)[1].lower()
        if suffix not in IMAGE_SUFFIXES and not self._allow_audio:
            self._send(
                403,
                b"Only images are served (use --allow-audio to widen)",
                {"Content-Type": "text/plain; charset=utf-8"},
            )
            self._log(403, "non-image blocked")
            return
        st = os.stat(abs_path)
        size = st.st_size
        ctype = mimetypes.guess_type(abs_path)[0] or "application/octet-stream"
        headers = {
            "Content-Type": ctype,
            "Last-Modified": _rfc1123(st.st_mtime),
            "ETag": f'"{int(st.st_mtime)}-{size}"',
            "Accept-Ranges": "bytes",
            "Cache-Control": "private, max-age=86400",
        }

        parsed = parse_range(self.headers.get("Range"), size)
        if parsed == UNSATISFIABLE:
            self._send(
                416,
                b"Range Not Satisfiable",
                {
                    "Content-Type": "text/plain; charset=utf-8",
                    "Content-Range": f"bytes */{size}",
                },
            )
            self._log(416)
            return

        if parsed is None or size == 0:
            start, end, status = 0, max(size - 1, 0), 200
            length = size
        else:
            start, end = parsed  # type: ignore[misc]
            status = 206
            length = end - start + 1
            headers["Content-Range"] = f"bytes {start}-{end}/{size}"

        if include_body and length > 0:
            try:
                with open(abs_path, "rb") as handle:
                    handle.seek(start)
                    payload = handle.read(length)
            except OSError:
                self._send(500, b"Read error", {"Content-Type": "text/plain"})
                self._log(500)
                return
        else:
            payload = b""

        self._send(status, payload, headers, content_length=length)
        self._log(status, f"{length}/{size}B range={start}-{end}")

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._serve_file(include_body=True)

    def do_HEAD(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._serve_file(include_body=False)

    def do_PUT(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._read_only()

    def do_DELETE(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._read_only()

    def do_MKCOL(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._read_only()

    def do_MOVE(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._read_only()

    def do_COPY(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._read_only()

    def do_LOCK(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._read_only()

    def _read_only(self) -> None:
        # Drain any body so the connection stays usable, then refuse.
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)
        self._send(
            405,
            b"Read-only server",
            {"Allow": "OPTIONS, PROPFIND, GET, HEAD", "Content-Type": "text/plain"},
        )
        self._log(405)

    def log_message(self, fmt: str, *args: object) -> None:
        # Route the default stderr chatter through our logger instead.
        log.debug(fmt, *args)


class WebDavServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(
        self,
        addr: tuple[str, int],
        root: str,
        token: str,
        allow_audio: bool,
    ) -> None:
        super().__init__(addr, WebDavHandler)
        self.root = os.path.abspath(root)
        self.token = token
        self.allow_audio = allow_audio


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------
def _valid_token(token: str) -> str:
    if not token:
        raise argparse.ArgumentTypeError("token must not be empty")
    return token


def _existing_dir(path: str) -> str:
    if not os.path.isdir(path):
        raise argparse.ArgumentTypeError(f"not a directory: {path}")
    return os.path.abspath(path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="webdav_server.py",
        description="Read-only WebDAV window onto a music library (covers only).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--root", required=True, type=_existing_dir, help="music library root")
    parser.add_argument("--port", type=int, default=8765, help="TCP port (default 8765)")
    parser.add_argument("--host", default="0.0.0.0", help="bind address (default 0.0.0.0)")
    parser.add_argument(
        "--token",
        required=True,
        type=_valid_token,
        help="shared secret; the app sends it as the basic-auth password",
    )
    parser.add_argument(
        "--allow-audio",
        action="store_true",
        help="serve non-image files too (off by default)",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="only log errors",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    logging.basicConfig(
        level=logging.ERROR if args.quiet else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        stream=sys.stderr,
    )
    # Windows consoles default to a legacy code page; make Japanese paths
    # printable instead of raising UnicodeEncodeError.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(errors="replace")  # type: ignore[attr-defined]
        except Exception:
            pass

    server = WebDavServer((args.host, args.port), args.root, args.token, args.allow_audio)
    print(f"Serving {args.root} read-only on http://{args.host}:{args.port}/")
    print(f"Token: {args.token}")
    print("Methods: OPTIONS, PROPFIND, GET, HEAD — images only" if not args.allow_audio
          else "Methods: OPTIONS, PROPFIND, GET, HEAD — all files")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
