import QtQuick
import Quickshell
import "./Modules/bar" as BarUI
import "./Modules/bar/Dock" as Dock
import "./Modules/bar/Settings" as Settings
import "./Modules/bar/ModuleRegistry.js" as Registry
import "./Services" as S

ShellRoot {
    id: probe
    property var names: Registry.allNames()
    property int step: 0
    property int ticks: 0
    Settings.Settings { id: settings; visible: false }
    PanelWindow {
        id: window
        screen: Quickshell.screens[0]
        anchors { top: true; left: true; right: true }
        implicitHeight: 120
        BarUI.ModuleCatalog { id: catalog; screenData: window.screen; settingsMenu: settings }
        Loader { id: barSlot; sourceComponent: catalog.componentFor(probe.names[probe.step]) }
        Dock.DockModuleSlot {
            id: dockSlot
            y: 60
            modelData: probe.names[probe.step]
            moduleMap: {
                var map = {};
                for (var name in catalog.componentMap) map[name] = catalog.componentFor(name);
                return map;
            }
            dockScale: 1
            iconSize: 38
        }
    }
    Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            try {
                if (++probe.ticks > 300) throw new Error("module load timeout " + probe.names[probe.step]);
                if (!S.ScreenManager.screenPreferences.notifications) return;
                var loader = dockSlot.children[0];
                if (barSlot.status === Loader.Error || loader.status === Loader.Error) throw new Error("module failed " + probe.names[probe.step]);
                if (barSlot.status !== Loader.Ready || loader.status !== Loader.Ready) return;
                if (!barSlot.item || !loader.item || dockSlot.width <= 0 || dockSlot.height <= 0)
                    throw new Error("empty module " + probe.names[probe.step]);
                if (probe.step === probe.names.length - 1) {
                    console.log("SETTINGS_UI_PASS module_catalog"); Qt.quit();
                } else probe.step++;
            } catch(error) { console.error("SETTINGS_UI_FAIL module_catalog: " + error); Qt.exit(1); }
        }
    }
}
