#!/usr/bin/env python3
"""Tests for tools/webdav_server.py.

Run with:

    python -m unittest tools.test_webdav_server -v
    # or, from inside tools/
    python test_webdav_server.py

Standard library only, mirroring the server itself.

Why this file exists
--------------------
The server shipped with a double percent-encoding bug: ``href_for`` was fed
``self.path``, which is *already* percent-encoded, so ``%20`` became ``%2520``.
A client that trusted the href and asked for it again got a 404 — but only for
paths whose parent contained a space or a non-ASCII character. Shallow trees
looked perfect, which is exactly why the bug survived manual testing. The
``href round-trip`` test below is the regression guard: it never hard-codes a
URL, it always follows the href the server handed back.
"""

from __future__ import annotations

import http.client
import os
import shutil
import sys
import tempfile
import threading
import unittest
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from webdav_server import (  # noqa: E402
    UNSATISFIABLE,
    OutsideRoot,
    WebDavServer,
    href_for,
    parse_range,
    resolve,
)

TOKEN = "s3cret-token"

# Deliberately hostile names: a space, Japanese characters, a literal percent
# sign, and an ampersand (XML escaping). These are the shapes that break naive
# encoding chains.
ALBUM = "Album A"
NESTED = "日本語 フォルダ"
TRACK = "曲 1.mp3"
ODD = "100% & more.jpg"

MP3_BYTES = bytes(range(256)) * 4  # 1024 bytes, easy to slice


class ServerHarness:
    """A WebDavServer running on an ephemeral port in a background thread."""

    def __init__(self, root: str, *, allow_audio: bool = False) -> None:
        self.server = WebDavServer(("127.0.0.1", 0), root, TOKEN, allow_audio)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def stop(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)

    def request(
        self,
        method: str,
        path: str,
        *,
        headers: dict[str, str] | None = None,
        auth: bool = True,
    ) -> tuple[int, dict[str, str], bytes]:
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        try:
            sent = dict(headers or {})
            if auth:
                import base64

                blob = base64.b64encode(f"user:{TOKEN}".encode()).decode()
                sent["Authorization"] = f"Basic {blob}"
            conn.request(method, path, headers=sent)
            response = conn.getresponse()
            body = response.read()
            return response.status, dict(response.getheaders()), body
        finally:
            conn.close()


def _build_tree(root: str) -> None:
    nested = os.path.join(root, ALBUM, NESTED)
    os.makedirs(nested)
    with open(os.path.join(nested, TRACK), "wb") as handle:
        handle.write(MP3_BYTES)
    with open(os.path.join(nested, "cover.jpg"), "wb") as handle:
        handle.write(b"\xff\xd8\xff\xe0fake-jpeg")
    with open(os.path.join(root, ALBUM, ODD), "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")


class WebDavServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._tmp = tempfile.TemporaryDirectory(prefix="webdav-test-")
        cls.root = cls._tmp.name
        _build_tree(cls.root)
        cls.images = ServerHarness(cls.root, allow_audio=False)
        cls.audio = ServerHarness(cls.root, allow_audio=True)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.images.stop()
        cls.audio.stop()
        cls._tmp.cleanup()

    # --- auth ------------------------------------------------------------
    def test_missing_credentials_are_rejected(self) -> None:
        status, headers, _ = self.images.request("PROPFIND", "/", auth=False)
        self.assertEqual(status, 401)
        self.assertIn("WWW-Authenticate", headers)

    def test_wrong_token_is_rejected(self) -> None:
        import base64

        blob = base64.b64encode(b"user:wrong").decode()
        status, _, _ = self.images.request(
            "PROPFIND", "/", headers={"Authorization": f"Basic {blob}"}, auth=False
        )
        self.assertEqual(status, 401)

    # --- the regression this file exists for ------------------------------
    def test_href_round_trip_through_deep_non_ascii_paths(self) -> None:
        """Follow every href the server hands back; none may 404.

        This is the guard against the ``%20`` -> ``%2520`` double-encoding bug.
        It deliberately walks *into* the tree using the server's own hrefs,
        requested **verbatim** rather than re-encoded, because that is exactly
        what a real client does.
        """
        import urllib.parse
        import xml.etree.ElementTree as ET

        namespace = "{DAV:}"
        href = "/"
        visited: list[str] = []

        for _ in range(3):  # root -> Album A -> 日本語 フォルダ -> (leaf)
            status, _, body = self.audio.request(
                "PROPFIND", href, headers={"Depth": "1"}
            )
            self.assertEqual(
                status, 207, f"PROPFIND {href!r} returned {status}"
            )

            root = ET.fromstring(body)
            hrefs = [node.text or "" for node in root.iter(f"{namespace}href")]
            self.assertTrue(hrefs, "207 with no href entries")

            self_path = hrefs[0]
            # Every href must decode to something that could plausibly be on
            # disk: decoding twice must be a no-op, i.e. no "%2520" leftovers.
            self.assertEqual(
                urllib.parse.unquote(urllib.parse.unquote(self_path)),
                urllib.parse.unquote(self_path),
                f"href {self_path!r} looks double-encoded",
            )

            visited.append(urllib.parse.unquote(self_path))
            directories = [
                entry
                for entry in hrefs[1:]
                if entry.endswith("/") and entry != self_path
            ]
            if not directories:
                break
            # Descend into the first child directory, using its href as-is.
            href = directories[0]

        self.assertEqual(
            visited,
            ["/", f"/{ALBUM}/", f"/{ALBUM}/{NESTED}/"],
            "walk did not reach the deepest directory",
        )

    def test_deep_file_is_listed_and_fetchable(self) -> None:
        import urllib.parse

        deep_dir = f"/{urllib.parse.quote(ALBUM)}/{urllib.parse.quote(NESTED)}"
        status, _, body = self.audio.request("PROPFIND", deep_dir, headers={"Depth": "1"})
        self.assertEqual(status, 207)
        text = body.decode("utf-8")
        self.assertIn(urllib.parse.quote(TRACK), text)
        self.assertNotIn("%25", text, "response contains double-encoded hrefs")

        # The encoded href the server gave us must be directly fetchable.
        status, _, payload = self.audio.request(
            "GET", f"{deep_dir}/{urllib.parse.quote(TRACK)}"
        )
        self.assertEqual(status, 200)
        self.assertEqual(payload, MP3_BYTES)

    # --- PROPFIND details -------------------------------------------------
    def test_depth_zero_lists_only_the_target(self) -> None:
        import xml.etree.ElementTree as ET

        status, _, body = self.images.request(
            "PROPFIND", "/", headers={"Depth": "0"}
        )
        self.assertEqual(status, 207)
        hrefs = [n.text for n in ET.fromstring(body).iter("{DAV:}href")]
        self.assertEqual(hrefs, ["/"])

    def test_propfind_reports_size_and_type_for_a_file(self) -> None:
        import urllib.parse
        import xml.etree.ElementTree as ET

        target = (
            f"/{urllib.parse.quote(ALBUM)}/{urllib.parse.quote(NESTED)}"
            f"/{urllib.parse.quote(TRACK)}"
        )
        status, _, body = self.images.request("PROPFIND", target, headers={"Depth": "0"})
        self.assertEqual(status, 207)
        root = ET.fromstring(body)
        sizes = [n.text for n in root.iter("{DAV:}getcontentlength")]
        self.assertEqual(sizes, [str(len(MP3_BYTES))])

    def test_propfind_missing_path_is_404(self) -> None:
        status, _, _ = self.images.request("PROPFIND", "/nope", headers={"Depth": "0"})
        self.assertEqual(status, 404)

    def test_directory_traversal_cannot_escape_the_root(self) -> None:
        """``..`` segments collapse harmlessly instead of reaching the parent.

        ``resolve`` normalises an absolute URL path with ``posixpath.normpath``,
        which discards leading ``..`` segments — so these all land on a
        non-existent entry *inside* the root and answer 404. Nothing outside the
        root is ever opened.
        """
        hostile = (
            "/../../windows/win.ini",
            "/%2e%2e/%2e%2e/windows/win.ini",
            "/..%2f..%2fwindows%2fwin.ini",
            "/Album%20A/../../../windows/win.ini",
        )
        for path in hostile:
            with self.subTest(path=path):
                status, _, body = self.images.request(
                    "PROPFIND", path, headers={"Depth": "0"}
                )
                self.assertEqual(status, 404, f"{path} did not stay inside root")
                self.assertNotIn(b"multistatus", body)

    def test_get_cannot_read_outside_the_root(self) -> None:
        status, _, _ = self.images.request("GET", "/../../windows/win.ini")
        self.assertEqual(status, 404)

    # --- GET / Range ------------------------------------------------------
    def test_range_request_returns_206_and_the_right_slice(self) -> None:
        import urllib.parse

        target = (
            f"/{urllib.parse.quote(ALBUM)}/{urllib.parse.quote(NESTED)}"
            f"/{urllib.parse.quote(TRACK)}"
        )
        status, headers, payload = self.audio.request(
            "GET", target, headers={"Range": "bytes=10-19"}
        )
        self.assertEqual(status, 206)
        self.assertEqual(payload, MP3_BYTES[10:20])
        self.assertEqual(headers.get("Content-Range"), f"bytes 10-19/{len(MP3_BYTES)}")
        self.assertEqual(headers.get("Content-Length"), "10")

    def test_open_ended_range_runs_to_end_of_file(self) -> None:
        import urllib.parse

        target = (
            f"/{urllib.parse.quote(ALBUM)}/{urllib.parse.quote(NESTED)}"
            f"/{urllib.parse.quote(TRACK)}"
        )
        status, headers, payload = self.audio.request(
            "GET", target, headers={"Range": "bytes=1000-"}
        )
        self.assertEqual(status, 206)
        self.assertEqual(len(payload), 24)
        self.assertEqual(
            headers.get("Content-Range"),
            f"bytes 1000-{len(MP3_BYTES) - 1}/{len(MP3_BYTES)}",
        )

    def test_unsatisfiable_range_returns_416(self) -> None:
        import urllib.parse

        target = (
            f"/{urllib.parse.quote(ALBUM)}/{urllib.parse.quote(NESTED)}"
            f"/{urllib.parse.quote(TRACK)}"
        )
        status, headers, _ = self.audio.request(
            "GET", target, headers={"Range": f"bytes={len(MP3_BYTES) + 5}-"}
        )
        self.assertEqual(status, 416)
        self.assertEqual(headers.get("Content-Range"), f"bytes */{len(MP3_BYTES)}")

    def test_head_has_no_body_but_keeps_content_length(self) -> None:
        import urllib.parse

        target = (
            f"/{urllib.parse.quote(ALBUM)}/{urllib.parse.quote(NESTED)}"
            f"/{urllib.parse.quote(TRACK)}"
        )
        status, headers, payload = self.audio.request("HEAD", target)
        self.assertEqual(status, 200)
        self.assertEqual(payload, b"")
        self.assertEqual(headers.get("Content-Length"), str(len(MP3_BYTES)))

    # --- image-only policy ------------------------------------------------
    def test_audio_is_blocked_without_the_flag(self) -> None:
        import urllib.parse

        target = (
            f"/{urllib.parse.quote(ALBUM)}/{urllib.parse.quote(NESTED)}"
            f"/{urllib.parse.quote(TRACK)}"
        )
        status, _, _ = self.images.request("GET", target)
        self.assertEqual(status, 403)

    def test_percent_and_ampersand_in_filename_survive_encoding(self) -> None:
        import urllib.parse
        import xml.etree.ElementTree as ET

        target = f"/{urllib.parse.quote(ALBUM)}/{urllib.parse.quote(ODD)}"
        status, _, payload = self.images.request("GET", target)
        self.assertEqual(status, 200)
        self.assertEqual(payload, b"\x89PNG\r\n\x1a\n")

        status, _, body = self.images.request("PROPFIND", target, headers={"Depth": "0"})
        self.assertEqual(status, 207)
        text = body.decode("utf-8")
        # "&" is XML-escaped inside the element body, and the literal "%" in
        # the file name is encoded exactly once — as "%25".
        self.assertIn("&amp;", text)

        hrefs = [n.text or "" for n in ET.fromstring(body).iter("{DAV:}href")]
        self.assertEqual(
            [urllib.parse.unquote(h) for h in hrefs],
            [f"/{ALBUM}/{ODD}"],
            "href did not decode back to the on-disk relative path",
        )

    # --- write methods ----------------------------------------------------
    def test_write_methods_are_read_only(self) -> None:
        for method in ("PUT", "DELETE", "MKCOL", "MOVE", "COPY", "LOCK"):
            with self.subTest(method=method):
                status, _, _ = self.images.request(method, "/")
                self.assertEqual(status, 405)

    def test_options_advertises_dav(self) -> None:
        status, headers, _ = self.images.request("OPTIONS", "/")
        self.assertEqual(status, 200)
        self.assertEqual(headers.get("DAV"), "1")


class ResolveTest(unittest.TestCase):
    """Unit tests for the path mapper — no sockets involved."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="webdav-resolve-")
        self.root = self._tmp.name
        _build_tree(self.root)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_decodes_percent_escapes(self) -> None:
        self.assertEqual(resolve(self.root, "/Album%20A"), os.path.join(self.root, ALBUM))

    def test_decodes_non_ascii(self) -> None:
        encoded = f"/{urllib.parse.quote(ALBUM)}/{urllib.parse.quote(NESTED)}"
        self.assertEqual(
            resolve(self.root, encoded), os.path.join(self.root, ALBUM, NESTED)
        )

    def test_root_and_slash_only(self) -> None:
        self.assertEqual(resolve(self.root, "/"), self.root)
        self.assertEqual(resolve(self.root, ""), self.root)

    def test_rejects_paths_that_escape_via_link(self) -> None:
        """A link pointing outside the root must be refused.

        This is the one escape route ``normpath`` cannot close, because it is
        decided by the filesystem rather than by the URL text. Verified against
        real Windows junctions: ``realpath`` resolves them, so the prefix check
        in ``resolve`` fires.
        """
        outside = tempfile.mkdtemp(prefix="webdav-outside-")
        self.addCleanup(shutil.rmtree, outside, ignore_errors=True)
        link = os.path.join(self.root, "escape")
        try:
            os.symlink(outside, link, target_is_directory=True)
        except (OSError, NotImplementedError, AttributeError) as exc:
            self.skipTest(f"cannot create a link here: {exc}")
        is_link = os.path.islink(link) or (
            hasattr(os.path, "isjunction") and os.path.isjunction(link)
        )
        if not is_link:
            # Some Windows sandboxes silently degrade os.symlink() to mkdir,
            # which makes the test vacuous rather than failing.
            self.skipTest("os.symlink() produced a plain directory, not a link")
        with self.assertRaises(OutsideRoot):
            resolve(self.root, "/escape")


class ParseRangeTest(unittest.TestCase):
    """Unit tests for the Range header translation."""

    def test_absent_or_malformed_header_means_whole_body(self) -> None:
        for header in (None, "", "items=0-1", "bytes=abc", "bytes=-", "bytes=1-2,5-6"):
            with self.subTest(header=header):
                self.assertIsNone(parse_range(header, 100))

    def test_closed_range_is_clamped_to_the_file_size(self) -> None:
        self.assertEqual(parse_range("bytes=0-9", 100), (0, 9))
        self.assertEqual(parse_range("bytes=90-1000", 100), (90, 99))

    def test_open_ended_range(self) -> None:
        self.assertEqual(parse_range("bytes=50-", 100), (50, 99))

    def test_suffix_range_counts_back_from_the_end(self) -> None:
        self.assertEqual(parse_range("bytes=-10", 100), (90, 99))
        self.assertEqual(parse_range("bytes=-1000", 100), (0, 99))

    def test_out_of_bounds_and_inverted_ranges_are_unsatisfiable(self) -> None:
        self.assertEqual(parse_range("bytes=100-", 100), UNSATISFIABLE)
        self.assertEqual(parse_range("bytes=9-5", 100), UNSATISFIABLE)
        self.assertEqual(parse_range("bytes=0-0", 0), UNSATISFIABLE)

    def test_zero_length_file_has_no_satisfiable_range(self) -> None:
        self.assertEqual(parse_range("bytes=0-", 0), UNSATISFIABLE)


class HrefForTest(unittest.TestCase):
    """The encoding contract that the double-encoding bug violated."""

    def test_root_has_a_single_slash(self) -> None:
        self.assertEqual(href_for("/", is_dir=True), "/")
        self.assertEqual(href_for("", is_dir=True), "/")

    def test_directories_get_a_trailing_slash(self) -> None:
        self.assertEqual(href_for("/Album A", is_dir=True), "/Album%20A/")
        self.assertEqual(href_for("/Album A", is_dir=False), "/Album%20A")

    def test_encoding_twice_produces_the_double_encoded_hazard(self) -> None:
        """Documents *why* callers must pass a decoded path.

        Encoding twice is the bug that shipped: ``%20`` becomes ``%2520``, the
        client decodes it back to a literal ``%20``, and asks for a file that
        does not exist.
        """
        decoded = "/Album A/日本語 フォルダ"
        once = href_for(decoded, is_dir=True)
        self.assertEqual(urllib.parse.unquote(once), f"{decoded}/")

        twice = href_for(once, is_dir=True)
        self.assertIn("%2520", twice, "guard is vacuous if double-encoding is clean")
        self.assertNotEqual(twice, once)


if __name__ == "__main__":
    unittest.main(verbosity=2)
