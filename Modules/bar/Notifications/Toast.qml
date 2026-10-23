import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S
import "../Dock" as DockParts

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

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
        var style = S.EffectSettings.toastStyle;
        if (style === "elastic") elasticEnterAnim.restart();
        else if (style === "classic") plainEnterAnim.restart();
        else enterAnim.restart();
    }

    // --- EXIT ---
    function playExit(callback) {
        exitAnim.onFinishedCallback = callback;
        exitAnim.restart();
    }

    // Entrance styles from Settings → Effects, all scaled by the animation speed.
    readonly property real springScale: Math.max(0.25, S.EffectSettings.speed) * Math.max(0.25, S.EffectSettings.speed)

    // Spring: overshoots and settles like a physical card.
    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: mainRect;  property: "opacity"; from: 0;    to: 1;    duration: S.EffectSettings.ms(320); easing.type: Easing.OutCubic }
        SpringAnimation { target: mainRect;  property: "scale";   from: 0.82; to: 1.0;  spring: 4.0 * root.springScale; damping: 0.28; epsilon: 0.002 }
        SpringAnimation { target: slideX;    property: "x";       to: 0;                spring: 3.2 * root.springScale; damping: 0.24; epsilon: 0.25 }
        SpringAnimation { target: slideY;    property: "y";       to: 0;                spring: 3.2 * root.springScale; damping: 0.30; epsilon: 0.25 }
    }

    // Elastic: snaps in and rings a few times like a rubber band.
    ParallelAnimation {
        id: elasticEnterAnim
        NumberAnimation { target: mainRect;  property: "opacity"; from: 0;    to: 1;    duration: S.EffectSettings.ms(260); easing.type: Easing.OutCubic }
        NumberAnimation { target: mainRect;  property: "scale";   from: 0.7;  to: 1.0;  duration: S.EffectSettings.ms(900); easing.type: Easing.OutElastic; easing.amplitude: 1.0; easing.period: 0.45 }
        NumberAnimation { target: slideX;    property: "x";       to: 0;                duration: S.EffectSettings.ms(900); easing.type: Easing.OutElastic; easing.amplitude: 1.0; easing.period: 0.5 }
        NumberAnimation { target: slideY;    property: "y";       to: 0;                duration: S.EffectSettings.ms(600); easing.type: Easing.OutCubic }
    }

    // Classic: the original eased slide.
    ParallelAnimation {
        id: plainEnterAnim
        NumberAnimation { target: mainRect;  property: "opacity"; from: 0;    to: 1;    duration: S.EffectSettings.ms(380); easing.type: Easing.OutCubic }
        NumberAnimation { target: mainRect;  property: "scale";   from: 0.82; to: 1.0;  duration: S.EffectSettings.ms(420); easing.type: Easing.OutBack }
        NumberAnimation { target: slideX;    property: "x";       to: 0;                duration: S.EffectSettings.ms(400); easing.type: Easing.OutBack }
        NumberAnimation { target: slideY;    property: "y";       to: 0;                duration: S.EffectSettings.ms(380); easing.type: Easing.OutCubic }
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
        color: S.EffectSettings.liquidGlass ? "transparent" : Theme.background
        radius: Theme.radius
        border.width: S.EffectSettings.liquidGlass ? 0 : 1
        border.color: Theme.surface
        opacity: 0
        scale: 0.82

        transform: [
            Translate { id: slideX; x: root.slideStartX },
            Translate { id: slideY; y: 0 }
        ]

        // Frosted glass background. ExclusionMode.Ignore means the window sits
        // exactly at its anchors + margins, so the screen position is known.
        Loader {
            anchors.fill: parent
            z: -1
            active: S.EffectSettings.liquidGlass && root.visible
            sourceComponent: DockParts.LiquidGlass {
                readonly property bool anchoredLeft: root.notifService.popupPosition === 2 || root.notifService.popupPosition === 6
                readonly property bool anchoredRight: root.notifService.popupPosition === 1 || root.notifService.popupPosition === 5
                screen: root.screen
                screenX: (anchoredLeft ? 20 : anchoredRight ? root.screen.width - 20 - root.width
                          : (root.screen.width - root.width) / 2) + slideX.x
                screenY: (root.isBottom ? root.screen.height - 60 - root.height : 60) + slideY.y
                radius: mainRect.radius
                refraction: 12
                edgeWidth: 12
                blurRadius: 14
                tint: Theme.background
                tintStrength: 0.45
                hovered: toastHover.hovered && S.EffectSettings.glassDroplet
                pointerX: toastHover.point.position.x
                pointerY: toastHover.point.position.y
            }
        }

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
                    font.family: Theme.fontFamily
                    text: currentNotif ? currentNotif.appName : "System"
                    font.bold: true; font.pixelSize: 11
                    color: Theme.subtext
                }

                Text {
                    font.family: Theme.fontFamily
                    text: currentNotif ? (notifService.privacyMode ? "New notification" : currentNotif.summary) : ""
                    font.bold: true; font.pixelSize: 13
                    color: Theme.text
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    font.family: Theme.fontFamily
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
