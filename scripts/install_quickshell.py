#!/usr/bin/env python3
"""Interactive configuration installer; preserves display settings and offers opt-in Lua autostart."""
from __future__ import annotations

import argparse
import collections
import datetime
import fcntl
import json
import math
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import uuid

sys.dont_write_bytecode = True
from monitor_role_manager import atomic_json_write, monitor_identity

PAYLOAD = ("shell.qml", "Modules", "Services", "Widgets", "Components", "assets", "scripts", "eq", "presets", "LICENSE", "README.md", "install.sh")
COMPONENTS = {"bar": "all", "dock": "1", "workspaces": "all", "notifications": "all", "weather": "none", "worldclock": "none", "markets": "none", "toast": "all", "osd": "1"}
PACKAGES = ("quickshell", "networkmanager", "bluez", "bluez-utils", "pipewire", "pipewire-pulse", "wireplumber", "libpulse", "jq", "python", "socat", "inotify-tools", "util-linux", "glib2", "fontconfig", "ttf-jetbrains-mono-nerd", "ttf-inter", "ttf-font-awesome")
EXCLUDED = {"__pycache__", "profile_avatar.jpg", "custom.json", "parametric-eq.txt", "api_keys.json"}


def read_object(path):
    if not path.exists():
        return {}
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def detect_monitors(fixture=None):
    if fixture:
        raw = Path(fixture).read_text(encoding="utf-8")
    else:
        result = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, check=True, timeout=10)
        raw = result.stdout
    monitors = json.loads(raw)
    if not isinstance(monitors, list):
        raise ValueError("Monitor data must be a JSON array.")
    active, names = [], set()
    for monitor in monitors:
        if not isinstance(monitor, dict):
            raise ValueError("Invalid monitor record.")
        if monitor.get("disabled"):
            continue
        name = monitor.get("name")
        if not isinstance(name, str) or not name or any(c.isspace() or c in ',;/\\' for c in name) or name in names:
            raise ValueError("Missing, duplicate or invalid monitor connector name.")
        for key in ("width", "height", "refreshRate", "scale", "x", "y"):
            value = monitor.get(key)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
                raise ValueError(f"{name}: invalid {key}")
            if key not in ("x", "y") and value <= 0:
                raise ValueError(f"{name}: {key} must be positive")
        for key in ("width", "height", "x", "y"):
            if int(monitor[key]) != monitor[key]:
                raise ValueError(f"{name}: {key} must be an integer")
        names.add(name)
        active.append(monitor)
    if not active:
        raise ValueError("No active monitors. Run inside Hyprland or use --monitors-json FILE.")
    return sorted(active, key=lambda item: (item["x"], item["y"], item["name"]))


def ask(prompt, default=""):
    try:
        answer = input(f"{prompt}" + (f" [{default}]" if default else "") + ": ").strip()
    except EOFError as error:
        raise ValueError("Input ended; installation cancelled without changing the destination.") from error
    return answer or default


def confirm(prompt, default="n"):
    while True:
        answer = ask(prompt + " (y/n)", default).lower()
        if answer in ("y", "yes", "e", "evet"):
            return True
        if answer in ("n", "no", "h", "hayir"):
            return False
        print("Please answer y or n.")


def choose_monitors(monitors):
    remaining = list(monitors)
    ordered = []
    while remaining:
        role = ("Main", "Secondary", "Third")[len(ordered)] if len(ordered) < 3 else f"Display {len(ordered) + 1}"
        if len(remaining) == 1:
            ordered.append(remaining.pop())
            break
        print("\n" + ", ".join(f"{index + 1}={item['name']}" for index, item in enumerate(remaining)))
        answer = ask(f"Select {role} monitor number", "1")
        if answer.isdigit() and 1 <= int(answer) <= len(remaining):
            ordered.append(remaining.pop(int(answer) - 1))
        else:
            print("Choose a number from the list.")
    return ordered


def choose_screens(monitors):
    print("\nScreen selections: all, none, or comma-separated monitor numbers.")
    print(", ".join(f"{i + 1}={item['name']}" for i, item in enumerate(monitors)))
    preferences = {}
    for component, default in COMPONENTS.items():
        while True:
            answer = ask(f"Screens for {component}", default).lower()
            if answer in ("all", "none"):
                preferences[component] = [answer]
                break
            parts = [part.strip() for part in answer.split(",")]
            if parts and all(part.isdigit() and 1 <= int(part) <= len(monitors) for part in parts):
                indices = sorted({int(part) - 1 for part in parts})
                preferences[component] = [("primary", "secondary", "tertiary")[i] if i < 3 else monitors[i]["name"] for i in indices]
                break
            print("Invalid selection; use all, none or listed numbers.")
    return preferences


def monitor_files(monitors):
    config, roles, identities = {}, {}, {}
    counts = collections.Counter(monitor_identity(item) for item in monitors)
    for index, item in enumerate(monitors):
        role = ("primary", "secondary", "tertiary")[index] if index < 3 else f"display-{index + 1}"
        identity = monitor_identity(item)
        roles[role] = item["name"]
        if identity and counts[identity] == 1:
            identities[identity] = role
        config[item["name"]] = {
            "role": role, "default": index == 0, "res": f"{int(item['width'])}x{int(item['height'])}",
            "hz": str(item["refreshRate"]), "scale": str(item["scale"]), "autoScale": False,
            "posX": str(int(item["x"])), "posY": str(int(item["y"])),
            "transform": item.get("transform", 0), "identity": identity,
        }
    return {
        "monitor_config.json": config, "monitor_runtime.json": roles,
        "monitor_identities.json": identities, "monitor_role_profiles.json": {},
        # Existing startup/hotplug hooks only observe this install's monitors.
        "monitor_setup.json": {"manageDisplays": False},
    }


def reject_symlinks(path):
    if path.is_symlink() or (path.is_dir() and any(item.is_symlink() for item in path.rglob("*"))):
        raise ValueError(f"Symlinks are not supported during installation: {path}")


def validate_paths(source, target):
    reject_symlinks(target)
    if target.exists() and not target.is_dir():
        raise ValueError("Destination is not a directory.")
    src, dst = source.resolve(), target.resolve()
    if src == dst or src in dst.parents or dst in src.parents:
        raise ValueError("Source and destination must be separate, non-nested directories. Clone outside the live config.")
    if not (source / "shell.qml").is_file() or not (source / "Services").is_dir():
        raise ValueError("Source is not a Quickshell configuration checkout.")
    for name in PAYLOAD:
        reject_symlinks(source / name)


def check_running(target):
    if not shutil.which("quickshell"):
        return
    result = subprocess.run(["quickshell", "list", "--all"], capture_output=True, text=True, timeout=10, check=True)
    for line in result.stdout.splitlines():
        if "Config path:" in line:
            path = Path(line.split("Config path:", 1)[1].strip())
            if path.resolve() == (target / "shell.qml").resolve():
                raise ValueError("This destination is running. Stop it yourself before installing; it will not be stopped automatically.")


def install(source, target, generated):
    validate_paths(source, target)
    check_running(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    lock_path = target.parent / ".quickshell-install.lock"
    if lock_path.is_symlink():
        raise ValueError("Installer lock must not be a symlink.")
    with lock_path.open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        validate_paths(source, target)
        check_running(target)
        stage = Path(tempfile.mkdtemp(prefix=".quickshell-install-", dir=target.parent))
        backup = None
        try:
            if target.exists():
                shutil.copytree(target, stage, dirs_exist_ok=True)
            for name in PAYLOAD:
                src, dst = source / name, stage / name
                if not src.exists():
                    continue
                if src.is_dir():
                    shutil.copytree(src, dst, dirs_exist_ok=True, ignore=lambda directory, names: [name for name in names if name in EXCLUDED or name.startswith(".") or name.endswith((".pyc", ".log"))])
                else:
                    shutil.copy2(src, dst)
            existing_screens = read_object(stage / "screen_config.json")
            existing_screens.update(generated["screen_config.json"])
            for name, value in generated.items():
                atomic_json_write(stage / name, existing_screens if name == "screen_config.json" else value)
            if target.exists():
                stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
                backup = target.with_name(f"quickshell.backup-{stamp}-{uuid.uuid4().hex[:8]}")
                target.rename(backup)
            stage.rename(target)
            return backup
        except BaseException:
            if backup and backup.exists() and not target.exists():
                backup.rename(target)
            raise
        finally:
            if stage.exists():
                shutil.rmtree(stage)



def missing_packages():
    if not shutil.which("pacman"):
        return None
    missing = []
    for package in PACKAGES:
        result = subprocess.run(["pacman", "-Q", "--", package], capture_output=True, text=True, timeout=10)
        if result.returncode == 1:
            missing.append(package)
        elif result.returncode != 0:
            raise ValueError(f"Cannot query installed package: {package}")
    return missing


def install_packages(packages):
    if not packages:
        return
    command = ["pacman", "-S", "--needed", "--", *packages]
    if os.geteuid() != 0:
        command.insert(0, "sudo")
    subprocess.run(command, check=True)



LUA_AUTOSTART = '\n-- Quickshell installer: autostart\nhl.on("hyprland.start", function()\n    hl.exec_cmd("quickshell")\nend)\n'


def add_lua_autostart(config):
    if config.suffix != ".lua" or config.is_symlink() or not config.is_file():
        raise ValueError("Select an existing non-symlink hyprland.lua; legacy .conf files are not supported.")
    original = config.read_text(encoding="utf-8")
    if 'hl.exec_cmd("quickshell' in original or "hl.exec_cmd('quickshell" in original:
        print("A Quickshell Lua launch entry already exists; left unchanged.")
        return None
    backup = config.with_name(config.name + ".quickshell-backup-" + uuid.uuid4().hex)
    shutil.copy2(config, backup)
    fd, temporary = tempfile.mkstemp(prefix=".quickshell-autostart-", dir=config.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            os.fchmod(handle.fileno(), config.stat().st_mode & 0o777)
            handle.write(original + LUA_AUTOSTART)
        if config.read_text(encoding="utf-8") != original:
            raise ValueError("Hyprland config changed during setup; refusing to overwrite it.")
        os.replace(temporary, config)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return backup


def offer_lua_autostart(target):
    try:
        accepted = confirm("Add Quickshell autostart to your Hyprland Lua configuration?", "n")
    except ValueError:
        return 0  # EOF is not permission to modify the compositor configuration.
    if not accepted:
        return 0
    try:
        config = Path(ask("Existing Hyprland Lua config", str(target.parent / "hypr/hyprland.lua"))).expanduser()
        backup = add_lua_autostart(config)
        if backup:
            print(f"Lua autostart added for the next Hyprland startup. Backup: {backup}")
        return 0
    except (OSError, ValueError) as error:
        print(f"Quickshell installed, but Lua autostart was not added: {error}", file=sys.stderr)
        return 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Show the plan without changing destination files")
    parser.add_argument("--monitors-json", type=Path, help="Read a hyprctl monitors -j snapshot instead of querying Hyprland")
    args = parser.parse_args(argv)
    source = Path(__file__).resolve().parents[1]
    target = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "quickshell"
    try:
        validate_paths(source, target)
        monitors = detect_monitors(args.monitors_json)
        print("Quickshell configuration installer — no automatic display changes or service startup.")
        for item in monitors:
            print(f"  {item['name']}: {item['width']}x{item['height']} @ {item['refreshRate']} Hz, scale {item['scale']}, position {item['x']},{item['y']}")
        if not confirm(f"Detected {len(monitors)} active monitor(s). Is this correct?", "y"):
            print("Cancelled. Check connected outputs and rerun.")
            return 0
        monitors = choose_monitors(monitors)
        generated = monitor_files(monitors)
        generated["screen_config.json"] = choose_screens(monitors)
        print(f"\nDestination: {target}\nExisting installation: {'will be backed up' if target.exists() else 'none'}")
        print(json.dumps(generated, indent=2, ensure_ascii=False))
        missing = missing_packages()
        if missing is None:
            print("Automatic package installation supports pacman systems only. See README Dependencies for other distributions.")
        else:
            print("Missing packages: " + (", ".join(missing) or "none; installed packages will be skipped"))
        if args.dry_run:
            print("DRY RUN: no destination, backup, service or display changes. After a real install, optional Lua autostart is offered.")
            return 0
        if not confirm("Install this configuration?", "n"):
            print("Cancelled. Nothing changed.")
            return 0
        check_running(target)
        if missing and confirm("Install only the missing packages now?", "n"):
            install_packages(missing)
        backup = install(source, target, generated)
        print(f"Installed: {target}")
        if backup:
            print(f"Backup: {backup}")
        launch = ["env", f"XDG_CONFIG_HOME={target.parent}", "bash", str(target / "scripts/start-quickshell.sh")]
        print("Start manually after checking dependencies: " + shlex.join(launch))
        return offer_lua_autostart(target)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Installation aborted: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nCancelled.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
