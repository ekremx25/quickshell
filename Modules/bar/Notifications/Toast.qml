import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S

PanelWindow {
    id: root

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "toast-notification"

    implicitWidth: mainRect.width
    implicitHeight: mainRect.height

    anchors {
        top:    notifService.popupPosition === 1 || notifService.popupPosition === 2 || notifService.popupPosition === 3
        bottom: notifService.popupPosition === 4 || notifService.popupPosition === 5 || notifService.popupPosition === 6
        left:   notifService.popupPosition === 2 || notifService.popupPosition === 6
        right:  notifService.popupPosition === 1 || notifService.popupPosition === 5
    }
    margins { top: 60; bottom: 60; left: 20; right: 20 }

    visible: false
    exclusionMode: ExclusionMode.Ignore

    property var notifService: S.Notifications
    property var currentNotif: null

    // Entry direction based on position
    readonly property bool isLeft:   notifService.popupPosition === 2 || notifService.popupPosition === 6
    readonly property bool isBottom: notifService.popupPosition === 4 || notifService.popupPosition === 5 || notifService.popupPosition === 6

    // --- Animation sources ---
    property real slideStartX: isLeft ? -360 : 360
    property real slideStartY: isBottom ? 80 : -80

    // --- ENTER ---
    function playEnter() {
        mainRect.opacity = 0;
        mainRect.scale   = 0.82;
        slideX.x = slideStartX;
        slideY.y = slideStartY * 0.4;
        enterAnim.restart();
    }

    // --- EXIT ---
    function playExit(callback) {
        exitAnim.onFinishedCallback = callback;
        exitAnim.restart();
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: mainRect;  property: "opacity"; from: 0;    to: 1;    duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { target: mainRect;  property: "scale";   from: 0.82; to: 1.0;  duration: 420; easing.type: Easing.OutBack }
        NumberAnimation { target: slideX;    property: "x";       to: 0;                duration: 400; easing.type: Easing.OutBack }
        NumberAnimation { target: slideY;    property: "y";       to: 0;                duration: 380; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: exitAnim
        property var onFinishedCallback: null
        NumberAnimation { target: mainRect; property: "opacity"; to: 0;             duration: 260; easing.type: Easing.InCubic }
        NumberAnimation { target: mainRect; property: "scale";   to: 0.88;          duration: 260; easing.type: Easing.InCubic }
        NumberAnimation { target: slideX;   property: "x"; to: root.slideStartX * 0.6; duration: 260; easing.type: Easing.InCubic }
        onFinished: {
            root.visible = false;
            if (onFinishedCallback) onFinishedCallback();
        }
    }

    // --- CONNECTIONS ---
    Connections {
        target: notifService
        function onNewNotificationReceived(notif) {
            if (!notif.closed && !notifService.dnd) {
                currentNotif = notif;
                root.visible = true;
                hideTimer.restart();
                root.playEnter();
            }
        }
    }

    Timer {
        id: hideTimer
        interval: root.notifService.displayDuration
        repeat: false
        onTriggered: root.playExit(null)
    }

    // --- UI ---
    Rectangle {
        id: mainRect
        width: 320
        height: Math.min(content.implicitHeight + 24, 200)
        color: Theme.background
        radius: Theme.radius
        border.width: 1
        border.color: Theme.surface
        opacity: 0
        scale: 0.82

        transform: [
            Translate { id: slideX; x: root.slideStartX },
            Translate { id: slideY; y: 0 }
        ]

        // Hover: stop the timer
        HoverHandler {
            id: toastHover
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    // Slight shine
                    hoverAnim.start();
                } else {
                    hideTimer.restart();
                    unhoverAnim.start();
                }
            }
        }

        NumberAnimation { id: hoverAnim;   target: mainRect; property: "scale"; to: 1.03; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { id: unhoverAnim; target: mainRect; property: "scale"; to: 1.0;  duration: 180; easing.type: Easing.OutCubic }

        // Close on click
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            z: 1
            onClicked: {
                hideTimer.stop();
                root.playExit(function() {
                    if (currentNotif && currentNotif.appName)
                        notifService.focusApp(currentNotif.appName);
                });
            }
        }

        // Close button
        Text {
            anchors { top: parent.top; right: parent.right; margins: 8 }
            text: ""
            font.family: Theme.fontFamily
            color: Theme.subtext
            z: 10
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { hideTimer.stop(); root.playExit(null); }
            }
        }

        RowLayout {
            id: content
            anchors { left: parent.left; top: parent.top; right: parent.right; margins: 12 }
            spacing: 12

            // Icon
            Rectangle {
                width: 40; height: 40; radius: 10
                color: Theme.base
                clip: true

                Image {
                    anchors.fill: parent
                    source: (currentNotif && currentNotif.appIcon) ? currentNotif.appIcon : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source != ""
                }

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    color: Theme.text
                    visible: !((currentNotif && currentNotif.appIcon) && currentNotif.appIcon != "")
                }
            }

            // Content
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: currentNotif ? currentNotif.appName : "System"
                    font.bold: true; font.pixelSize: 11
                    color: Theme.subtext
                }

                Text {
                    text: currentNotif ? (notifService.privacyMode ? "New notification" : currentNotif.summary) : ""
                    font.bold: true; font.pixelSize: 13
                    color: Theme.text
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    text: currentNotif ? (notifService.privacyMode ? "Content hidden" : currentNotif.body) : ""
                    font.pixelSize: 12
                    color: Theme.subtext
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    maximumLineCount: notifService.compactMode ? 1 : 3
                    elide: Text.ElideRight
                }
            }
        }

        // Progress bar (duration indicator)
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left }
            height: 3
            radius: 1.5
            color: Theme.primary
            width: root.visible ? parent.width : 0
            Behavior on width {
                enabled: root.visible
                NumberAnimation { duration: root.notifService.displayDuration; easing.type: Easing.Linear }
            }
        }
    }
}
