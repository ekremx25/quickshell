import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('sync', ROOT / 'scripts/hyprmoncfg_sync.py')
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class ProfileSyncTests(unittest.TestCase):
    def setUp(self):
        self.profile = dict(outputs=[dict(name='DP-1', match_key='a|b|c'),
                                    dict(name='HDMI-1', scale=1)], workspaces={'enabled': False}, exec='')
        self.desired = {'DP-1': dict(identity='edid:a|b|c', res='3840x2160', hz='160',
            scale='1.25', posX='0', posY='0', bitdepth=10, vrr=0, hdr=True,
            colorManagement='hdr', sdrLuminance=324, sdrBrightness=1.2, sdrSaturation=1.3)}

    def test_hdr_geometry_and_unedited_output(self):
        result = sync.merge(self.profile, self.desired)
        self.assertEqual(result['outputs'][0]['cm'], 'hdr')
        self.assertEqual(result['outputs'][0]['scale'], 1.25)
        self.assertIsInstance(result['outputs'][0]['sdr_max_luminance'], int)
        self.assertEqual(result['outputs'][1], self.profile['outputs'][1])
        self.assertEqual(result['workspaces'], self.profile['workspaces'])
        self.assertNotIn('cm', self.profile['outputs'][0])

    def test_identity_mismatch_rejected(self):
        self.desired['DP-1']['identity'] = 'edid:other'
        with self.assertRaises(ValueError):
            sync.merge(self.profile, self.desired)

    def test_unknown_display_rejected(self):
        self.desired['DP-2'] = self.desired.pop('DP-1')
        with self.assertRaises(ValueError):
            sync.merge(self.profile, self.desired)

    def test_invalid_scale_rejected(self):
        self.desired['DP-1']['scale'] = 'nan'
        with self.assertRaises(ValueError):
            sync.merge(self.profile, self.desired)

    def test_other_compositors_do_not_touch_profiles(self):
        for compositor in ('niri', 'mango', 'unknown'):
            with patch.object(sync, 'run', return_value=compositor) as run:
                sync.main()
                self.assertEqual(run.call_count, 1)

    def test_hook_only_runs_after_keep(self):
        source = (ROOT / 'Modules/bar/System/MonitorsBackend.qml').read_text()
        preview = source.split('function applySettings(', 1)[1].split('function confirmPreview()', 1)[0]
        self.assertNotIn('hyprmoncfg_sync.py', preview)
        self.assertIn('backend.finishConfirmation()', source)
