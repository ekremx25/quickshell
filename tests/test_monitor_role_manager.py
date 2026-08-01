import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts" / "monitor_role_manager.py"
SPEC = importlib.util.spec_from_file_location("monitor_role_manager", SCRIPT)
manager = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = manager
SPEC.loader.exec_module(manager)


def output(name, width, height, hz, physical_width, physical_height, x=0, scale=1.0):
    return {
        "name": name,
        "width": width,
        "height": height,
        "refreshRate": hz,
        "physicalWidth": physical_width,
        "physicalHeight": physical_height,
        "x": x,
        "y": 0,
        "scale": scale,
        "availableModes": [f"{width}x{height}@{hz:.2f}Hz"],
    }


class MonitorRoleManagerTests(unittest.TestCase):
    def test_auto_scale_4k_27_inch(self):
        monitor = output("DP-9", 3840, 2160, 160, 600, 340)
        self.assertAlmostEqual(manager.automatic_scale(monitor, "3840x2160"), 4 / 3)

    def test_auto_scale_1080p_27_inch(self):
        monitor = output("HDMI-A-8", 1920, 1080, 165, 600, 340)
        self.assertEqual(manager.automatic_scale(monitor, "1920x1080"), 1.0)

    def test_port_names_do_not_control_roles(self):
        outputs = [
            output("HDMI-A-9", 3840, 2160, 160, 600, 340),
            output("DP-1", 1920, 1080, 165, 600, 340),
        ]
        config = {
            "OLD-DP": {"res": "3840x2160", "hz": "160", "default": True, "hdr": True},
            "OLD-HDMI": {"res": "1920x1080", "hz": "165", "default": False},
        }
        plan = manager.build_plan(outputs, config)
        self.assertEqual(plan[0]["name"], "HDMI-A-9")
        self.assertEqual(plan[0]["role"], "primary")
        self.assertEqual(plan[1]["name"], "DP-1")

    def test_three_monitors_are_contiguous_and_non_overlapping(self):
        outputs = [
            output("DP-4", 2560, 1440, 144, 600, 340),
            output("HDMI-A-2", 1920, 1080, 60, 520, 290),
            output("DP-8", 3840, 2160, 160, 600, 340),
        ]
        config = {
            "A": {"res": "3840x2160", "hz": "160", "default": True},
            "B": {"res": "2560x1440", "hz": "144", "default": False, "posX": "2880"},
        }
        plan = manager.build_plan(outputs, config)
        self.assertEqual(len(plan), 3)
        self.assertEqual([item["role"] for item in plan], ["primary", "secondary", "tertiary"])
        self.assertFalse(manager.plan_has_overlap(plan))
        self.assertEqual(plan[1]["posX"], manager.rect(plan[0])[2])
        self.assertEqual(plan[2]["posX"], manager.rect(plan[1])[2])

    def test_unsupported_saved_mode_falls_back_to_native(self):
        monitor = output("DP-1", 2560, 1440, 144, 600, 340)
        resolution, rate = manager.preferred_mode(monitor, {"res": "3840x2160", "hz": "160"})
        self.assertEqual(resolution, "2560x1440")
        self.assertEqual(rate, 144)

    def test_same_capability_outputs_are_deterministic(self):
        outputs = [
            output("DP-3", 1920, 1080, 60, 520, 290),
            output("HDMI-A-1", 1920, 1080, 60, 520, 290),
        ]
        assignments = manager.assign_roles(outputs, [{"role": "primary", "res": "1920x1080"}])
        self.assertEqual(assignments[0][0]["name"], "DP-3")

    def test_verify_plan_accepts_hyprland_scale_rounding(self):
        monitor = output("DP-3", 3840, 2160, 160, 600, 340, scale=1.33)
        monitor.update({"colorManagementPreset": "hdr", "x": 0, "y": 0})
        plan = [{
            "name": "DP-3", "res": "3840x2160", "scale": 4 / 3,
            "posX": 0, "posY": 0, "hdr": True,
        }]
        manager.verify_plan(plan, [monitor])


if __name__ == "__main__":
    unittest.main()
