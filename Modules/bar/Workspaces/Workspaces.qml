import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services"

Rectangle {
    id: workspaceRoot
    required property string monitorName
    property var config: ({
        format: "roman",
        style: "square",
        transparent: true,
        displayMode: "role",
        workspaceCount: 5,
        showEmpty: true,
        showSpecial: true,
        wrapAround: true,
        reverseScroll: false,
        maxIcons: 4
    })
    property string style: config.style || "fill"
    property bool isTransparent: config.transparent === true
    property color activeColor: Theme.workspacesColor
    property int workspaceRevision: WorkspaceService.revision
    property var activeWorkspaces: {
        var currentRevision = workspaceRoot.workspaceRevision
        return WorkspaceService.workspacesForMonitor(workspaceRoot.monitorName, workspaceRoot.config)
    }

    // Read DMS properties from bar_config.json
    property bool showApps: config.showApps !== false
    property bool groupApps: config.groupApps !== false
    property bool scrollEnabled: config.scrollEnabled !== false
    property int iconSize: config.iconSize || 20
    property int maxIcons: Math.max(1, Math.min(12, config.maxIcons || 4))

    // Mouse scroll accumulator
    property real mouseAccumulator: 0
    property bool scrollInProgress: false

    Timer {
        id: scrollCooldown
        interval: 100
        onTriggered: workspaceRoot.scrollInProgress = false
    }

    // Main background transparent
    color: "transparent"
    border.width: 0

    implicitHeight: 34
    implicitWidth: wsRow.implicitWidth

    // --- FORMAT CONVERTER ---
    function getWorkspaceLabel(numStr) {
        var fmt = config.format || "chinese";

        if (fmt === "roman") {
            var romans = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"];
            var n = parseInt(numStr);
            if (!isNaN(n) && n >= 1 && n <= 10) return romans[n];
            return numStr;
        }

        if (fmt === "chinese") {
            var map = {
                "1": "一", "2": "二", "3": "三", "4": "四", "5": "五",
                "6": "六", "7": "七", "8": "八", "9": "九", "10": "十"
            };
            return map[numStr] || numStr;
        }

        // Arabic (Default fallback)
        return numStr;
    }

    function switchToWorkspace(targetName) {
        WorkspaceService.activateWorkspace(workspaceRoot.monitorName, targetName);
    }

    function scrollWorkspaces(direction) {
        if (!workspaceRoot.scrollEnabled) return;
        var wss = workspaceRoot.activeWorkspaces.filter(function(workspace) {
            return !workspace.is_special && /^\d+$/.test(String(workspace.name || ""));
        });
        if (wss.length < 2) return;

        var currentIndex = wss.findIndex(w => w.is_active);
        var validIndex = currentIndex === -1 ? 0 : currentIndex;
        var nextIndex = WorkspaceService.nextWorkspaceIndex(wss, validIndex, direction, workspaceRoot.config);

        if (nextIndex !== validIndex) {
            switchToWorkspace(wss[nextIndex].name);
        }
    }

    // Scroll Area
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: wheel => {
            if (!workspaceRoot.scrollEnabled || scrollInProgress) return;

            var delta = wheel.angleDelta.y;
            workspaceRoot.mouseAccumulator += delta;
            if (Math.abs(workspaceRoot.mouseAccumulator) < 120) return;
            var direction = workspaceRoot.mouseAccumulator < 0 ? 1 : -1;
            workspaceRoot.scrollWorkspaces(direction);

            workspaceRoot.scrollInProgress = true;
            scrollCooldown.restart();
            workspaceRoot.mouseAccumulator = 0;
        }
    }

    // --- VISUAL LAYOUT (Professional Glassmorphism Design) ---
    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: workspaceRoot.activeWorkspaces
            delegate: Rectangle {
                id: wsBox
                property var wsData: modelData
                property bool isActive: wsData.is_active
                property int winCount: wsData.winCount
                property var visibleApps: (wsData.groupedWindows || []).slice(0, workspaceRoot.maxIcons)
                property int hiddenAppCount: Math.max(0, (wsData.groupedWindows || []).length - visibleApps.length)
                property bool isHovered: workspaceHover.hovered

                // Label toggle state
                // Workspace numbers must remain visible for every workspace.
                property bool labelVisible: true
                property bool labelForced: false
                property bool showLabel: labelVisible || labelForced

                Timer {
                    id: labelHideTimer
                    interval: 2000
                    onTriggered: wsBox.labelForced = false
                }

                // Size
                implicitWidth: wsContentRow.implicitWidth + 22
                height: 34
                radius: style === "square" ? 8 : 17

                // Hover scale
                scale: isHovered ? 1.05 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                // --- GLASSMORPHISM BACKGROUND ---
                color: {
                    if (isActive) return Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.25)
                    if (isHovered) return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                    return Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.15)
                }

                border.width: 1
                border.color: {
                    if (isActive) return Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.45)
                    if (isHovered) return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
                    return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
                }

                Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on implicitWidth { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                // --- GLOW LAYERS (behind box, active only) ---
                Rectangle {
                    z: -2
                    anchors.centerIn: parent
                    width: parent.implicitWidth + 6
                    height: parent.height + 6
                    radius: parent.radius + 3
                    color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.12)
                    visible: isActive
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    z: -3
                    anchors.centerIn: parent
                    width: parent.implicitWidth + 12
                    height: parent.height + 12
                    radius: parent.radius + 6
                    color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.06)
                    visible: isActive
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                }

                // Glass top-edge highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: 1
                    radius: parent.radius
                    color: Qt.rgba(1, 1, 1, isActive ? 0.12 : 0.05)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // --- CONTENT ROW ---
                Row {
                    id: wsContentRow
                    anchors.centerIn: parent
                    spacing: 7

                    // Minimal dot indicator (when label is hidden)
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !wsBox.showLabel
                        color: {
                            if (isActive) return activeColor
                            if (winCount > 0) return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.4)
                            return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.15)
                        }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    // Workspace label (animated)
                    Text {
                        id: labelText
                        visible: wsBox.showLabel
                        text: getWorkspaceLabel(wsData.name)
                        color: isActive ? Theme.workspaceActiveTextColor : Theme.text
                        font.bold: true
                        font.pixelSize: 13
                        font.family: Theme.fontFamily
                        font.letterSpacing: 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: wsBox.showLabel ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }

                    // Gradient separator
                    Rectangle {
                        width: 1
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: winCount > 0 && workspaceRoot.showApps && wsBox.showLabel
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.3; color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25) }
                            GradientStop { position: 0.7; color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // APPLICATION ICONS
                    Row {
                        spacing: 5
                        anchors.verticalCenter: parent.verticalCenter
                        visible: winCount > 0 && workspaceRoot.showApps

                        Repeater {
                            model: wsBox.visibleApps

                            Item {
                                width: appIconText.implicitWidth
                                height: workspaceRoot.iconSize + 4

                                Text {
                                    id: appIconText
                                    text: modelData.icon
                                    color: {
                                        if (isActive && modelData.active) return Theme.workspaceActiveTextColor
                                        if (modelData.active) return Theme.primary
                                        if (isActive) return Qt.rgba(Theme.workspaceActiveTextColor.r, Theme.workspaceActiveTextColor.g, Theme.workspaceActiveTextColor.b, 0.85)
                                        return Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.7)
                                    }
                                    font.pixelSize: workspaceRoot.iconSize
                                    font.family: "JetBrainsMono Nerd Font"
                                    anchors.centerIn: parent
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !!modelData.windowId
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: mouse => {
                                        mouse.accepted = true
                                        WorkspaceService.focusWindow(modelData.windowId)
                                    }
                                }

                                // Grouping bubble (modern pill)
                                Rectangle {
                                    visible: (modelData.count !== undefined && modelData.count > 1) && !isActive
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.2)
                                    border.color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.4)
                                    border.width: 1
                                    anchors.right: parent.right
                                    anchors.rightMargin: -5
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -2
                                    z: 2

                                    Text {
                                        font.family: Theme.fontFamily
                                        anchors.centerIn: parent
                                        text: modelData.count !== undefined ? String(modelData.count) : ""
                                        font.pixelSize: 8
                                        font.bold: true
                                        color: Theme.text
                                    }
                                }
                            }
                        }

                        // Hidden app count pill
                        Rectangle {
                            visible: wsBox.hiddenAppCount > 0
                            width: hiddenCountText.implicitWidth + 8
                            height: 16
                            radius: 8
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: hiddenCountText
                                text: "+" + wsBox.hiddenAppCount
                                color: isActive ? Theme.workspaceActiveTextColor : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.7)
                                font.pixelSize: Math.max(9, workspaceRoot.iconSize - 7)
                                font.bold: true
                                font.family: Theme.fontFamily
                                anchors.centerIn: parent
                            }
                        }
                    }
                }

                // --- UNDERLINE STYLE ---
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: isActive ? parent.implicitWidth * 0.5 : 0
                    height: 2.5
                    radius: 1.25
                    color: activeColor
                    visible: style === "underline"
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // --- DOT STYLE ---
                Rectangle {
                    anchors.top: parent.bottom
                    anchors.topMargin: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: isActive ? 5 : 3
                    height: isActive ? 5 : 3
                    radius: width / 2
                    color: activeColor
                    visible: style === "dot"
                    opacity: isActive ? 1.0 : 0.3
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // --- OVERLINE STYLE ---
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: isActive ? parent.implicitWidth * 0.5 : 0
                    height: 2.5
                    radius: 1.25
                    color: activeColor
                    visible: style === "overline"
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // --- PIPE STYLE ---
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 3
                    width: 2.5
                    height: isActive ? parent.height * 0.55 : 0
                    radius: 1.25
                    color: activeColor
                    visible: style === "pipe"
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // --- CLICK AREA ---
                MouseArea {
                    z: 1
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!wsBox.isActive) {
                            workspaceRoot.switchToWorkspace(wsData.name)
                        }
                        wsBox.labelForced = !wsBox.labelForced
                        if (wsBox.labelForced) {
                            labelHideTimer.restart()
                        } else {
                            labelHideTimer.stop()
                        }
                    }
                }

                HoverHandler { id: workspaceHover }
            }
        }
    }
}
