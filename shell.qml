//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import "./Services"

import "./Modules/bar"
import "./Modules/bar/Notifications"
import "./Modules/bar/Weather"
import "./Modules/bar/Dock"
import "./Modules/bar/Tray"
import "./Modules/OSD"
import "./Modules/AppDrawer"

ShellRoot {
    Bar {}

    WeatherDesktop {}

    Dock {}

    Loader {
        id: toastLoader
        source: "Modules/bar/Notifications/Toast.qml"
        active: true
        
        Connections {
            target: Notifications
            function onPopupPositionChanged() {
                // Reload to update LayerShell anchors
                toastLoader.active = false;
                Qt.callLater(() => { toastLoader.active = true; });
            }
        }
    }

    Variants {
        model: ScreenManager.getFilteredScreens("osd")
        delegate: VolumeOSD {}
    }

    // Variants {
    //     model: ScreenManager.getFilteredScreens("appdrawer")
    //     delegate: AppDrawer {
    //         id: appDrawer
    //     }
    // }
}
