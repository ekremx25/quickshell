#!/usr/bin/env python3
"""Sites that bypass the VPN (Settings → Network → VPN).

How the bypass works: the physical connection (e.g. br0) carries a /32 route
for every IPv4 address of a bypassed site, pointing at the home gateway.
WireGuard's `suppress_prefixlength 0` rule lets these specific routes win over
the VPN's default route, so those addresses are reached directly. The home
network has no IPv6, so each site's IPv6 addresses get an `unreachable`
route; browsers then fall back to IPv4 at once instead of using the VPN.

Sites are kept by domain in quickshell/vpn_bypass.json and resolved to
addresses here. Addresses that were bypassed before this file existed are kept
as "legacy" and never touched unless the user removes them. Routes that are
not bypass routes are left alone. Changes are applied with `nmcli device
reapply`, which does not interrupt the connection.

Every command prints one JSON object.
"""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import time

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "quickshell/vpn_bypass.json"
DOMAIN = re.compile(r"^(?=.{1,253}$)(?!-)([a-z0-9-]{1,63}(?<!-)\.)+[a-z]{2,63}$")
MAX_SITES = 200
MAX_ADDRESSES = 32


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def fail(message: str) -> None:
    emit({"ok": False, "error": message})
    raise SystemExit(1)


def nmcli(*args: str, check: bool = True) -> str:
    try:
        result = subprocess.run(["nmcli", *args], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as exc:
        fail(f"nmcli failed: {exc}")
    if check and result.returncode != 0:
        fail((result.stderr or result.stdout).strip().replace("Error: ", "") or "nmcli failed")
    return result.stdout


# ── state ────────────────────────────────────────────────────────────────

def load_state() -> dict:
    try:
        data = json.loads(CONFIG.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {"version": 1, "sites": {}, "legacy": None}
    except (OSError, json.JSONDecodeError):
        fail(f"{CONFIG.name} is damaged; fix or delete it.")
    if not isinstance(data, dict) or not isinstance(data.get("sites", {}), dict):
        fail(f"{CONFIG.name} has an unexpected format.")
    data.setdefault("sites", {})
    data.setdefault("legacy", None)
    return data


def save_state(state: dict) -> None:
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{CONFIG.name}.", dir=CONFIG.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(state, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.replace(tmp, CONFIG)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


# ── network ──────────────────────────────────────────────────────────────

def physical_link() -> dict:
    """The connection that holds the non-VPN default route."""
    out = subprocess.run(["ip", "-j", "route", "show", "default", "table", "main"],
                         capture_output=True, text=True, timeout=10).stdout
    try:
        routes = [r for r in json.loads(out or "[]") if r.get("gateway")]
    except json.JSONDecodeError:
        routes = []
    if not routes:
        fail("No home network connection with a gateway was found.")
    route = sorted(routes, key=lambda r: r.get("metric", 0))[0]
    device = route["dev"]
    connection = nmcli("-g", "GENERAL.CONNECTION", "device", "show", device).strip()
    if not connection:
        fail(f"{device} is not managed by NetworkManager.")
    return {"device": device, "connection": connection, "gateway": route["gateway"]}


def vpn_active() -> bool:
    out = nmcli("-t", "-f", "TYPE,STATE", "connection", "show", "--active", check=False)
    return any(line.split(":")[0] in ("vpn", "wireguard") and line.endswith(":activated")
               for line in out.splitlines())


def split_routes(raw: str) -> list[str]:
    # nmcli -g prints routes separated by ", " and escapes ":" inside IPv6.
    return [r.strip().replace("\\:", ":") for r in raw.split(",") if r.strip()]


def read_routes(link: dict) -> tuple[list[str], list[str]]:
    v4 = split_routes(nmcli("-g", "ipv4.routes", "connection", "show", link["connection"]))
    v6 = split_routes(nmcli("-g", "ipv6.routes", "connection", "show", link["connection"]))
    return v4, v6


def bypass_ip(route: str, gateway: str) -> str | None:
    """IPv4 address if `route` is a bypass route ("A.B.C.D/32 gateway")."""
    parts = route.split()
    if len(parts) == 2 and parts[0].endswith("/32") and parts[1] == gateway:
        return parts[0][:-3]
    return None


def block_ip(route: str) -> str | None:
    """IPv6 address if `route` is a bypass block route ("X/128 type=unreachable")."""
    parts = route.split()
    if len(parts) == 2 and parts[0].endswith("/128") and parts[1] == "type=unreachable":
        return parts[0][:-4]
    return None


def resolve(domain: str) -> tuple[list[str], list[str]]:
    v4: set[str] = set()
    v6: set[str] = set()
    names = [domain] if domain.startswith("www.") else [domain, f"www.{domain}"]
    for name in names:
        try:
            infos = socket.getaddrinfo(name, 443, proto=socket.IPPROTO_TCP)
        except (socket.gaierror, UnicodeError):
            continue
        for family, _, _, _, sockaddr in infos:
            address = ipaddress.ip_address(sockaddr[0])
            if not address.is_global:
                continue
            (v4 if family == socket.AF_INET else v6).add(str(address))
    return sorted(v4)[:MAX_ADDRESSES], sorted(v6)[:MAX_ADDRESSES]


def normalize_domain(raw: str) -> str:
    text = raw.strip().lower()
    text = re.sub(r"^[a-z][a-z0-9+.-]*://", "", text)
    text = text.split("/")[0].split("?")[0].split("#")[0].split("@")[-1]
    text = text.rsplit(":", 1)[0] if text.count(":") == 1 else text
    text = text.strip(".")
    # "www.example.com" and "example.com" are one entry; resolve() covers both.
    if text.startswith("www.") and text.count(".") >= 2:
        text = text[4:]
    try:
        text = text.encode("idna").decode("ascii")
    except UnicodeError:
        fail("That is not a valid site address.")
    if not DOMAIN.match(text):
        fail("Enter a site address like example.com.")
    return text


# ── sync ─────────────────────────────────────────────────────────────────

def apply(state: dict, link: dict) -> bool:
    """Make the connection's routes match the state. Returns True if changed."""
    v4_routes, v6_routes = read_routes(link)
    gateway = link["gateway"]
    if state.get("legacy") is None:
        # First run: whatever bypass routes exist now were made before this tool.
        state["legacy"] = sorted({ip for r in v4_routes if (ip := bypass_ip(r, gateway))})
    wanted_v4 = set(state["legacy"])
    wanted_v6: set[str] = set()
    for site in state["sites"].values():
        wanted_v4.update(site.get("ipv4", []))
        wanted_v6.update(site.get("ipv6", []))

    other_v4 = [r for r in v4_routes if bypass_ip(r, gateway) is None]
    other_v6 = [r for r in v6_routes if block_ip(r) is None]
    new_v4 = other_v4 + [f"{ip}/32 {gateway}" for ip in sorted(wanted_v4, key=ipaddress.ip_address)]
    new_v6 = other_v6 + [f"{ip}/128 type=unreachable" for ip in sorted(wanted_v6, key=ipaddress.ip_address)]
    # Compare as sets: the same routes in another order need no change.
    if set(new_v4) == set(v4_routes) and set(new_v6) == set(v6_routes):
        return False
    nmcli("connection", "modify", link["connection"],
          "ipv4.routes", ", ".join(new_v4), "ipv6.routes", ", ".join(new_v6))
    if nmcli("-g", "GENERAL.STATE", "device", "show", link["device"], check=False).startswith("100"):
        nmcli("device", "reapply", link["device"])
        # reapply installs routes asynchronously; wait so the report that
        # follows shows the real state instead of "not applied".
        probe = next(iter(wanted_v4 - {bypass_ip(r, gateway) for r in v4_routes}), None)
        for _ in range(30):
            if probe is None or route_device(probe) == link["device"]:
                break
            time.sleep(0.1)
    return True


def route_device(ip: str) -> str:
    out = subprocess.run(["ip", "-j", "route", "get", ip], capture_output=True, text=True, timeout=5).stdout
    try:
        return json.loads(out)[0].get("dev", "")
    except (json.JSONDecodeError, IndexError):
        return ""


def report(state: dict, link: dict, **extra) -> None:
    sites = []
    for domain, site in sorted(state["sites"].items()):
        v4 = site.get("ipv4", [])
        sites.append({
            "domain": domain,
            "ipv4": v4,
            "ipv6": site.get("ipv6", []),
            "updated": site.get("updated", 0),
            # Checks the live routing table, so it reflects what really happens.
            "direct": bool(v4) and all(route_device(ip) == link["device"] for ip in v4[:3]),
        })
    emit({"ok": True, "connection": link["connection"], "device": link["device"],
          "gateway": link["gateway"], "vpnActive": vpn_active(), "sites": sites,
          "legacy": state.get("legacy") or [], **extra})


# ── commands ─────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    add = sub.add_parser("add")
    add.add_argument("--domain", required=True)
    remove = sub.add_parser("remove")
    remove.add_argument("--domain", required=True)
    remove_ip = sub.add_parser("remove-ip")
    remove_ip.add_argument("--ip", required=True)
    sub.add_parser("refresh")
    args = parser.parse_args()

    link = physical_link()
    state = load_state()

    if args.command == "status":
        if state.get("legacy") is None:
            apply(state, link)  # records legacy routes without changing them
            save_state(state)
        report(state, link)
        return

    if args.command == "add":
        domain = normalize_domain(args.domain)
        if domain not in state["sites"] and len(state["sites"]) >= MAX_SITES:
            fail(f"You can add up to {MAX_SITES} sites.")
        v4, v6 = resolve(domain)
        if not v4:
            fail(f"{domain} could not be found. Check the address and your connection.")
        state["sites"][domain] = {"ipv4": v4, "ipv6": v6, "updated": int(time.time())}
        apply(state, link)
        save_state(state)
        report(state, link, changed=domain)
        return

    if args.command == "remove":
        domain = normalize_domain(args.domain)
        # Older entries may carry a "www." prefix.
        key = next((k for k in (domain, f"www.{domain}", args.domain.strip().lower()) if k in state["sites"]), None)
        if key is None:
            fail(f"{domain} is not in the list.")
        state["sites"].pop(key)
        apply(state, link)
        save_state(state)
        report(state, link, changed=domain)
        return

    if args.command == "remove-ip":
        try:
            ip = str(ipaddress.IPv4Address(args.ip.strip()))
        except ValueError:
            fail("That is not an IPv4 address.")
        apply(state, link)  # make sure legacy is recorded first
        legacy = list(state.get("legacy") or [])
        if ip not in legacy:
            fail(f"{ip} is not in the list of earlier addresses.")
        state["legacy"] = [x for x in legacy if x != ip]
        apply(state, link)
        save_state(state)
        report(state, link, changed=ip)
        return

    if args.command == "refresh":
        failed = []
        for domain, site in state["sites"].items():
            v4, v6 = resolve(domain)
            if v4:
                site.update({"ipv4": v4, "ipv6": v6, "updated": int(time.time())})
            else:
                failed.append(domain)  # keep the old addresses rather than drop the site
        changed = apply(state, link)
        save_state(state)
        report(state, link, refreshed=True, routesChanged=changed, unresolved=failed)


if __name__ == "__main__":
    main()
