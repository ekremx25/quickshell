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

// Sıralı (staged) yükleme stratejisi:
//
//  Aşama 1 (anında) : ShellBootstrap + Bar
//    → Monitör konfigürasyonu uygulanır, bar hemen görünür.
//
//  Aşama 2 (300ms)  : EqBootstrap + MouseBootstrap
//    → Equalizer ve mouse servisleri arka planda başlar.
//
//  Aşama 3 (600ms)  : Dock + WeatherDesktop + ToastHost + OSD
//    → Görsel eklentiler ilk frame'den sonra yüklenir.
//
// Bu yaklaşım başlangıç yükünü dağıtarak ilk görünür kareyi hızlandırır.
ShellRoot {

    // ── Aşama 1: Kritik servis + Bar (anında) ────────────────────────
    Loader {
        active: true
        source: "Services/ShellBootstrap.qml"
    }

    Bar {}

    // ── Aşama 2: Arka plan servisleri (300ms sonra) ───────────────────
    Loader { id: eqLoader;    active: false; source: "Services/EqBootstrap.qml"    }
    Loader { id: mouseLoader; active: false; source: "Services/MouseBootstrap.qml" }

    // ── Aşama 3: Görsel bileşenler (600ms sonra) ─────────────────────
    Loader { id: dockLoader;    active: false; sourceComponent: dockComp    }
    Loader { id: weatherLoader; active: false; sourceComponent: weatherComp }
    Loader { id: toastLoader;   active: false; source: "Modules/bar/Notifications/ToastHost.qml" }
    Loader { id: osdLoader;     active: false; sourceComponent: osdComp     }

    // Bileşen tanımları
    Component { id: dockComp;    Dock {}           }
    Component { id: weatherComp; WeatherDesktop {} }
    Component {
        id: osdComp
        Variants {
            model: ScreenManager.getFilteredScreens("osd")
            delegate: VolumeOSD {}
        }
    }

    // Aşama 2 zamanlayıcısı
    Timer {
        interval: 300
        repeat: false
        running: true
        onTriggered: {
            eqLoader.active    = true;
            mouseLoader.active = true;
        }
    }

    // Aşama 3 zamanlayıcısı
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
