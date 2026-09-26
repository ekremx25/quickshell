"""Real pointer events must not hide the dock when entering child controls."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from test_dock_phase3 import block

ROOT = Path(__file__).resolve().parents[1]
RUNNER = '/usr/lib/qt6/bin/qmltestrunner' if Path('/usr/lib/qt6/bin/qmltestrunner').exists() else shutil.which('qmltestrunner')

@unittest.skipUnless(RUNNER, 'Qt Quick Test runner required')
class DockPointerTests(unittest.TestCase):
    def test_child_hover_and_click_keep_dock_visible(self):
        source = (ROOT / 'Modules/bar/Dock/Dock.qml').read_text()
        hover = block(source, 'HoverHandler {\n                id: dockHover') if 'id: dockHover' in source else ''
        bindings = re.search(r'property bool dockContainsMouse:.*', source).group(0) + '\n' + block(source, 'property bool shouldHide:')
        background = block(source, 'MouseArea {\n            id: globalMouse')
        row = block(source, 'MouseArea {\n                id: dockRowMouseArea') if 'id: dockRowMouseArea' in source else ''
        qml = '''import QtQuick
import QtTest
Item {
 id: scene; width:400; height:200
 Item {
  id: dockWindow; x:50; y:50; width:300; height:70
  property var dockConfigData: ({autoHide:true})
  property bool cfgIntelligentHide: false
  property bool contextMenuVisible: false
  property bool isDragging: false
  property bool hasOverlappingWindow: true
  __BINDINGS__
  __BACKGROUND__
  Rectangle {
   id: dockContent; anchors.fill:parent; color:"gray"
   __HOVER__
   __ROW__
   Rectangle {
    id: icon; x:40; y:10; width:50; height:50; color:"blue"
    property int clicks:0
    MouseArea {anchors.fill:parent; hoverEnabled:true; onClicked: icon.clicks++}
   }
  }
 }
 TestCase {
  name:"DockPointer"; when:windowShown
  function test_hover_then_click() {
   mouseMove(scene,10,10);
   verify(dockWindow.shouldHide);
   mouseMove(dockContent,5,5);
   verify(!dockWindow.shouldHide,"padding reveals dock");
   mouseMove(icon,25,25);
   verify(!dockWindow.shouldHide,"child hover must keep dock visible");
   mousePress(icon,25,25);
   verify(!dockWindow.shouldHide,"press must keep dock visible");
   mouseRelease(icon,25,25);
   compare(icon.clicks,1,"child receives click");
   mouseMove(scene,10,10);
   verify(dockWindow.shouldHide,"leaving dock allows hide");
  }
 }
}'''.replace('__BINDINGS__', bindings).replace('__BACKGROUND__', background).replace('__HOVER__', hover).replace('__ROW__', row)
        scratch = ROOT / '.temp_files'
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch, prefix='dock-pointer-') as directory:
            path = Path(directory)
            (path / 'tst_dock.qml').write_text(qml)
            (path / 'runtime').mkdir(mode=0o700)
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=str(path / 'runtime'))
            result = subprocess.run([RUNNER, '-input', str(path), '-o', '-,txt'], env=env, text=True, capture_output=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

if __name__ == '__main__':
    unittest.main()
