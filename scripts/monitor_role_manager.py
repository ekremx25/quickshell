#!/usr/bin/env python3
"""Port-independent Hyprland monitor role manager.

Treats monitor_config.json entries as role profiles instead of permanent
connector identities. Connected outputs are matched by capabilities, assigned
primary/secondary/tertiary roles, auto-scaled from physical DPI and laid out
without overlap. Manufacturer/model/serial values are intentionally ignored.
"""

from __future__ import annotations

import argparse
import fcntl
import itertools
import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROLE_NAMES = ("primary", "secondary", "tertiary")
CLEAN_SCALES = (1.0, 1.2, 1.25, 4.0 / 3.0, 1.5, 1.6, 1.75, 2.0)
TARGET_LOGICAL_DPI = 120.0


def resolution_parts(value: str) -> tuple[int, int]:
    try:
        width, height = value.lower().split("x", 1)
        return int(width), int(height)
    except (AttributeError, TypeError, ValueError):
        return 0, 0


def mode_parts(value: str) -> tuple[str, float]:
    value = str(value or "")
    if "@" not in value:
        return value.replace("Hz", ""), 0.0
    resolution, rate = value.split("@", 1)
    try:
        return resolution, float(rate.replace("Hz", ""))
    except ValueError:
        return resolution, 0.0


def available_modes(output: dict) -> list[tuple[str, float]]:
    modes = []
    for raw in output.get("availableModes") or []:
        resolution, rate = mode_parts(raw)
        if resolution_parts(resolution) != (0, 0) and rate > 0:
            modes.append((resolution, rate))
    if not modes:
        width = int(output.get("width") or 0)
        height = int(output.get("height") or 0)
        rate = float(output.get("refreshRate") or 60.0)
        if width and height:
            modes.append((f"{width}x{height}", rate))
    return modes


def preferred_mode(output: dict, profile: dict) -> tuple[str, float]:
    modes = available_modes(output)
    if not modes:
        return "0x0", 60.0

    requested_resolution = str(profile.get("res") or "")
    same_resolution = [item for item in modes if item[0] == requested_resolution]
    candidates = same_resolution or modes
    if not same_resolution:
        max_area = max(resolution_parts(item[0])[0] * resolution_parts(item[0])[1] for item in candidates)
        candidates = [item for item in candidates if resolution_parts(item[0])[0] * resolution_parts(item[0])[1] == max_area]

    requested_rate = float(profile.get("hz") or 0)
    if same_resolution and requested_rate:
        return min(candidates, key=lambda item: abs(item[1] - requested_rate))
    return max(candidates, key=lambda item: item[1])


def physical_dpi(output: dict, resolution: str) -> float | None:
    width_px, height_px = resolution_parts(resolution)
    width_mm = float(output.get("physicalWidth") or 0)
    height_mm = float(output.get("physicalHeight") or 0)
    if width_px <= 0 or height_px <= 0 or width_mm < 100 or height_mm < 100:
        return None
    diagonal_px = math.hypot(width_px, height_px)
    diagonal_in = math.hypot(width_mm, height_mm) / 25.4
    return diagonal_px / diagonal_in if diagonal_in > 0 else None


def clean_scale_candidates(resolution: str) -> list[float]:
    width, height = resolution_parts(resolution)
    result = []
    for scale in CLEAN_SCALES:
        logical_width = width / scale
        logical_height = height / scale
        if abs(logical_width - round(logical_width)) < 0.01 and abs(logical_height - round(logical_height)) < 0.01:
            result.append(scale)
    return result or [1.0]


def automatic_scale(output: dict, resolution: str) -> float:
    dpi = physical_dpi(output, resolution)
    if dpi is None or dpi < 125:
        return 1.0
    desired = min(2.0, max(1.0, dpi / TARGET_LOGICAL_DPI))
    candidates = clean_scale_candidates(resolution)
    return min(candidates, key=lambda scale: (abs(scale - desired), scale))


def profile_order(config: dict) -> list[dict]:
    entries = []
    for connector, value in (config or {}).items():
        if not isinstance(value, dict) or not value.get("res"):
            continue
        item = dict(value)
        item["_oldConnector"] = connector
        entries.append(item)
    entries.sort(key=lambda item: (
        0 if item.get("default") or item.get("role") == "primary" else 1,
        int(float(item.get("posX") or 0)),
        int(float(item.get("posY") or 0)),
    ))
    for index, item in enumerate(entries):
        item["role"] = ROLE_NAMES[index] if index < len(ROLE_NAMES) else f"display-{index + 1}"
    return entries


def output_capability_area(output: dict) -> int:
    areas = [resolution_parts(mode[0])[0] * resolution_parts(mode[0])[1] for mode in available_modes(output)]
    return max(areas or [0])


def profile_match_score(profile: dict, output: dict) -> tuple:
    requested = resolution_parts(str(profile.get("res") or ""))
    requested_area = requested[0] * requested[1]
    modes = available_modes(output)
    supports_exact = any(resolution_parts(mode[0]) == requested for mode in modes)
    capability_area = output_capability_area(output)
    area_distance = abs(capability_area - requested_area) if requested_area else 0
    max_rate = max((mode[1] for mode in modes), default=0.0)
    return (0 if supports_exact else 1, area_distance, -max_rate, str(output.get("name") or ""))


def assign_roles(outputs: list[dict], profiles: list[dict]) -> list[tuple[dict, dict]]:
    remaining = list(outputs)
    assignments = []
    for profile in profiles:
        if not remaining:
            break
        selected = min(remaining, key=lambda output: profile_match_score(profile, output))
        assignments.append((selected, profile))
        remaining.remove(selected)

    remaining.sort(key=lambda output: (-output_capability_area(output), str(output.get("name") or "")))
    for output in remaining:
        index = len(assignments)
        role = ROLE_NAMES[index] if index < len(ROLE_NAMES) else f"display-{index + 1}"
        assignments.append((output, {"role": role, "autoScale": True}))
    return assignments


def normalize_eotf(value) -> str:
    if value in (0, "0"):
        return "default"
    if value in (1, "1", None):
        return "srgb"
    if value in (2, "2"):
        return "gamma22"
    return str(value)


def build_plan(outputs: list[dict], config: dict) -> list[dict]:
    profiles = profile_order(config)
    assignments = assign_roles(outputs, profiles)
    plan = []
    for output, profile in assignments:
        resolution, rate = preferred_mode(output, profile)
        auto_scale = bool(profile.get("autoScale", True))
        scale = automatic_scale(output, resolution) if auto_scale else float(profile.get("scale") or 1.0)
        plan.append({
            "name": output.get("name"),
            "role": profile.get("role"),
            "res": resolution,
            "hz": rate,
            "scale": scale,
            "autoScale": auto_scale,
            "hdr": bool(profile.get("hdr", False)),
            "bitdepth": int(profile.get("bitdepth") or (10 if profile.get("hdr") else 8)),
            "vrr": int(profile.get("vrr") or 0),
            "sdrLuminance": int(profile.get("sdrLuminance") or 80),
            "sdrBrightness": float(profile.get("sdrBrightness") or 1.0),
            "sdrSaturation": float(profile.get("sdrSaturation") or 1.0),
            "colorManagement": str(profile.get("colorManagement") or ("hdr" if profile.get("hdr") else "srgb")),
            "iccProfile": str(profile.get("iccProfile") or ""),
            "sdrEotf": profile.get("sdrEotf", 1),
            "_live": output,
        })

    logical_heights = [math.ceil(resolution_parts(item["res"])[1] / item["scale"]) for item in plan]
    max_height = max(logical_heights or [0])
    cursor_x = 0
    for index, item in enumerate(plan):
        width, height = resolution_parts(item["res"])
        logical_width = math.ceil(width / item["scale"])
        logical_height = math.ceil(height / item["scale"])
        item["posX"] = cursor_x
        item["posY"] = round((max_height - logical_height) / 2)
        item["default"] = index == 0
        cursor_x += logical_width
    return plan


def rect(item: dict) -> tuple[int, int, int, int]:
    width, height = resolution_parts(item["res"])
    return (
        int(item["posX"]), int(item["posY"]),
        int(item["posX"]) + math.ceil(width / float(item["scale"])),
        int(item["posY"]) + math.ceil(height / float(item["scale"])),
    )


def overlaps(first: tuple[int, int, int, int], second: tuple[int, int, int, int]) -> bool:
    return min(first[2], second[2]) > max(first[0], second[0]) and min(first[3], second[3]) > max(first[1], second[1])


def plan_has_overlap(plan: list[dict]) -> bool:
    rectangles = [rect(item) for item in plan]
    return any(overlaps(rectangles[i], rectangles[j]) for i in range(len(rectangles)) for j in range(i + 1, len(rectangles)))


def safe_apply_order(plan: list[dict]) -> list[dict]:
    current = {}
    for item in plan:
        live = item["_live"]
        current[item["name"]] = (
            int(live.get("x") or 0), int(live.get("y") or 0),
            int(live.get("x") or 0) + math.ceil(int(live.get("width") or 0) / float(live.get("scale") or 1)),
            int(live.get("y") or 0) + math.ceil(int(live.get("height") or 0) / float(live.get("scale") or 1)),
        )
    for permutation in itertools.permutations(plan):
        simulated = dict(current)
        valid = True
        for item in permutation:
            simulated[item["name"]] = rect(item)
            values = list(simulated.values())
            if any(overlaps(values[i], values[j]) for i in range(len(values)) for j in range(i + 1, len(values))):
                valid = False
                break
        if valid:
            return list(permutation)
    return sorted(plan, key=lambda item: item["posX"], reverse=True)


def monitor_argument(item: dict, force_sdr: bool = False) -> str:
    hdr = item["hdr"] and not force_sdr
    color = "srgb" if force_sdr else item["colorManagement"]
    bitdepth = 8 if force_sdr else item["bitdepth"]
    argument = (
        f'{item["name"]},{item["res"]}@{item["hz"]:.2f},'
        f'{item["posX"]}x{item["posY"]},{item["scale"]:.6f},'
        f'bitdepth,{bitdepth},vrr,{item["vrr"]}'
    )
    if hdr or color.startswith("hdr"):
        applied = "hdredid" if color == "hdredid" else "hdr"
        argument += (
            f',cm,{applied},sdrbrightness,{item["sdrBrightness"]:.1f}'
            f',sdrsaturation,{item["sdrSaturation"]:.1f}'
            f',sdr_max_luminance,{item["sdrLuminance"]}'
        )
    elif color not in ("default", ""):
        argument += f",cm,{color}"
    eotf = normalize_eotf(item["sdrEotf"])
    if eotf in ("default", "gamma22", "srgb"):
        argument += f",sdr_eotf,{eotf}"
    return argument


def atomic_json_write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def public_config(plan: list[dict]) -> dict:
    result = {}
    for item in plan:
        result[item["name"]] = {key: item[key] for key in (
            "role", "res", "hz", "scale", "autoScale", "posX", "posY", "default",
            "hdr", "bitdepth", "vrr", "sdrLuminance", "sdrBrightness",
            "sdrSaturation", "colorManagement", "iccProfile", "sdrEotf",
        )}
        result[item["name"]]["hz"] = f'{item["hz"]:.2f}'
        result[item["name"]]["scale"] = str(round(item["scale"], 6))
        result[item["name"]]["posX"] = str(item["posX"])
        result[item["name"]]["posY"] = str(item["posY"])
    return result


def runtime_roles(plan: list[dict]) -> dict:
    return {item["role"]: item["name"] for item in plan}


def merge_role_profiles(existing: dict, plan: list[dict]) -> dict:
    result = dict(existing or {})
    for item in plan:
        result[item["role"]] = {key: item[key] for key in (
            "res", "hz", "scale", "autoScale", "hdr", "bitdepth", "vrr",
            "sdrLuminance", "sdrBrightness", "sdrSaturation",
            "colorManagement", "iccProfile", "sdrEotf",
        )}
        result[item["role"]]["hz"] = f'{item["hz"]:.2f}'
        result[item["role"]]["scale"] = str(round(item["scale"], 6))
    ordered = {}
    for role in ROLE_NAMES:
        if role in result:
            ordered[role] = result[role]
    for role in sorted(result):
        if role not in ordered:
            ordered[role] = result[role]
    return ordered


def config_from_role_profiles(role_profiles: dict) -> dict:
    config = {}
    for index, (role, value) in enumerate((role_profiles or {}).items()):
        item = dict(value)
        item["role"] = role
        item["default"] = role == "primary"
        item["posX"] = str(index * 10000)
        item["posY"] = "0"
        config[role] = item
    return config


def run_json(command: list[str]) -> list[dict]:
    completed = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(completed.stdout)


def apply_plan(plan: list[dict], helper: Path) -> None:
    if plan_has_overlap(plan):
        raise RuntimeError("generated monitor plan overlaps")
    for item in safe_apply_order(plan):
        argument = monitor_argument(item)
        completed = subprocess.run([str(helper), "monitor", argument], capture_output=True, text=True)
        if completed.returncode != 0 and item["hdr"]:
            fallback = subprocess.run([str(helper), "monitor", monitor_argument(item, force_sdr=True)], capture_output=True, text=True)
            if fallback.returncode != 0:
                raise RuntimeError(f'{item["name"]}: HDR and SDR fallback failed')
            item["hdr"] = False
            item["bitdepth"] = 8
            item["colorManagement"] = "srgb"
        elif completed.returncode != 0:
            raise RuntimeError(f'{item["name"]}: monitor apply failed: {completed.stderr.strip()}')
    if plan:
        subprocess.run([str(helper), "focus", plan[0]["name"]], capture_output=True, text=True)


def verify_plan(plan: list[dict], live_outputs: list[dict]) -> None:
    live_by_name = {str(output.get("name") or ""): output for output in live_outputs}
    failures = []
    for item in plan:
        live = live_by_name.get(item["name"])
        if not live:
            failures.append(f'{item["name"]}: missing after apply')
            continue
        expected_width, expected_height = resolution_parts(item["res"])
        if (int(live.get("width") or 0), int(live.get("height") or 0)) != (expected_width, expected_height):
            failures.append(f'{item["name"]}: resolution mismatch')
        if (int(live.get("x") or 0), int(live.get("y") or 0)) != (item["posX"], item["posY"]):
            failures.append(f'{item["name"]}: position mismatch')
        if abs(float(live.get("scale") or 1.0) - float(item["scale"])) >= 0.02:
            failures.append(f'{item["name"]}: scale mismatch')
        live_color = str(live.get("colorManagementPreset") or live.get("colorManagement") or "srgb")
        if item["hdr"] and not live_color.startswith("hdr"):
            failures.append(f'{item["name"]}: HDR did not activate')
    if failures:
        raise RuntimeError("; ".join(failures))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--state-file", help="Use a monitor JSON fixture instead of hyprctl")
    args = parser.parse_args()

    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    root = config_home / "quickshell"
    config_path = root / "monitor_config.json"
    runtime_path = root / "monitor_runtime.json"
    role_profile_path = root / "monitor_role_profiles.json"
    helper = root / "scripts" / "hypr_monitor_apply.sh"
    lock_path = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "quickshell-monitor-role-manager.lock"

    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            config = json.loads(config_path.read_text(encoding="utf-8")) if config_path.exists() else {}
            if args.state_file:
                outputs = json.loads(Path(args.state_file).read_text(encoding="utf-8"))
            else:
                outputs = run_json(["hyprctl", "monitors", "all", "-j"])
            outputs = [output for output in outputs if not output.get("disabled")]
            connected_names = {str(output.get("name") or "") for output in outputs}
            role_profiles = json.loads(role_profile_path.read_text(encoding="utf-8")) if role_profile_path.exists() else {}

            # Manual changes made in the QuickShell monitor page are written to
            # monitor_config.json. Import only entries whose connectors are
            # currently connected; stale port names must never replace roles.
            for connector, value in config.items():
                if connector not in connected_names or not isinstance(value, dict):
                    continue
                role = value.get("role")
                if role:
                    role_profiles[role] = dict(value)

            if role_profiles:
                profile_config = config_from_role_profiles(role_profiles)
            else:
                profile_config = config
            plan = build_plan(outputs, profile_config)
            if args.dry_run:
                print(json.dumps({"roles": runtime_roles(plan), "config": public_config(plan)}, indent=2))
                return 0
            apply_plan(plan, helper)
            verify_plan(plan, run_json(["hyprctl", "monitors", "all", "-j"]))
            atomic_json_write(config_path, public_config(plan))
            atomic_json_write(runtime_path, runtime_roles(plan))
            atomic_json_write(role_profile_path, merge_role_profiles(role_profiles, plan))
            return 0
        except (OSError, ValueError, subprocess.SubprocessError, RuntimeError) as error:
            print(f"monitor-role-manager: {error}", file=sys.stderr)
            return 1


if __name__ == "__main__":
    raise SystemExit(main())
