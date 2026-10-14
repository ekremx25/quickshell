"""Exercise production Settings page construction with inert external pages."""
import os
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell required')
class SettingsLazyPagesTests(unittest.TestCase):
    def test_hidden_settings_do_not_construct_pages(self):
        source = (ROOT / 'Modules/bar/Settings/Settings.qml').read_text()
        marker = '                    clip: true'
        begin = source.index(marker, source.index('color: contentPanelColor')) + len(marker)
        end = source.index('\n                }\n            }\n        }\n\n        //', begin)
        area = source[begin:end]
        area = re.sub(r'\b(?:Sys\.)?([A-Z]\w*Page)\s*\{', r'Stub.\1 {', area)
        page_names = set(re.findall(r'Stub\.(\w+)', area))
        page_keys = re.findall(r'currentPage === "([^"]+)"', area)
        remaining = list(dict.fromkeys(key for key in page_keys if key not in ('bar', 'dock')))
        scratch = ROOT / '.temp_files'
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch, prefix='s-') as folder:
            temp = Path(folder)
            (temp/'stubs').mkdir()
            for name in page_names:
                (temp/'stubs'/f'{name}.qml').write_text('''import QtQuick
Item {
    property var backend; property var barConfig; property var settingsPopup
    property var leftModel; property var centerModel; property var rightModel
    property var inactiveModel; property var dockLeftModel; property var dockRightModel
    property var dragLayer
    signal barConfigEdited(var cfg)
    signal saveRequested()
    signal presetApplied()
    Component.onCompleted: probe.created++
}
''')
            # probe is a creation context property shared with external components.
            qml = '''import QtQuick
import Quickshell
import "stubs" as Stub
ShellRoot {
    QtObject { id: probe; property int created: 0 }
    QtObject { id: settingsBackend }
    QtObject { id: leftModulesModel }
    QtObject { id: centerModulesModel }
    QtObject { id: rightModulesModel }
    QtObject { id: inactiveModulesModel }
    QtObject { id: dockLeftModulesModel }
    QtObject { id: dockRightModulesModel }
    QtObject {
        id: settingsWindow
        property bool visible: false
        property string currentPage: "bar"
        property var barConfig: ({})



        function scheduleApplyUiFont() {}
        function saveConfig() {}
        function loadConfig() {}
        function closeSettings() { visible = false; }
    }
    Item {
        id: settingsContent



        AREA
    }
    property var remainingPages: REMAINING
    function verifyRemaining(index) {
        if (index === remainingPages.length) {
            settingsWindow.visible = false;
            Qt.callLater(function() {
                for (var child of settingsContent.children) {
                    if (child.item) { console.error("PAGES_FAIL retained page"); Qt.exit(1); return; }
                }
                console.log("PAGES_PASS"); Qt.quit();
            });
            return;
        }
        settingsWindow.currentPage = remainingPages[index];
        Qt.callLater(function() {
            if (probe.created !== index + 3) { console.error("PAGES_FAIL page=" + remainingPages[index]); Qt.exit(1); return; }
            verifyRemaining(index + 1);
        });
    }
    Component.onCompleted: Qt.callLater(function() {
        if (probe.created !== 0) { console.error("PAGES_FAIL hidden=" + probe.created); Qt.exit(1); return; }
        settingsWindow.visible = true;
        Qt.callLater(function() {
            if (probe.created !== 1) { console.error("PAGES_FAIL open=" + probe.created); Qt.exit(1); return; }
            settingsWindow.currentPage = "dock";
            Qt.callLater(function() {
                if (probe.created !== 2) { console.error("PAGES_FAIL switch=" + probe.created); Qt.exit(1); return; }
                verifyRemaining(0);
            });
        });
    });
}
'''.replace('AREA', area).replace('REMAINING', json.dumps(remaining))
            # No theme references are needed inside the extracted page declarations.
            (temp/'shell.qml').write_text(qml)
            runtime = temp/'r'; runtime.mkdir(mode=0o700)
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(temp/'config'),
                       XDG_CACHE_HOME=str(temp/'cache'), XDG_STATE_HOME=str(temp/'state'))
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['quickshell', '-p', str(temp/'shell.qml'), '--no-color'],
                                    env=env, text=True, capture_output=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertIn('PAGES_PASS', output)
            self.assertEqual(result.returncode, 0, output)
            self.assertNotIn('ReferenceError', output)
