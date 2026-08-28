from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "monitor_role_manager", ROOT / "scripts" / "monitor_role_manager.py"
)
assert SPEC and SPEC.loader
MANAGER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MANAGER
SPEC.loader.exec_module(MANAGER)


def output(
    name: str,
    make: str,
    model: str,
    serial: str,
    resolution: str = "1920x1080",
    refresh: float = 60.0,
) -> dict:
    width, height = (int(part) for part in resolution.split("x", 1))
    return {
        "name": name,
        "make": make,
        "model": model,
        "serial": serial,
        "description": f"{make} {model} {serial}",
        "width": width,
        "height": height,
        "refreshRate": refresh,
        "availableModes": [f"{resolution}@{refresh:.2f}Hz"],
        "physicalWidth": 600,
        "physicalHeight": 340,
    }


class MonitorRoleManagerTests(unittest.TestCase):
    def test_identity_is_independent_of_connector_name(self) -> None:
        first = output("DP-1", "Vendor", "Panel", "SERIAL-1")
        moved = output("HDMI-A-2", "Vendor", "Panel", "SERIAL-1")
        self.assertEqual(MANAGER.monitor_identity(first), MANAGER.monitor_identity(moved))

    def test_remembered_roles_win_for_identical_monitors(self) -> None:
        primary = output("HDMI-A-9", "Vendor", "SamePanel", "PRIMARY")
        secondary = output("DP-9", "Vendor", "SamePanel", "SECONDARY")
        profiles = [
            {"role": "primary", "res": "1920x1080"},
            {"role": "secondary", "res": "1920x1080"},
        ]
        identities = {
            MANAGER.monitor_identity(primary): "primary",
            MANAGER.monitor_identity(secondary): "secondary",
        }

        assignments = MANAGER.assign_roles(
            [secondary, primary], profiles, identities
        )
        by_role = {profile["role"]: monitor["serial"] for monitor, profile in assignments}

        self.assertEqual(by_role, {"primary": "PRIMARY", "secondary": "SECONDARY"})

    def test_new_install_assigns_largest_display_as_primary(self) -> None:
        small = output("HDMI-A-1", "Vendor", "FHD", "FHD-1")
        large = output("DP-1", "Vendor", "UHD", "UHD-1", "3840x2160", 144.0)

        plan = MANAGER.build_plan([small, large], {})

        self.assertEqual(plan[0]["role"], "primary")
        self.assertEqual(plan[0]["_live"]["serial"], "UHD-1")
        self.assertEqual(plan[1]["role"], "secondary")

    def test_identities_still_restore_roles_if_profiles_are_missing(self) -> None:
        primary = output("HDMI-A-4", "Vendor", "Panel", "PRIMARY")
        secondary = output("DP-7", "Vendor", "Panel", "SECONDARY")
        identities = {
            MANAGER.monitor_identity(primary): "primary",
            MANAGER.monitor_identity(secondary): "secondary",
        }

        assignments = MANAGER.assign_roles([secondary, primary], [], identities)
        by_role = {profile["role"]: monitor["serial"] for monitor, profile in assignments}

        self.assertEqual(by_role, {"primary": "PRIMARY", "secondary": "SECONDARY"})

    def test_stale_connector_config_cannot_reverse_physical_roles(self) -> None:
        asus_identity = "edid:vendor|asus|asus-serial"
        media_identity = "edid:vendor|media|media-serial"
        old_config = {
            "DP-3": {"role": "primary", "identity": asus_identity, "res": "3840x2160"},
            "HDMI-A-1": {"role": "secondary", "identity": media_identity, "res": "1920x1080"},
        }
        # The physical monitors now use each other's former connector names.
        live = [
            output("HDMI-A-1", "Vendor", "ASUS", "ASUS-SERIAL", "3840x2160"),
            output("DP-3", "Vendor", "Media", "MEDIA-SERIAL"),
        ]
        identities = {asus_identity: "primary", media_identity: "secondary"}
        profiles = {
            "primary": {"res": "3840x2160"},
            "secondary": {"res": "1920x1080"},
        }

        merged_profiles, merged_identities = MANAGER.merge_connected_profiles(
            old_config, live, profiles, identities
        )

        self.assertEqual(merged_profiles, profiles)
        self.assertEqual(merged_identities, identities)

    def test_public_config_records_physical_identity(self) -> None:
        monitor = output("DP-1", "Vendor", "Panel", "SERIAL-1")
        config = MANAGER.public_config(MANAGER.build_plan([monitor], {}))

        self.assertEqual(config["DP-1"]["role"], "primary")
        self.assertEqual(
            config["DP-1"]["identity"], MANAGER.monitor_identity(monitor)
        )


if __name__ == "__main__":
    unittest.main()
