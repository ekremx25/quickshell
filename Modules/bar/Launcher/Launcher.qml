import QtQuick
import QtQuick.Layouts
import "."
import "../../../Widgets"

Rectangle {
    id: launcherRoot

    // --- SIGNAL ---
    signal settingsRequested()
    LauncherService { id: launcherService }

    // --- COLOR SETTINGS ---
    // --- COLOR SETTINGS ---
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
    border.width: 0
    // border.color: borderColor

    scale: launcherMouse.pressed ? 0.85 : (launcherMouse.containsMouse ? 1.15 : 1.0)

    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

    // Ripple effect
    Rectangle {
        id: ripple
        anchors.centerIn: parent
        width: 0; height: 0
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.35)
        opacity: 0

        ParallelAnimation {
            id: rippleAnim
            NumberAnimation { target: ripple; property: "width";   from: 0; to: 56; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: ripple; property: "height";  from: 0; to: 56; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: ripple; property: "opacity"; from: 0.35; to: 0; duration: 380; easing.type: Easing.OutCubic }
        }
    }

    // --- LOGO SETTINGS ---
    property string logo: ""

    // --- GENTOO ICON / CUSTOM LOGO ---
    
    // 1. Text Logo (if logo is text or empty/default)
    Text {
        anchors.centerIn: parent
        text: (launcherRoot.logo !== "" && launcherRoot.logo.indexOf("/") === -1 && launcherRoot.logo.indexOf(".") === -1) 
              ? launcherRoot.logo 
              : launcherService.distroIcon(launcherService.distroName)
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

    // --- CLICK AREA ---
    MouseArea {
        id: launcherMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: rippleAnim.restart()
        onClicked: launcherRoot.settingsRequested()
    }
}
