"""Exercise the production GridView scroll handlers without a Wayland desktop."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WallpaperDeckPaginationTests(unittest.TestCase):
    def test_non_drag_scroll_and_pagination_guards(self):
        self.assertIsNotNone(shutil.which('quickshell'))
        source = (ROOT / 'Modules/wallpaper/WallpaperDeck.qml').read_text()
        start = source.index('                GridView {')
        end = source.index('                    delegate: Item {', start)
        grid = source[start:end].replace('S.WallpaperDeckService', 'service').replace('Theme.animMedium', '0')
        service = (ROOT / 'Services/WallpaperDeckService.qml').read_text()
        start = service.index('    function loadNextPage() {')
        end = service.index('\n    function applyItem', start)
        next_page = service[start:end].replace('root.', 'service.')
        qml = '''import QtQuick
import Quickshell
ShellRoot {
 FloatingWindow {
  id: root
  visible: true
  implicitWidth: 900; implicitHeight: 600
  property string sourceMode: "wallhaven"
  property var sourceItems: Array.from({length:24}, (_,i)=>i)
  QtObject {
   id: service
   property bool searchBusy: false
   property string errorMessage: ""
   property int currentPage: 1
   property int lastPage: 2
   property int calls: 0
   function searchWallhaven(page) { searchBusy = true; calls++; }
   NEXT_PAGE
  }
  GRID
   delegate: Rectangle { width: deck.cellWidth; height: deck.cellHeight }
  }
  function require(value, message) { if (!value) throw new Error(message); }
  function endScroll() { deck.contentX = deck.originX + deck.contentWidth - deck.width; }
  function run() {
   try {
    require(!deck.moving, "fixture must scroll without dragging");
    root.sourceMode = "local"; endScroll();
    require(service.calls === 0, "local must not fetch Wallhaven");
    deck.contentX = deck.originX; root.sourceMode = "wallhaven";
    service.errorMessage = "offline"; endScroll();
    require(service.calls === 0, "error must not trigger retry loop");
    deck.contentX = deck.originX; service.errorMessage = ""; service.searchBusy = true; endScroll();
    require(service.calls === 0, "busy must not duplicate request");
    deck.contentX = deck.originX; service.searchBusy = false; endScroll();
    require(service.calls === 1, "non-drag end scroll must load next page");
    deck.loadMoreNearEnd();
    require(service.calls === 1, "in-flight request must not duplicate");
    service.currentPage = 2; service.searchBusy = false;
    deck.contentX = deck.originX; endScroll();
    require(service.calls === 1, "last page must stop pagination");
    console.log("DECK_PAGINATION_PASS");
   } catch (error) { console.error("DECK_PAGINATION_FAIL", error); }
   Qt.quit();
  }
  Component.onCompleted: Qt.callLater(root.run)
 }
 Timer { interval: 5000; running: true; onTriggered: { console.error("DECK_PAGINATION_FAIL timeout"); Qt.quit(); } }
}
'''.replace('NEXT_PAGE', next_page).replace('GRID', grid)
        with tempfile.TemporaryDirectory(prefix='qs-deck-pagination-') as directory:
            temp = Path(directory)
            (temp / 'shell.qml').write_text(qml)
            (temp / 'runtime').mkdir(mode=0o700)
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                       XDG_CONFIG_HOME=str(temp / 'config'), XDG_CACHE_HOME=str(temp / 'cache'),
                       XDG_STATE_HOME=str(temp / 'state'), XDG_RUNTIME_DIR=str(temp / 'runtime'))
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['quickshell', '-p', str(temp / 'shell.qml'), '--no-color'],
                                    env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('DECK_PAGINATION_PASS', output)
            self.assertNotIn('DECK_PAGINATION_FAIL', output)
