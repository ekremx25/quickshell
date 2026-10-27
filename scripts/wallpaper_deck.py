#!/usr/bin/env python3
"""Safe local/Wallhaven backend for the QuickShell wallpaper deck."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
WALLHAVEN_API = "https://wallhaven.cc/api/v1/search"
MAX_DOWNLOAD_BYTES = 50 * 1024 * 1024
USER_AGENT = "ekrem-quickshell-wallpaper-deck/1.0"


def emit(payload: object) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def fail(message: str, code: int = 1) -> None:
    emit({"ok": False, "error": message})
    raise SystemExit(code)


def expanded_dir(raw: str) -> Path:
    path = Path(raw).expanduser()
    return path.resolve(strict=False)


def local_wallpapers(directory: str) -> None:
    root = expanded_dir(directory)
    if not root.exists():
        emit({"ok": True, "directory": str(root), "items": [], "missing": True})
        return
    if not root.is_dir():
        fail("Wallpaper path is not a directory")

    items = []
    try:
        entries = list(root.iterdir())
    except OSError as exc:
        fail(f"Cannot read wallpaper directory: {exc}")
    # Stat each entry on its own so one broken symlink cannot empty the list.
    candidates = []
    for path in entries:
        try:
            if path.name.startswith(".") or not path.is_file() or path.suffix.lower() not in IMAGE_EXTENSIONS:
                continue
            candidates.append((path, path.stat()))
        except OSError:
            continue
    candidates.sort(key=lambda entry: entry[1].st_mtime, reverse=True)
    for path, stat in candidates:
        items.append({
            "id": "local:" + str(path),
            "source": "local",
            "name": path.stem,
            "path": str(path),
            "preview": path.as_uri(),
            "fileSize": stat.st_size,
            "colors": [],
            "resolution": "",
        })
        if len(items) >= 400:
            break
    emit({"ok": True, "directory": str(root), "items": items, "missing": False})


def wallhaven_search(query: str, page: int, sorting: str, atleast: str) -> None:
    allowed_sorting = {"relevance", "date_added", "views", "favorites", "toplist"}
    if sorting not in allowed_sorting:
        fail("Unsupported Wallhaven sorting mode")
    params = {
        "q": query.strip(),
        "page": max(1, page),
        "sorting": sorting,
        "order": "desc",
        "categories": "111",
        "purity": "100",
    }
    if atleast:
        params["atleast"] = atleast
    request = urllib.request.Request(
        WALLHAVEN_API + "?" + urllib.parse.urlencode(params),
        headers={"Accept": "application/json", "User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            data = json.load(response)
    except urllib.error.HTTPError as exc:
        if exc.code == 429:
            fail("Wallhaven rate limit reached; try again shortly")
        fail(f"Wallhaven request failed ({exc.code})")
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        fail(f"Wallhaven is unavailable: {exc}")

    raw_items = data.get("data") if isinstance(data, dict) else None
    meta = data.get("meta") if isinstance(data, dict) else None
    if not isinstance(raw_items, list) or not isinstance(meta, dict):
        fail("Wallhaven returned an invalid response")

    items = []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        wallpaper_id = str(item.get("id", ""))
        path = str(item.get("path", ""))
        thumbs = item.get("thumbs") if isinstance(item.get("thumbs"), dict) else {}
        if not wallpaper_id or not path.startswith("https://"):
            continue
        items.append({
            "id": wallpaper_id,
            "source": "wallhaven",
            "name": "Wallhaven " + wallpaper_id,
            "path": path,
            "preview": str(thumbs.get("large") or thumbs.get("original") or path),
            "colors": [str(color) for color in item.get("colors", []) if isinstance(color, str)][:5],
            "resolution": str(item.get("resolution", "")),
            "fileSize": int(item.get("file_size", 0) or 0),
            "category": str(item.get("category", "")),
        })
    emit({
        "ok": True,
        "items": items,
        "meta": {
            "currentPage": int(meta.get("current_page", page) or page),
            "lastPage": int(meta.get("last_page", page) or page),
            "total": int(meta.get("total", len(items)) or len(items)),
        },
    })


def validated_wallhaven_url(raw_url: str) -> tuple[str, str]:
    parsed = urllib.parse.urlparse(raw_url)
    host = (parsed.hostname or "").lower()
    if parsed.scheme != "https" or not (host == "wallhaven.cc" or host.endswith(".wallhaven.cc")):
        fail("Download URL is not a trusted Wallhaven host")
    extension = Path(parsed.path).suffix.lower()
    if extension not in IMAGE_EXTENSIONS:
        fail("Wallhaven returned an unsupported image type")
    return raw_url, extension


def download_wallpaper(raw_url: str, wallpaper_id: str, directory: str) -> None:
    url, extension = validated_wallhaven_url(raw_url)
    safe_id = "".join(char for char in wallpaper_id if char.isalnum() or char in "-_")[:80]
    if not safe_id:
        fail("Invalid Wallhaven wallpaper id")
    target_dir = expanded_dir(directory)
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / f"wallhaven-{safe_id}{extension}"
    if target.exists() and target.stat().st_size > 0:
        emit({"ok": True, "path": str(target), "cached": True})
        return

    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    temporary_name = None
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            content_type = response.headers.get_content_type()
            raw_content_length = response.headers.get("Content-Length", "0") or "0"
            try:
                content_length = int(raw_content_length)
            except (TypeError, ValueError):
                content_length = 0
            if not content_type.startswith("image/"):
                fail("Wallhaven download did not return an image")
            if content_length > MAX_DOWNLOAD_BYTES:
                fail("Wallpaper is larger than the 50 MB download limit")
            with tempfile.NamedTemporaryFile(prefix=".wallhaven-", suffix=extension, dir=target_dir, delete=False) as temp:
                temporary_name = temp.name
                copied = 0
                while True:
                    chunk = response.read(256 * 1024)
                    if not chunk:
                        break
                    copied += len(chunk)
                    if copied > MAX_DOWNLOAD_BYTES:
                        fail("Wallpaper exceeded the 50 MB download limit")
                    temp.write(chunk)
        os.replace(temporary_name, target)
    except urllib.error.HTTPError as exc:
        fail(f"Wallpaper download failed ({exc.code})")
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        fail(f"Wallpaper download failed: {exc}")
    finally:
        if temporary_name and os.path.exists(temporary_name):
            os.unlink(temporary_name)
    emit({"ok": True, "path": str(target), "cached": False})


def apply_wallpaper(raw_path: str) -> None:
    path = Path(raw_path).expanduser().resolve(strict=True)
    if not path.is_file() or path.suffix.lower() not in IMAGE_EXTENSIONS:
        fail("Wallpaper file is missing or unsupported")

    command = None
    if shutil.which("awww"):
        command = ["awww", "img", "--transition-type", "grow", "--transition-duration", "1.2", str(path)]
    elif shutil.which("swww"):
        command = ["swww", "img", str(path), "--transition-type", "grow", "--transition-duration", "1.2"]
    elif shutil.which("waypaper"):
        command = ["waypaper", "--wallpaper", str(path)]
    if command is None:
        fail("No supported wallpaper backend found (awww, swww or waypaper)")
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=20, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        fail(f"Wallpaper backend failed: {exc}")
    if completed.returncode != 0:
        details = (completed.stderr or completed.stdout).strip()
        fail(details or f"Wallpaper backend exited with {completed.returncode}")
    emit({"ok": True, "path": str(path), "backend": command[0]})


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    local = subparsers.add_parser("local")
    local.add_argument("--dir", required=True)
    search = subparsers.add_parser("search")
    search.add_argument("--query", default="")
    search.add_argument("--page", type=int, default=1)
    search.add_argument("--sorting", default="relevance")
    search.add_argument("--atleast", default="1920x1080")
    download = subparsers.add_parser("download")
    download.add_argument("--url", required=True)
    download.add_argument("--id", required=True)
    download.add_argument("--dir", required=True)
    apply_command = subparsers.add_parser("apply")
    apply_command.add_argument("--path", required=True)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if args.command == "local":
        local_wallpapers(args.dir)
    elif args.command == "search":
        wallhaven_search(args.query, args.page, args.sorting, args.atleast)
    elif args.command == "download":
        download_wallpaper(args.url, args.id, args.dir)
    elif args.command == "apply":
        apply_wallpaper(args.path)


if __name__ == "__main__":
    main()
