import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../../../Services"

Rectangle {
    id: launcherRoot

    // --- SİNYAL ---
    signal settingsRequested()

    // --- RENK AYARLARI ---
    // --- RENK AYARLARI ---
    property color containerColor: Theme.launcherColor
    property color hoverColor: Qt.lighter(containerColor, 1.1)
    property color iconColor: Theme.launcherIconColor
    property color borderColor: "#ccd0da" // border color unused? or keep?

    width: 34
    height: 34
    implicitWidth: 34
    implicitHeight: 34
    radius: 17
    color: launcherMouse.containsMouse ? hoverColor : containerColor
    border.width: 0 // Remove border to match Power button style? Power has no border.
    // border.color: borderColor

    Behavior on color { ColorAnimation { duration: 200 } }

    // --- ROFI KOMUTU ---
    // --- ROFI KOMUTU ---
    // --- PROCESS ---
    Process {
        id: distroProc
        command: ["sh", "-c", "grep '^PRETTY_NAME=' /etc/os-release | cut -d'\"' -f2"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { distroProc.buf = data.trim(); } }
        running: true
    }

    function getDistroIcon(name) {
        if (!name) return "\ue712"; // Generic Tux
        var n = name.toLowerCase();
        if (n.indexOf("gentoo") !== -1) return "\ue7e6";
        if (n.indexOf("fedora") !== -1) return "\ue7d9";
        if (n.indexOf("ubuntu") !== -1) return "\uef72";
        if (n.indexOf("debian") !== -1) return "\ue77d";
        if (n.indexOf("arch") !== -1) return "\uf31e";
        if (n.indexOf("nixos") !== -1) return "\ue843";
        if (n.indexOf("opensuse") !== -1) return "\uf314";
        if (n.indexOf("linux mint") !== -1) return "\uf30e";
        if (n.indexOf("elementary") !== -1) return "\uf309";
        return "\ue712"; // Generic Tux
    }

    // --- LOGO SETTINGS ---
    property string logo: ""

    // --- GENTOO İKONU / CUSTOM LOGO ---
    
    // 1. Text Logo (if logo is text or empty/default)
    Text {
        anchors.centerIn: parent
        text: (launcherRoot.logo !== "" && launcherRoot.logo.indexOf("/") === -1 && launcherRoot.logo.indexOf(".") === -1) 
              ? launcherRoot.logo 
              : getDistroIcon(distroProc.buf)
        visible: !imgLogo.visible
        color: iconColor
        font.pixelSize: 18
        font.family: "JetBrainsMono Nerd Font"
        anchors.verticalCenterOffset: 1
    }

    // 2. Image Logo (if logo is a file path)
    Image {
        id: imgLogo
        anchors.centerIn: parent
        source: (launcherRoot.logo !== "" && (launcherRoot.logo.indexOf("/") !== -1 || launcherRoot.logo.indexOf(".") !== -1))
                ? (launcherRoot.logo.indexOf("file://") === 0 ? launcherRoot.logo : "file://" + launcherRoot.logo)
                : ""
        visible: source !== "" && status === Image.Ready
        width: 20
        height: 20
        fillMode: Image.PreserveAspectFit
    }

    // --- TIKLAMA ALANI ---
    MouseArea {
        id: launcherMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                launcherRoot.settingsRequested();
            } else if (mouse.button === Qt.RightButton) {
                launcherRoot.settingsRequested();
            }
        }
    }
}

