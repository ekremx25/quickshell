"""Boot an actual freshly installed payload only inside the private compositor."""
import json
from pathlib import Path
import shutil
import unittest
from unittest.mock import patch
import test_cold_start_resources as cold
from test_installer import installer, monitor

ROOT = Path(__file__).resolve().parents[1]

@unittest.skipUnless(all(shutil.which(tool) for tool in cold.TOOLS), 'isolated desktop tools required')
class InstalledColdStartTests(unittest.TestCase):
    def test_fresh_payload_boots_without_author_config(self):
        original = shutil.copytree
        def install_instead_of_copy(src, dst, *args, **kwargs):
            if Path(src) != ROOT:
                return original(src,dst,*args,**kwargs)
            checkout=Path(dst).parent.parent/'installer-source'
            original(src,checkout,*args,**kwargs)
            data=installer.monitor_files([monitor('Virtual-0'),monitor('Virtual-1',1920)])
            data['screen_config.json']={key:['none' if value=='none' else 'all'] for key,value in installer.COMPONENTS.items()}
            with patch.object(installer,'check_running'):
                installer.install(checkout,Path(dst),data)
            self.assertFalse((Path(dst)/'assets/profile_avatar.jpg').exists())
            self.assertFalse((Path(dst)/'bar_config.json').exists())
            return str(dst)
        with patch.object(shutil,'copytree',install_instead_of_copy):
            report=cold.ColdStartResourceTests().run_cold_start(2)
        self.assertTrue(report['loaded'],report)
        self.assertTrue(report['alive'],report)
        self.assertEqual(report['nofile'],['1024','1024'],report)
        self.assertEqual(report['qml_reference_errors'],0,report)
        for key in ('pipe_errors','too_many_files','binding_loops','notification_conflicts'):
            self.assertEqual(report[key],0,report)
        print('Installed payload: '+json.dumps(report),flush=True)
