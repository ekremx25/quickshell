"""Atomic cross-monitor Workspace Overview move transaction tests."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/hypr_overview_action.sh"
WINDOW = "0x12ab"

FAKE_HYPRCTL = r'''#!/usr/bin/env python3
import json
import os
import re
import sys

path = os.environ["HYPR_FAKE_STATE"]
with open(path, encoding="utf-8") as handle:
    state = json.load(handle)
args = sys.argv[1:]
if args[:2] == ["-i", "0"]:
    args = args[2:]

def save():
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(state, handle)

def monitor(name):
    return next((item for item in state["monitors"] if item["name"] == name), None)

def workspace(name):
    return next((item for item in state["workspaces"] if item["name"] == name or str(item["id"]) == name), None)

def client(address):
    return next((item for item in state["clients"] if item["address"] == address), None)

def refresh_counts():
    for item in state["workspaces"]:
        item["windows"] = sum(1 for entry in state["clients"] if entry["workspace"]["name"] == item["name"])
    state["workspaces"] = [item for item in state["workspaces"] if item["windows"] > 0 or item.get("ispersistent", False)]

def disconnect(name):
    removed = monitor(name)
    if not removed:
        return
    state["monitors"] = [item for item in state["monitors"] if item["name"] != name]
    fallback = state["monitors"][0]
    for item in state["workspaces"]:
        if item["monitor"] == name:
            item["monitor"] = fallback["name"]
            item["monitorID"] = fallback["id"]
    for item in state["clients"]:
        if item["monitor"] == removed["id"]:
            item["monitor"] = fallback["id"]

def move_window(address, target):
    item = client(address)
    if not item:
        return False
    destination = workspace(target)
    if not destination:
        current_monitor = next(entry for entry in state["monitors"] if entry["id"] == item["monitor"])
        numeric = int(target) if target.isdigit() else -99
        destination = {"id": numeric, "name": target, "monitor": current_monitor["name"], "monitorID": current_monitor["id"], "windows": 0, "ispersistent": False}
        state["workspaces"].append(destination)
    item["workspace"] = {"id": destination["id"], "name": destination["name"]}
    item["monitor"] = destination["monitorID"]
    state["actions"].append({"type": "window", "workspace": target, "address": address})
    refresh_counts()
    if state.get("scenario") == "disconnect_after_window" and not state.get("disconnected"):
        state["disconnected"] = True
        disconnect(state["disconnect_monitor"])
    return True

def move_workspace(target, target_monitor):
    destination_monitor = monitor(target_monitor)
    item = workspace(target)
    if not item or not destination_monitor or destination_monitor.get("disabled") or not destination_monitor.get("dpmsStatus", True) or destination_monitor.get("mirrorOf", "none") not in ("", "none"):
        return False
    item["monitor"] = target_monitor
    item["monitorID"] = destination_monitor["id"]
    for entry in state["clients"]:
        if entry["workspace"]["name"] == item["name"]:
            entry["monitor"] = destination_monitor["id"]
    state["actions"].append({"type": "workspace", "workspace": target, "monitor": target_monitor})
    if state.get("scenario") == "disconnect_after_workspace" and not state.get("disconnected"):
        state["disconnected"] = True
        disconnect(state["disconnect_monitor"])
    return True

if not args:
    raise SystemExit(2)
if args[0] == "systeminfo":
    print("configProvider: lua")
    raise SystemExit(0)
if args[0] in ("clients", "monitors", "workspaces") and "-j" in args:
    print(json.dumps(state[args[0]]))
    raise SystemExit(0)
if args[0] == "eval":
    expression = args[1]
    window_match = re.search(r'hl\.dsp\.window\.move\(\{ workspace = "([^"]+)", follow = false, window = "address:([^"]+)"', expression)
    workspace_match = re.search(r'hl\.dsp\.workspace\.move\(\{ workspace = "([^"]+)", monitor = "([^"]+)"', expression)
    success = False
    if window_match:
        success = move_window(window_match.group(2), window_match.group(1))
    elif workspace_match:
        success = move_workspace(workspace_match.group(1), workspace_match.group(2))
    save()
    if success:
        print("ok")
        raise SystemExit(0)
    print("fake dispatcher failure", file=sys.stderr)
    raise SystemExit(1)
print("unsupported fake hyprctl call", file=sys.stderr)
raise SystemExit(2)
'''


def monitor(monitor_id, name, mirror="none"):
    return {
        "id": monitor_id,
        "name": name,
        "disabled": False,
        "dpmsStatus": True,
        "mirrorOf": mirror,
    }


def initial_state(monitors, scenario="", disconnect_monitor=""):
    return {
        "monitors": monitors,
        "clients": [{
            "address": WINDOW,
            "monitor": 0,
            "workspace": {"id": 2, "name": "2"},
        }],
        "workspaces": [{
            "id": 2,
            "name": "2",
            "monitor": monitors[0]["name"],
            "monitorID": 0,
            "windows": 1,
            "ispersistent": False,
        }],
        "actions": [],
        "scenario": scenario,
        "disconnect_monitor": disconnect_monitor,
        "disconnected": False,
    }


class WorkspaceOverviewTransactionTests(unittest.TestCase):
    def run_move(self, state, target_monitor):
        with tempfile.TemporaryDirectory(prefix="overview-transaction-") as directory:
            temp = Path(directory)
            state_path = temp / "state.json"
            state_path.write_text(json.dumps(state))
            fake = temp / "hyprctl"
            fake.write_text(FAKE_HYPRCTL)
            fake.chmod(0o755)
            env = dict(
                os.environ,
                PATH=str(temp) + os.pathsep + os.environ["PATH"],
                HYPR_FAKE_STATE=str(state_path),
            )
            result = subprocess.run(
                [str(HELPER), "move", WINDOW, "6", target_monitor],
                env=env,
                text=True,
                capture_output=True,
                timeout=10,
            )
            return result, json.loads(state_path.read_text())

    def assert_success(self, state, target_monitor):
        result, final = self.run_move(state, target_monitor)
        self.assertEqual(result.returncode, 0, result.stderr)
        moved = final["clients"][0]
        target = next(item for item in final["workspaces"] if item["name"] == "6")
        target_id = next(item["id"] for item in final["monitors"] if item["name"] == target_monitor)
        self.assertEqual(moved["workspace"]["name"], "6")
        self.assertEqual(moved["monitor"], target_id)
        self.assertEqual(target["monitor"], target_monitor)
        self.assertEqual([item["type"] for item in final["actions"]], ["window", "workspace"])

    def assert_rolled_back(self, state, expected_code):
        result, final = self.run_move(state, state["disconnect_monitor"])
        self.assertEqual(result.returncode, expected_code, result.stderr)
        restored = final["clients"][0]
        source = next(item for item in final["workspaces"] if item["name"] == "2")
        self.assertEqual(restored["workspace"]["name"], "2")
        self.assertEqual(restored["monitor"], 0)
        self.assertEqual(source["monitor"], "DP-1")
        self.assertNotIn("rollback is incomplete", result.stderr)
        self.assertIn({"type": "window", "workspace": "2", "address": WINDOW}, final["actions"])

    def test_two_monitor_move(self):
        self.assert_success(initial_state([monitor(0, "DP-1"), monitor(1, "DP-2")]), "DP-2")

    def test_three_monitor_move(self):
        self.assert_success(initial_state([monitor(0, "DP-1"), monitor(1, "DP-2"), monitor(2, "HDMI-A-1")]), "HDMI-A-1")

    def test_mirror_monitor_is_rejected_without_mutation(self):
        state = initial_state([monitor(0, "DP-1"), monitor(1, "HDMI-A-1", mirror="DP-1")])
        result, final = self.run_move(state, "HDMI-A-1")
        self.assertEqual(result.returncode, 4)
        self.assertEqual(final["actions"], [])
        self.assertEqual(final["clients"][0]["workspace"]["name"], "2")
        self.assertIn("mirrored", result.stderr)

    def test_disconnect_after_window_move_rolls_back(self):
        state = initial_state([monitor(0, "DP-1"), monitor(1, "DP-2")], "disconnect_after_window", "DP-2")
        self.assert_rolled_back(state, 6)

    def test_disconnect_after_workspace_move_rolls_back(self):
        state = initial_state([monitor(0, "DP-1"), monitor(1, "DP-2")], "disconnect_after_workspace", "DP-2")
        self.assert_rolled_back(state, 8)


if __name__ == "__main__":
    unittest.main()
