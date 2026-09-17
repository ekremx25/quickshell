#!/usr/bin/env python3
"""Portable power-profile helper for Arch Linux and Fedora.

Arch normally supplies ``powerprofilesctl`` with power-profiles-daemon.
Fedora can expose the same API through tuned-ppd without installing that CLI.
The helper prefers the CLI and falls back to the standard D-Bus interface.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys


VALID_PROFILES = ("performance", "balanced", "power-saver")
BUS_NAME = "net.hadess.PowerProfiles"
OBJECT_PATH = "/net/hadess/PowerProfiles"
INTERFACE = "net.hadess.PowerProfiles"
PROPERTIES = "org.freedesktop.DBus.Properties"


class BackendError(RuntimeError):
    pass


def run_cli(*arguments: str) -> str:
    executable = shutil.which("powerprofilesctl")
    if not executable:
        raise BackendError("powerprofilesctl is not installed")

    result = subprocess.run(
        [executable, *arguments],
        check=False,
        capture_output=True,
        text=True,
        timeout=15,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "powerprofilesctl failed"
        raise BackendError(message)
    return result.stdout.strip()


def cli_status() -> dict[str, object]:
    active = run_cli("get")
    listing = run_cli("list")
    profiles = [
        match.group(1)
        for line in listing.splitlines()
        if (match := re.match(r"^\s*\*?\s*(performance|balanced|power-saver):", line))
    ]
    return {"active": active, "profiles": profiles or list(VALID_PROFILES), "backend": "powerprofilesctl"}


def dbus_connection():
    try:
        from gi.repository import Gio, GLib
    except ImportError as error:
        raise BackendError("Neither powerprofilesctl nor Python GObject is available") from error
    return Gio, GLib, Gio.bus_get_sync(Gio.BusType.SYSTEM, None)


def dbus_get(bus, Gio, GLib, property_name: str):
    result = bus.call_sync(
        BUS_NAME,
        OBJECT_PATH,
        PROPERTIES,
        "Get",
        GLib.Variant("(ss)", (INTERFACE, property_name)),
        None,
        Gio.DBusCallFlags.NONE,
        5000,
        None,
    )
    return result.unpack()[0]


def dbus_status() -> dict[str, object]:
    Gio, GLib, bus = dbus_connection()
    active = dbus_get(bus, Gio, GLib, "ActiveProfile")
    raw_profiles = dbus_get(bus, Gio, GLib, "Profiles")
    profiles = [
        entry.get("Profile")
        for entry in raw_profiles
        if entry.get("Profile") in VALID_PROFILES
    ]
    return {"active": active, "profiles": profiles or list(VALID_PROFILES), "backend": "dbus"}


def status() -> dict[str, object]:
    errors: list[str] = []
    for getter in (cli_status, dbus_status):
        try:
            result = getter()
            if result["active"] not in VALID_PROFILES:
                raise BackendError("Power-profile service returned an unknown profile")
            return result
        except Exception as error:  # Try the other compatible backend.
            errors.append(str(error))
    raise BackendError("; ".join(errors))


def set_with_dbus(profile: str) -> None:
    Gio, GLib, bus = dbus_connection()
    bus.call_sync(
        BUS_NAME,
        OBJECT_PATH,
        PROPERTIES,
        "Set",
        GLib.Variant("(ssv)", (INTERFACE, "ActiveProfile", GLib.Variant("s", profile))),
        None,
        Gio.DBusCallFlags.ALLOW_INTERACTIVE_AUTHORIZATION,
        30000,
        None,
    )


def set_profile(profile: str) -> None:
    if profile not in VALID_PROFILES:
        raise BackendError(f"Unsupported profile: {profile}")

    errors: list[str] = []
    try:
        run_cli("set", profile)
        return
    except Exception as error:
        errors.append(str(error))

    try:
        set_with_dbus(profile)
    except Exception as error:
        errors.append(str(error))
        raise BackendError("; ".join(errors)) from error


def main() -> int:
    try:
        if sys.argv[1:] == ["status"]:
            print(json.dumps(status(), separators=(",", ":")))
        elif sys.argv[1:] == ["get"]:
            print(status()["active"])
        elif len(sys.argv) == 3 and sys.argv[1] == "set":
            set_profile(sys.argv[2])
        else:
            raise BackendError(
                "Usage: power-profile.py status | get | set {balanced,performance,power-saver}"
            )
    except Exception as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
