import importlib.util
from pathlib import Path
import sys
import unittest
import json
import os
import tempfile
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
from monitor_port_restore import plan_restore
import monitor_port_restore


def displays():
    base = dict(width=1920, height=1080, refreshRate=165.0, x=2560, y=0, scale=1,
                transform=0, vrr=False, colorManagementPreset='hdr', currentFormat='XRGB2101010',
                sdrBrightness=1.3, sdrSaturation=1.2, sdrMaxLuminance=267,
                sdrMinLuminance=0.2, make='Media4', model='GB', serial='1', mirrorOf='none')
    return [dict(base, id=1, name='DP-3'),
            dict(base, id=2, name='HDMI-A-1', mirrorOf='1',
                 colorManagementPreset='srgb', currentFormat='XRGB8888')]


class MonitorPortRestoreTests(unittest.TestCase):
    def test_main_publishes_roles_for_dock_and_workspaces(self):
        saved = displays()
        config = {'DP-3': {'role': 'primary', 'identity': 'edid:media4|gb|1'}}
        for moved in (False, True):
            with self.subTest(moved=moved), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / 'quickshell'
                root.mkdir()
                (root / 'monitor_port_snapshot.json').write_text(json.dumps(saved))
                (root / 'monitor_config.json').write_text(json.dumps(config))
                live = [dict(saved[0], name='DP-1' if moved else 'DP-3'), saved[1]]
                with patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}), \
                     patch.object(sys, 'argv', ['restore']), \
                     patch.object(monitor_port_restore.subprocess, 'check_output', return_value=json.dumps(live)), \
                     patch.object(monitor_port_restore.subprocess, 'run') as apply:
                    monitor_port_restore.main()
                runtime = root / 'monitor_runtime.json'
                self.assertTrue(runtime.exists(), 'Port restore must publish the shared UI role map')
                self.assertEqual(json.loads(runtime.read_text()), {'primary': live[0]['name']})
                self.assertEqual(apply.call_count, 2 if moved else 0)

    def test_unchanged_is_noop(self):
        saved = displays()
        self.assertEqual(plan_restore(saved, saved), [])

    def test_dp_move_preserves_hdr_geometry_and_updates_mirror(self):
        saved = displays()
        live = [dict(saved[0], name='DP-1', x=0, y=180), saved[1]]
        commands = plan_restore(saved, live)
        self.assertEqual(len(commands), 2)
        self.assertIn('DP-1,1920x1080@165.00,2560x0,1.000000', commands[0])
        self.assertIn('bitdepth,10', commands[0])
        self.assertIn('cm,hdr,sdrbrightness,1.3,sdrsaturation,1.2,sdr_max_luminance,267', commands[0])
        self.assertIn('sdr_min_luminance,0.2', commands[0])
        self.assertTrue(commands[1].endswith(',mirror,DP-1'))
        self.assertIn('bitdepth,8', commands[1])
        self.assertIn('cm,srgb', commands[1])

    def test_absent_source_does_not_self_mirror(self):
        saved = displays()
        with self.assertRaisesRegex(ValueError, 'Ambiguous'):
            plan_restore(saved, [saved[1]])

    def test_ambiguous_identity_is_not_assigned(self):
        saved = displays()[:1]
        self.assertEqual(plan_restore(saved, [dict(saved[0], name='DP-1'), dict(saved[0], name='DP-4')]), [])

    def test_unrelated_display_is_untouched(self):
        self.assertEqual(plan_restore(displays(), [dict(displays()[0], serial='other', name='DP-1')]), [])


if __name__ == '__main__':
    unittest.main()
