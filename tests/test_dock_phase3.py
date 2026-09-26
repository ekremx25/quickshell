"""Exercise production Dock fragments offscreen, without compositor processes."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DOCK = ROOT / "Modules/bar/Dock"


def block(source, marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 0
    quote = None
    escape = False
    comment = False
    for i in range(opening, len(source)):
        c = source[i]
        if comment:
            if c == "\n": comment = False
            continue
        if not quote and source[i:i + 2] == "//":
            comment = True
            continue
        if quote:
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return source[start:i + 1]
    raise AssertionError(marker)


@unittest.skipUnless(shutil.which("quickshell"), "Quickshell required")
class DockPhase3Tests(unittest.TestCase):
    def run_qml(self, body, fixture_files=None):
        scratch = ROOT / ".temp_files"
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch, prefix="dock-test-") as directory:
            temp = Path(directory)
            runtime = temp / "runtime"
            runtime.mkdir(mode=0o700)
            entry = temp / "shell.qml"
            imports = 'import QtQuick\nimport Quickshell\n'
            if fixture_files:
                for name, content in fixture_files.items(): (temp / name).write_text(content)
                imports += 'import "." as Local\n'
            imports += 'import "' + (DOCK / 'AppService.js').as_uri() + '" as AppService\n'
            helper = ROOT / "Services/core/DesktopMetadata.js"
            if helper.exists():
                imports += 'import "' + helper.as_uri() + '" as DesktopMetadata\n'
            entry.write_text(imports + 'ShellRoot {\nfunction check(v,m) { if (!v) throw new Error(m); }\n' + body + '\n}')
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(temp / "config"),
                       XDG_CACHE_HOME=str(temp / "cache"), XDG_STATE_HOME=str(temp / "state"))
            env.pop("WAYLAND_DISPLAY", None)
            result = subprocess.run(["quickshell", "-p", str(entry), "--no-color"], env=env,
                                    text=True, capture_output=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("DOCK_PASS", output)
            self.assertNotIn("DOCK_FAIL", output)
            self.assertNotIn("ReferenceError", output)

    def test_dolphin_tooltip_name(self):
        self.run_qml("""
            Component.onCompleted: {
                try {
                    for (var name of ["dolphin", "org.kde.dolphin", "Org.Kde.Dolphin"])
                        check(AppService.getAppName(name) === "Dolphin", "Dolphin label: " + name);
                    check(AppService.getAppName("nautilus") === "Dosyalar", "Nautilus unchanged");
                    check(AppService.getAppName("firefox") === "Firefox", "Firefox unchanged");
                    console.log("DOCK_PASS");
                } catch(e) { console.error("DOCK_FAIL " + e); }
                Qt.callLater(Qt.quit);
            }
        """)

    def test_metadata_consumers(self):
        for path in (DOCK / "DockDataService.qml", ROOT / "Services/WorkspaceService.qml"):
            with self.subTest(path=path.name):
                function = block(path.read_text(), "function parseDesktopMetadata(raw)")
                self.run_qml(function + r'''
    Component.onCompleted: {
        try {
            var icons = {app: 'icon } { " \\ end'};
            var commands = {app: 'echo "unmatched }"'};
            var entries = {app: {name: "{title", nested: [1, {value: "}"}]}};
            var raw = JSON.stringify(icons) + "\n" + JSON.stringify(commands) + "\n" + JSON.stringify(entries);
            var result = parseDesktopMetadata(raw);
            check(JSON.stringify(result.icons) === JSON.stringify(icons), "icons preserved");
            check(result.commands.app === commands.app, "command preserved");
            check(result.entries.app.name === "{title", "entries preserved");
            check(Object.keys(parseDesktopMetadata("{}").commands).length === 0, "legacy document");
            for (var bad of ["{}{}{" , "{}garbage", "[]", "{}{}{}{}"]) {
                var rejected = false;
                try { parseDesktopMetadata(bad); } catch(e) { rejected = true; }
                check(rejected, "invalid metadata accepted: " + bad);
            }
            console.log("DOCK_PASS");
        } catch(e) { console.error("DOCK_FAIL " + e); }
        Qt.callLater(Qt.quit);
    }''')

    def test_drag_uses_actual_slot_centers(self):
        source = (DOCK / "DockItem.qml").read_text()
        calculation = block(source, "if (dragStarted)")
        self.run_qml("""Item {
            id: itemRoot
            property real dockScale: 1.5
            property var panel: ({isHorizontal:true, dockItems:[{},{},{}], dragOverIndex:-1})
            property var row: null
            property var repeater: ({itemAt: function(i) { return slots[i]; }})
            property var slots: []
            property real cursorX: 0
            property real cursorY: 0
            function mapToItem(row,x,y) { return Qt.point(cursorX,cursorY); }
            function calculate() {
                var dragStarted = true;
                var mouse = {x:0,y:0};
                """ + calculation + """
                return panel.dragOverIndex;
            }
            Component.onCompleted: {
                try {
                    for (var horizontal of [true,false]) {
                        panel.isHorizontal = horizontal;
                        slots = [
                            {width:24,height:24,mapToItem:function() {return Qt.point(80,80);}},
                            {width:120,height:120,mapToItem:function() {return Qt.point(110,110);}},
                            {width:40,height:40,mapToItem:function() {return Qt.point(240,240);}}
                        ];
                        for (var pair of [[-100,0],[92,0],[170,1],[260,2],[999,2]]) {
                            cursorX = horizontal ? pair[0] : 0;
                            cursorY = horizontal ? 0 : pair[0];
                            check(calculate() === pair[1], "drag target " + horizontal + ":" + pair);
                        }
                    }
                    console.log("DOCK_PASS");
                } catch(e) { console.error("DOCK_FAIL " + e); }
                Qt.callLater(Qt.quit);
            }
        }""")

    def test_four_direction_layout(self):
        source = (DOCK / "Dock.qml").read_text()
        marker = "Grid {\n                id: dockRow" if "Grid {\n                id: dockRow" in source else "Row {\n                id: dockRow"
        grid = block(source, marker)
        # Keep production positioner and separators; replace service-backed app/module slots.
        grid = grid.replace("DockItem {", "TestSlot {").replace("DockModuleSlot {", "TestModule {")
        grid = grid.replace("DockSeparator {", "TestSeparator {")
        separator = (DOCK / "DockSeparator.qml").read_text().split("Rectangle {", 1)[1]
        dimensions = source[source.index("            implicitWidth: dockRow."):source.index("            radius: 14", source.index("            implicitWidth: dockRow."))]
        grid = re.sub(r"(?<![\w.])dockScale\b", "dockWindow.dockScale", grid)
        grid = grid.replace("dockWindow.dockScale:", "dockScale:")
        self.run_qml("""
    component TestSlot: Item {
        required property var modelData; required property int index
        property real dockScale; property var panel; property var backend
        property var repeater; property var row; property var content; property var moduleMap; property var settingsPopup
        width: index === 1 ? 100 * dockScale : panel.cfgIconSize * dockScale
        height: (panel.cfgIconSize + 8) * dockScale
    }
    component TestModule: Item {
        required property string modelData; property var moduleMap; property real dockScale; property real iconSize
        width: 70 * dockScale; height: (iconSize + 8) * dockScale
    }
    component TestSeparator: Rectangle {""" + separator + """
    QtObject { id: dockBackend }
    QtObject { id: settingsMenu }
    Window {
        id: testWindow
        visible: true; width: 900; height: 900
        property int scenario: 0
        Item {
            id: dockWindow
            property string cfgPosition: ["bottom", "top", "left", "right"][Math.floor(testWindow.scenario / 3)]
            property bool isHorizontal: cfgPosition === "bottom" || cfgPosition === "top"
            property real dockScale: [0.75,1,1.5][testWindow.scenario % 3]
            property real cfgIconSize: [24,28,40][testWindow.scenario % 3]
            property real cfgItemSpacing: [0,2,8][testWindow.scenario % 3]
            property real cfgPadding: 8
            property var leftModules: ["left"]
            property var rightModules: ["right"]
            property var dockItems: [{},{},{}]
            property var moduleMap: ({})
            Rectangle {
                id: dockContent
                property real dockScale: dockWindow.dockScale
                """ + dimensions + grid + """
            }
        }
        onAfterAnimating: {
            try {
                check(dockContent.width > 0 && dockContent.height > 0, "content dimensions");
                var first = dockRepeater.itemAt(0), second = dockRepeater.itemAt(1);
                check(!!first && !!second, "delegates ready");
                if (dockWindow.isHorizontal) check(second.x >= first.x + first.width, "horizontal order");
                else check(second.y >= first.y + first.height, "vertical order");
                for (var child of dockRow.children) {
                    if (!child.visible || child.width <= 0 || child.height <= 0) continue;
                    var pos = child.mapToItem(dockContent, 0, 0);
                    check(pos.x >= -0.5 && pos.y >= -0.5 && pos.x + child.width <= dockContent.width + 0.5 && pos.y + child.height <= dockContent.height + 0.5, "clipped slot " + scenario);
                }
                scenario++;
                if (scenario === 12) { console.log("DOCK_PASS"); Qt.quit(); }
            } catch(e) { console.error("DOCK_FAIL " + e); Qt.quit(); }
        }
    }
    Timer { interval: 3000; running: true; onTriggered: {console.error("DOCK_FAIL layout timeout"); Qt.quit();} }
""")

    def test_hide_modes(self):
        source = (DOCK / "Dock.qml").read_text()
        timer = block(source, "Timer {\n            id: hideCheckTimer").replace("S.WorkspaceService.state", "dockWindow.workspaceState")
        extra = re.search(r'property bool hideTrackingEnabled:.*', source).group(0)
        should_hide = block(source, "property bool shouldHide:")
        offset = re.search(r'property real hideOffset:.*', source).group(0)
        self.run_qml("""Item {
            id: dockWindow
            property var dockConfigData: ({autoHide:false})
            property bool cfgIntelligentHide: false
            property bool hasOverlappingWindow: false
            property bool dockContainsMouse: false
            property bool contextMenuVisible: false
            property bool isDragging: false
            property real dockThickness: 40
            property real dockScale: 1.5
            property real cfgBottomMargin: 5
            property var screen: ({name:"DP-1"})
            property var workspaceState: ({byMonitor:{"DP-1":{workspaces:[{is_active:true,winCount:1}]}}})
            """ + extra + '\n' + should_hide + '\n' + offset + '\n' + timer + """
            Component.onCompleted: Qt.callLater(checkModes)
            function checkModes() {
                try {
                    for (var normal of [false,true]) for (var smart of [false,true]) {
                        dockConfigData = {autoHide:normal}; cfgIntelligentHide = smart;
                        check(hideCheckTimer.running === (normal || smart), "timer mode");
                        hideCheckTimer.triggered();
                        check(shouldHide === (normal || smart), "active workspace hides");
                        if (shouldHide) check(dockThickness * dockScale + hideOffset === 2, "edge strip retained");
                        dockContainsMouse = true;
                        check(!shouldHide, "edge hover reveals immediately");
                        if (normal || smart) check(hideOffset === 0, "no dead gap after edge reveal");
                        dockContainsMouse = false;
                        contextMenuVisible = true; check(!shouldHide, "popup keeps dock visible");
                        contextMenuVisible = false;
                        isDragging = true; check(!shouldHide, "drag keeps dock visible"); isDragging = false;
                    }
                    workspaceState = {byMonitor:{"DP-1":{workspaces:[{is_active:true,winCount:0},{is_active:false,winCount:3}]}, "DP-2":{workspaces:[{is_active:true,winCount:5}]}}};
                    hideCheckTimer.triggered(); check(!shouldHide, "other workspace/display ignored");
                    screen = {name:"DP-2"}; hideCheckTimer.triggered(); check(shouldHide, "own active display counted");
                    screen = {name:"missing"}; hideCheckTimer.triggered(); check(!shouldHide, "unknown screen stays visible");
                    console.log("DOCK_PASS");
                } catch(e) { console.error("DOCK_FAIL " + e); }
                Qt.callLater(Qt.quit);
            }
        }""")

    def test_real_popup_components_anchor_in_all_directions(self):
        files = {name:(DOCK / name).read_text().replace('import "../../../Widgets"', 'import "."')
                 for name in ('DockPopup.qml','DockTooltip.qml','DockContextMenu.qml')}
        files['qmldir'] = 'singleton Theme 1.0 Theme.qml\n' + ''.join(name[:-4] + ' 1.0 ' + name + '\n' for name in files if name.endswith('.qml'))
        files['Theme.qml'] = '''pragma Singleton
import QtQuick
QtObject {
 property color primary: "#88aaff"; property color background: "#111111"
 property color surface: "#333333"; property color text: "#eeeeee"; property color red: "#ff8888"
 property string fontFamily: "Sans Serif"
 function withAlpha(c,a) {return Qt.rgba(c.r,c.g,c.b,a);}
}'''
        self.run_qml("""
        QtObject {id: testBackend; function pinApp(id) {} function unpinApp(id) {} function closeWindow(id) {}}
        QtObject {id: settings; property string currentPage: ""; property bool visible: false}
        Window {
            id: host; visible:true; width:640; height:480
            property string position: "bottom"
            Item {id: targetItem; x:300; y:200; width:40; height:40}
            Local.DockTooltip {id: tip; anchorItem: targetItem; dockPosition:host.position; shown:true; dockScale:1; label:"Application with a very long title that must be bounded"}
            Local.DockContextMenu {id: menu; anchorItem: targetItem; dockPosition:host.position; shown:true; dockScale:1; backend: testBackend; settingsPopup:settings; modelData:({isPinned:true,isRunning:true,appId:"test",windowId:1})}
            Component.onCompleted: Qt.callLater(verifyPopups)
            function verifyPopups() {
                try {
                  for (var step=0; step<4; step++) {
                    position = ["bottom","top","left","right"][step];
                    var expected=[Edges.Top,Edges.Bottom,Edges.Right,Edges.Left][step];
                    check(tip.anchor.edges === expected && menu.anchor.edges === expected, "popup direction");
                    check(tip.anchor.gravity === expected && menu.anchor.gravity === expected, "popup gravity");
                    check(tip.anchor.item === targetItem && menu.anchor.item === targetItem, "real anchor item");
                    check(tip.width > 0 && tip.width <= 360 && menu.width > 0 && menu.height > 0, "popup dimensions");
                    check(menu.anchor.adjustment === (PopupAdjustment.Slide | PopupAdjustment.Flip), "screen constraints enabled");
                  }
                  console.log("DOCK_PASS"); Qt.quit();
                } catch(e) {console.error("DOCK_FAIL " + e); Qt.quit();}
            }
        }
        Timer {interval:3000;running:true;onTriggered:{console.error("DOCK_FAIL timeout");Qt.quit();}}
        """, files)

if __name__ == "__main__":
    unittest.main()
