"""Exercise production DockPage sliders without disk writes or a compositor."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from test_dock_phase3 import block

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell required')
class DockSliderSyncTests(unittest.TestCase):
    def test_config_load_is_read_only_and_user_moves_save(self):
        source = (ROOT/'Modules/bar/Settings/DockPage.qml').read_text()
        sliders = []
        keys = []
        for index, match in enumerate(re.finditer(r'\bSlider \{', source)):
            fragment = block(source[match.start():], 'Slider {')
            key = re.search(r'value: root\.(cfg_\w+)', fragment).group(1)
            keys.append(key)
            sliders.append(fragment.replace('Slider {', 'Slider { id: slider' + str(index), 1))
        self.assertEqual(len(sliders), 6)
        properties = '\n'.join(re.search(r'    property (?:real|int)\s+' + key + r':[^\n]+', source).group(0) for key in keys)
        values = [1.23, 31, 0.94, 9, 5, 11]
        checks = []
        for index, (key, value) in enumerate(zip(keys, values)):
            checks.append(f'''
                root.isLoaded = false;
                root.{key} = {value};
                check(Math.abs(root.{key} - {value}) < 0.00001, "config value altered: {key}");
                check(Math.abs(slider{index}.value - {value}) < 0.00001, "slider not synced: {key}");
                check(root.saveCount === {index}, "load triggered save: {key}");
                root.isLoaded = true;
                slider{index}.increase();
                slider{index}.moved();
                check(root.saveCount === {index + 1}, "user move did not save: {key}");
                check(Math.abs(root.{key} - slider{index}.value) < 0.00001, "move not synced: {key}");
                for (var boundary of [slider{index}.from, slider{index}.to]) {{
                    root.{key} = boundary;
                    check(Math.abs(slider{index}.value - boundary) < 0.00001, "boundary not synced: {key}");
                    check(root.saveCount === {index + 1}, "refresh triggered save: {key}");
                }}
            ''')
        qml = '''import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
ShellRoot {
        id: root
        property int saveCount: 0
        property bool isLoaded: false
        property color colorPrimary: "#89b4fa"
        property color colorTrack: "#313244"
        PROPERTIES
        function save() { if (isLoaded) saveCount++; }
        Item { width: 400; height: 700
            @SLIDERS@
        }
    function check(value, message) { if (!value) throw new Error(message); }
    Component.onCompleted: Qt.callLater(function() {
        try {
            check(root.saveCount === 0, "construction triggered save");
            CHECKS
            console.log("SLIDERS_PASS"); Qt.quit();
        } catch (error) { console.error("SLIDERS_FAIL " + error); Qt.exit(1); }
    });
}
'''.replace('PROPERTIES', properties).replace('@SLIDERS@', '\n'.join(sliders)).replace('CHECKS', '\n'.join(checks))
        scratch = ROOT/'.temp_files'; scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch, prefix='d-') as folder:
            temp = Path(folder)
            (temp/'shell.qml').write_text(qml)
            runtime = temp/'r'; runtime.mkdir(mode=0o700)
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(temp/'config'),
                       XDG_CACHE_HOME=str(temp/'cache'), XDG_STATE_HOME=str(temp/'state'))
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['quickshell', '-p', str(temp/'shell.qml'), '--no-color'],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertIn('SLIDERS_PASS', output)
            self.assertEqual(result.returncode, 0, output)
            self.assertNotIn('Binding loop', output)
            self.assertNotIn('ReferenceError', output)
