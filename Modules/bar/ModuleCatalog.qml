import QtQuick
import "ModuleRegistry.js" as ModuleRegistry
import "../../Services/core/Log.js" as Log

import "./Launcher"
import "./Workspaces"
import "./Tray"
import "./SysInfo"
import "./Volume"
import "./power"
import "./Calendar"
import "./Notepad"
import "./Weather"
import "./Notifications"
import "./Clipboard"
import "./Equalizer"
import "./NightLight"
import "./Group"
import "./Dock"

// Visual factory paired with ModuleRegistry.js. Context-sensitive properties
// (monitor, workspace preferences, launcher settings, dock scale) are injected
// here once instead of being duplicated by Bar.qml and Dock.qml.
Item {
    id: catalog

    visible: false
    width: 0
    height: 0

    property var screenData: null
    property var workspacesConfig: ({})
    property string launcherLogo: ""
    property var settingsMenu: null
    property real dockScale: 1.0
    property var healthReport: ({
        valid: false,
        errors: ["Catalog validation has not run."],
        warnings: []
    })

    readonly property int schemaVersion: ModuleRegistry.schemaVersion()
    readonly property var definitions: ModuleRegistry.definitions()
    readonly property var componentMap: ({
        "Launcher": launcherComp,
        "Calendar": calendarComp,
        "Notepad": notepadComp,
        "Workspaces": workspacesComp,
        "Notifications": notificationsComp,
        "Weather": weatherComp,
        "Volume": volumeComp,
        "Equalizer": equalizerComp,
        "Tray": trayComp,
        "Clipboard": clipboardComp,
        "Power": powerComp,
        "NightLight": nightLightComp,
        "PowerGroup": powerGroupComp,
        "SysInfoGroup": sysInfoGroupComp,
        "RamModule": ramModuleComp,
        "Media": mediaComp
    })

    function componentFor(name) {
        var canonical = ModuleRegistry.canonicalName(name);
        return catalog.componentMap[canonical] || null;
    }

    function validateCatalog() {
        var report = ModuleRegistry.validateCatalog(catalog.componentMap);
        catalog.healthReport = report;

        for (var i = 0; i < report.errors.length; ++i) {
            Log.error("ModuleCatalog", report.errors[i]);
        }
        for (var j = 0; j < report.warnings.length; ++j) {
            Log.warn("ModuleCatalog", report.warnings[j]);
        }
        if (report.valid) {
            Log.debug("ModuleCatalog", "Registry/catalog contract valid (schema "
                + catalog.schemaVersion + ", " + report.registryCount + " modules).");
        }
        return report.valid;
    }

    Component.onCompleted: validateCatalog()

    Component {
        id: launcherComp
        Launcher {
            logo: catalog.launcherLogo
            onSettingsRequested: {
                if (catalog.settingsMenu) {
                    catalog.settingsMenu.visible = !catalog.settingsMenu.visible;
                }
            }
        }
    }

    Component { id: calendarComp; Calendar {} }
    Component { id: notepadComp; Notepad {} }
    Component { id: notificationsComp; Notifications {} }
    Component { id: weatherComp; Weather {} }
    Component { id: volumeComp; Volume {} }
    Component { id: equalizerComp; Equalizer {} }
    Component { id: trayComp; Tray {} }
    Component { id: clipboardComp; Clipboard {} }
    Component { id: powerComp; Power {} }
    Component { id: nightLightComp; NightLight {} }
    Component { id: powerGroupComp; PowerGroup {} }
    Component { id: sysInfoGroupComp; SysInfoGroup {} }
    Component { id: ramModuleComp; RamModule {} }

    Component {
        id: workspacesComp
        Workspaces {
            monitorName: catalog.screenData && catalog.screenData.name
                ? catalog.screenData.name
                : ""
            config: catalog.workspacesConfig
        }
    }

    Component {
        id: mediaComp
        MediaWidget {
            dockScale: catalog.dockScale
        }
    }
}
