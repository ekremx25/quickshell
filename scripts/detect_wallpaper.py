#!/usr/bin/env python3
"""Find the image actually displayed by awww/swww, then fall back to Waypaper."""
import configparser
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def image_path(value):
    value = os.path.expanduser(value.strip().strip('\"').strip("'"))
    return value if value and Path(value).is_file() else ""


def query_images(output):
    images = []
    for line in output.splitlines():
        match = re.search(r"(?:currently displaying:\s*)?image:\s*(.+)$", line)
        if match:
            path = image_path(match.group(1))
            if path and path not in images:
                images.append(path)
    return images


def waypaper_image():
    config = configparser.ConfigParser(interpolation=None)
    location = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "waypaper/config.ini"
    try:
        config.read(location)
        for section in config.sections():
            path = image_path(config[section].get("wallpaper", ""))
            if path:
                return path
    except (OSError, configparser.Error):
        pass
    return ""


def detect():
    configured = waypaper_image()
    for backend in ("awww", "swww"):
        if not shutil.which(backend):
            continue
        try:
            result = subprocess.run([backend, "query"], capture_output=True, text=True, timeout=1.5)
            images = query_images(result.stdout) if result.returncode == 0 else []
            if images:
                # Waypaper's last selection disambiguates multi-output queries.
                return backend, configured if configured in images else images[0]
        except (OSError, subprocess.TimeoutExpired):
            pass
    # Read argv directly: shell-style splitting breaks paths containing spaces.
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if (entry / "comm").read_text().strip() != "swaybg":
                continue
            args = (entry / "cmdline").read_bytes().decode().split("\0")
            for i, value in enumerate(args[:-1]):
                if value in ("-i", "--image"):
                    path = image_path(args[i + 1])
                    if path:
                        return "swaybg", path
        except (OSError, UnicodeError):
            continue
    return ("waypaper", configured) if configured else ("unknown", "")


if __name__ == "__main__":
    backend, path = detect()
    print((backend + "\t" if "--with-backend" in sys.argv else "") + path)
    raise SystemExit(0 if path else 1)
