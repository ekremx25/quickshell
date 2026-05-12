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

// Staged loading strategy:
//
//  Stage 1 (immediate) : ShellBootstrap + Bar
//    → Monitor configuration applied, bar becomes visible immediately.
//
//  Stage 2 (300ms)     : EqBootstrap + MouseBootstrap
//    → Equalizer and mouse services start in the background.
//
//  Stage 3 (600ms)     : Dock + WeatherDesktop + ToastHost + OSD
//    → Visual extensions load after the first frame.
//
// This approach spreads the startup cost to speed up the first visible frame.
ShellRoot {

    // ── Stage 1: critical services + Bar (immediate) ─────────────────
    Loader {
        active: true
        source: "Services/ShellBootstrap.qml"
    }

    Bar {}

    // ── Stage 2: background services (after 300ms) ───────────────────
    Loader { id: eqLoader;    active: false; source: "Services/EqBootstrap.qml"    }
    Loader { id: mouseLoader; active: false; source: "Services/MouseBootstrap.qml" }

    // ── Stage 3: visual components (after 600ms) ─────────────────────
    Loader { id: dockLoader;    active: false; sourceComponent: dockComp    }
    Loader { id: weatherLoader; active: false; sourceComponent: weatherComp }
    Loader { id: toastLoader;   active: false; source: "Modules/bar/Notifications/ToastHost.qml" }
    Loader { id: osdLoader;     active: false; sourceComponent: osdComp     }

    // Component definitions
    Component { id: dockComp;    Dock {}           }
    Component { id: weatherComp; WeatherDesktop {} }
    Component {
        id: osdComp
        Variants {
            model: ScreenManager.getFilteredScreens("osd")
            delegate: VolumeOSD {}
        }
    }

    // Stage 2 timer
    Timer {
        interval: 300
        repeat: false
        running: true
        onTriggered: {
            eqLoader.active    = true;
            mouseLoader.active = true;
        }
    }

    // Stage 3 timer
    Timer {
        interval: 600
        repeat: false
        running: true
        onTriggered: {
            dockLoader.active    = true;
            weatherLoader.active = true;
            toastLoader.active   = true;
            osdLoader.active     = true;
        }
    }
}
