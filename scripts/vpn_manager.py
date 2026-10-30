#!/usr/bin/env python3
"""Inspect and import VPN profiles for Settings → Network.

Uses NetworkManager's own importers through libnm, so WireGuard .conf and
OpenVPN .ovpn files are read exactly as `nmcli connection import` would read
them, but:

* the profile is added with autoconnect blocked, so importing never switches
  the user's traffic to the VPN by itself (nmcli import activates it at once);
* the name, autoconnect choice and OpenVPN credentials are set before the
  profile is saved, and no key or password ever appears on a command line;
* the user's file is never copied to a shared location.

Every command prints one JSON object: {"ok": true, ...} or
{"ok": false, "error": "..."}. The OpenVPN password, when given, is read from
standard input.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

MAX_FILE_BYTES = 512 * 1024
WG_IFNAME = re.compile(r"^[A-Za-z0-9_=+.-]{1,15}$")


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def fail(message: str) -> None:
    emit({"ok": False, "error": message})
    raise SystemExit(1)


def load_nm():
    try:
        import gi
        gi.require_version("NM", "1.0")
        from gi.repository import GLib, NM
    except (ImportError, ValueError):
        fail("NetworkManager's Python bindings (libnm, python-gobject) are not installed.")
    return GLib, NM


def check_file(raw: str) -> Path:
    path = Path(raw).expanduser()
    try:
        path = path.resolve(strict=True)
    except OSError:
        fail("The selected file does not exist.")
    if not path.is_file():
        fail("The selected path is not a file.")
    if path.stat().st_size > MAX_FILE_BYTES:
        fail("The file is too large to be a VPN configuration.")
    try:
        path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        fail("The file cannot be read as text.")
    return path


def detect_type(path: Path, requested: str) -> str:
    if requested in ("openvpn", "wireguard"):
        return requested
    text = path.read_text(encoding="utf-8")
    if re.search(r"^\s*\[Interface\]", text, re.M | re.I):
        return "wireguard"
    if re.search(r"^\s*remote\s+\S+", text, re.M):
        return "openvpn"
    fail("This does not look like a WireGuard (.conf) or OpenVPN (.ovpn) file.")
    return ""


def wireguard_ifname(stem: str, taken: set[str]) -> str:
    base = re.sub(r"[^A-Za-z0-9_=+.-]", "-", stem).strip("-.") or "wg"
    base = base[:15].rstrip("-.") or "wg"
    candidate, counter = base, 2
    while candidate in taken or not WG_IFNAME.match(candidate):
        suffix = f"-{counter}"
        candidate = base[: 15 - len(suffix)] + suffix
        counter += 1
    return candidate


def taken_ifnames(NM, client) -> set[str]:
    names = {conn.get_interface_name() for conn in client.get_connections() if conn.get_interface_name()}
    try:
        names.update(os.listdir("/sys/class/net"))
    except OSError:
        pass
    return names


def unique_name(NM, client, wanted: str) -> str:
    existing = {conn.get_id() for conn in client.get_connections()}
    name, counter = wanted, 2
    while name in existing:
        name = f"{wanted} ({counter})"
        counter += 1
    return name


def import_connection(NM, client, path: Path, vpn_type: str):
    """Return an NMConnection built by NetworkManager's importer, not yet added."""
    if vpn_type == "wireguard":
        # The importer names the interface after the file, so give it a valid,
        # unused name in a private (0700) directory that is removed afterwards.
        ifname = wireguard_ifname(path.stem, taken_ifnames(NM, client))
        runtime = os.environ.get("XDG_RUNTIME_DIR") or None
        workdir = tempfile.mkdtemp(prefix="qs-vpn-", dir=runtime)
        try:
            staged = Path(workdir) / f"{ifname}.conf"
            shutil.copyfile(path, staged)
            os.chmod(staged, 0o600)
            try:
                return NM.conn_wireguard_import(str(staged))
            except Exception as exc:  # GLib.Error
                # Point at the line, not at the private staging copy.
                detail = re.sub(r"\s+at\s+\S+:(\d+)$", r" (line \1)", str(getattr(exc, "message", exc)))
                fail(f"WireGuard file is not valid: {detail}")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    plugin = next((info for info in NM.VpnPluginInfo.list_load() if info.get_name() == "openvpn"), None)
    if plugin is None:
        fail("OpenVPN support for NetworkManager is not installed (package networkmanager-openvpn).")
    try:
        editor = plugin.load_editor_plugin()
        return editor.import_(str(path))
    except Exception as exc:  # GLib.Error
        fail(f"OpenVPN file is not valid: {getattr(exc, 'message', exc)}")
    return None


def describe(NM, connection, vpn_type: str, path: Path) -> dict:
    info = {"type": vpn_type, "suggestedName": path.stem, "server": "", "fullTunnel": False,
            "needsCredentials": False}
    if vpn_type == "wireguard":
        setting = connection.get_setting_by_name(NM.SETTING_WIREGUARD_SETTING_NAME)
        for index in range(setting.get_peers_len() if setting else 0):
            peer = setting.get_peer(index)
            if not info["server"] and peer.get_endpoint():
                info["server"] = peer.get_endpoint()
            allowed = [peer.get_allowed_ip(i, None) for i in range(peer.get_allowed_ips_len())]
            if any(ip in ("0.0.0.0/0", "::/0") for ip in allowed):
                info["fullTunnel"] = True
    else:
        vpn = connection.get_setting_vpn()
        remote = vpn.get_data_item("remote") if vpn else ""
        info["server"] = (remote or "").split(",")[0].strip()
        kind = vpn.get_data_item("connection-type") if vpn else ""
        info["needsCredentials"] = kind in ("password", "password-tls")
        ipv4 = connection.get_setting_ip4_config()
        info["fullTunnel"] = not (ipv4 and ipv4.get_never_default())
    return info


def run_add(GLib, NM, client, connection) -> str:
    loop = GLib.MainLoop()
    outcome: dict = {}

    def done(source, result, _data=None):
        try:
            remote, _ = source.add_connection2_finish(result)
            outcome["uuid"] = remote.get_uuid()
        except Exception as exc:  # GLib.Error
            outcome["error"] = getattr(exc, "message", str(exc))
        loop.quit()

    flags = NM.SettingsAddConnection2Flags.TO_DISK | NM.SettingsAddConnection2Flags.BLOCK_AUTOCONNECT
    client.add_connection2(connection.to_dbus(NM.ConnectionSerializationFlags.ALL), flags, None, False,
                           None, done, None)
    GLib.timeout_add_seconds(20, lambda: (outcome.setdefault("error", "NetworkManager did not answer in time."),
                                          loop.quit(), False)[2])
    loop.run()
    if "error" in outcome:
        fail(f"NetworkManager refused the profile: {outcome['error']}")
    return outcome["uuid"]


def cmd_inspect(args) -> None:
    GLib, NM = load_nm()
    path = check_file(args.file)
    vpn_type = detect_type(path, args.type)
    client = NM.Client.new(None)
    connection = import_connection(NM, client, path, vpn_type)
    emit({"ok": True, **describe(NM, connection, vpn_type, path)})


def cmd_import(args) -> None:
    GLib, NM = load_nm()
    path = check_file(args.file)
    vpn_type = detect_type(path, args.type)
    client = NM.Client.new(None)
    if not client.get_nm_running():
        fail("NetworkManager is not running.")
    connection = import_connection(NM, client, path, vpn_type)
    info = describe(NM, connection, vpn_type, path)

    wanted = " ".join(args.name.split())[:64] or path.stem
    name = unique_name(NM, client, wanted)
    base = connection.get_setting_connection()
    base.set_property(NM.SETTING_CONNECTION_ID, name)
    base.set_property(NM.SETTING_CONNECTION_UUID, NM.utils_uuid_generate())
    base.set_property(NM.SETTING_CONNECTION_AUTOCONNECT, args.autoconnect == "yes")

    if vpn_type == "openvpn":
        vpn = connection.get_setting_vpn()
        username = args.username.strip()
        password = sys.stdin.read() if args.password_stdin else ""
        password = password.rstrip("\n")
        if info["needsCredentials"] and not username:
            fail("This OpenVPN server needs a username.")
        if username:
            vpn.add_data_item("username", username)
        if password:
            vpn.add_secret("password", password)
            # Stored by NetworkManager for the system, so connecting needs no prompt.
            vpn.add_data_item("password-flags", "0")

    try:
        connection.normalize()
    except Exception as exc:  # GLib.Error
        fail(f"The profile is incomplete: {getattr(exc, 'message', exc)}")
    uuid = run_add(GLib, NM, client, connection)
    emit({"ok": True, "uuid": uuid, "name": name, "type": vpn_type})


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    inspect = sub.add_parser("inspect")
    inspect.add_argument("--file", required=True)
    inspect.add_argument("--type", default="auto", choices=("auto", "openvpn", "wireguard"))
    imp = sub.add_parser("import")
    imp.add_argument("--file", required=True)
    imp.add_argument("--type", default="auto", choices=("auto", "openvpn", "wireguard"))
    imp.add_argument("--name", default="")
    imp.add_argument("--autoconnect", default="no", choices=("yes", "no"))
    imp.add_argument("--username", default="")
    imp.add_argument("--password-stdin", action="store_true")
    args = parser.parse_args()
    if args.command == "inspect":
        cmd_inspect(args)
    else:
        cmd_import(args)


if __name__ == "__main__":
    main()
