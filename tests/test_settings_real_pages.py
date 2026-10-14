"""Exercise actual loaded settings pages, real mouse clicks and JSON persistence."""
import shutil
from pathlib import Path
import unittest
from unittest.mock import patch
import test_cold_start_resources as cold

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(all(shutil.which(tool) for tool in cold.TOOLS), 'isolated desktop test tools required')
class SettingsRealPagesTests(unittest.TestCase):
    def check_page(self, page):
        fixture = {'routing': 'screen_routing_probe.qml', 'weather_drag': 'weather_drag_probe.qml', 'module_catalog': 'module_catalog_probe.qml'}.get(page, 'settings_page_probe.qml')
        source = (ROOT/'tests/fixtures'/fixture).read_text().replace('__PAGE__', page)
        original = shutil.copytree
        def copy_with_probe(src, dst, *args, **kwargs):
            result = original(src, dst, *args, **kwargs)
            if Path(src) == ROOT:
                (Path(dst)/'shell.qml').write_text(source)
                if page == 'weather_drag':
                    weather = Path(dst)/'Modules/bar/Weather/WeatherDesktop.qml'
                    content = weather.read_text().replace('    id: root', '    id: root\n    readonly property var testPanels: testVariants.instances', 1)
                    content = content.replace('    Variants {', '    Variants {\n        id: testVariants', 1)
                    weather.write_text(content)
            return result
        with patch.object(shutil, 'copytree', copy_with_probe):
            report = cold.ColdStartResourceTests().run_cold_start(3)
        results = '\n'.join(report['ui_results'])
        self.assertIn('SETTINGS_UI_PASS ' + page, results, report)
        self.assertNotIn('SETTINGS_UI_FAIL', results)
        self.assertEqual(report['binding_loops'], 0, report)
        self.assertEqual(report['qml_reference_errors'], 0, report)

    def test_bar_models_move_and_save(self):
        self.check_page('bar')

    def test_dock_load_click_and_save(self):
        self.check_page('dock')

    def test_screen_preferences_click_and_save(self):
        self.check_page('screens')

    def test_workspaces_style_apply_and_bar_reload(self):
        self.check_page('workspaces')

    def test_screen_routing_after_disk_reload(self):
        self.check_page('routing')

    def test_weather_drag_and_position_persistence(self):
        self.check_page('weather_drag')

    def test_all_modules_load_in_bar_and_dock_slots(self):
        self.check_page('module_catalog')
