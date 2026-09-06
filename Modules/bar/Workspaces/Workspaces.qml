import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services"
import "../BarDefaults.js" as BarDefaults
import "WorkspaceAppearance.js" as Appearance

Rectangle {
    id: workspaceRoot
    IpcHandler {
        target: "workspaces-" + workspaceRoot.monitorName
        function status(): string {
            return JSON.stringify({monitor: workspaceRoot.monitorName, config: workspaceRoot.config,
                count: workspaceRoot.activeWorkspaces.length,
                labels: workspaceRoot.activeWorkspaces.map(function(w) { return w.displayName || w.name; })});
        }
    }
    required property string monitorName
    property var config: BarDefaults.createWorkspacesConfig()
    property string style: config.style || BarDefaults.createWorkspacesConfig().style
    property bool isTransparent: config.transparent !== false
    property color activeColor: Theme.workspacesColor
    // Opaque fills keep the chosen accent visible over any wallpaper.
    readonly property color inactiveColor: blendAccent(0.72)
    readonly property color hoverColor: blendAccent(0.88)
    function blendAccent(amount) {
        var surface = Theme.panelSurface;
        return Qt.rgba(activeColor.r * amount + surface.r * (1 - amount),
                       activeColor.g * amount + surface.g * (1 - amount),
                       activeColor.b * amount + surface.b * (1 - amount), 1);
    }
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
    property int maxIcons: BarDefaults.normalizeWorkspacesConfig(config).maxIcons

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

    implicitHeight: 32
    implicitWidth: wsRow.implicitWidth

    // --- FORMAT CONVERTER ---
    function getWorkspaceLabel(numStr) {
        var fmt = config.format || BarDefaults.createWorkspacesConfig().format;

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
            return !workspace.is_special && /^\d+$/.test(String(workspace.targetName || workspace.name || ""));
        });
        if (wss.length < 2) return;

        var currentIndex = wss.findIndex(w => w.is_active);
        var validIndex = currentIndex === -1 ? 0 : currentIndex;
        var nextIndex = WorkspaceService.nextWorkspaceIndex(wss, validIndex, direction, workspaceRoot.config);

        if (nextIndex !== validIndex) {
            switchToWorkspace(wss[nextIndex].targetName || wss[nextIndex].name);
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
        spacing: 4

        Repeater {
            model: workspaceRoot.activeWorkspaces
            delegate: Rectangle {
                id: wsBox
                objectName: "workspaceColorTile"
                readonly property color contentColor: !appearance.fill
                    ? (isActive ? workspaceRoot.activeColor : Theme.text)
                    : Theme.foregroundFor(color)
                property var wsData: modelData
                property bool isActive: wsData.is_active
                property int winCount: wsData.winCount
                property var visibleApps: (wsData.groupedWindows || []).slice(0, workspaceRoot.maxIcons)
                property int hiddenAppCount: Math.max(0, (wsData.groupedWindows || []).length - visibleApps.length)
                property bool isHovered: workspaceHover.hovered
                readonly property var appearance: Appearance.resolve(workspaceRoot.style, workspaceRoot.isTransparent, isActive)

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
                implicitWidth: wsContentRow.implicitWidth + 18
                height: 32
                radius: appearance.radius

                // Hover scale
                scale: isHovered ? 1.025 : 1.0
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                // --- GLASSMORPHISM BACKGROUND ---
                color: {
                    if (!appearance.fill) return "transparent"
                    if (isActive) return activeColor
                    return isHovered ? workspaceRoot.hoverColor : workspaceRoot.inactiveColor
                }

                border.width: appearance.borderWidth
                border.color: {
                    if (!appearance.fill)
                        return Theme.withAlpha(activeColor, isActive ? 1 : (isHovered ? 0.65 : 0.3))
                    return Theme.withAlpha(wsBox.contentColor, isActive ? 0.65 : 0.20)
                }

                Behavior on color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 190; easing.type: Easing.OutCubic } }
                Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                // --- GLOW LAYERS (behind box, active only) ---
                Rectangle {
                    z: -2
                    anchors.centerIn: parent
                    width: parent.implicitWidth + 4
                    height: parent.height + 4
                    radius: parent.radius + 2
                    color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.065)
                    visible: isActive && wsBox.appearance.fill
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    z: -3
                    anchors.centerIn: parent
                    width: parent.implicitWidth + 8
                    height: parent.height + 8
                    radius: parent.radius + 4
                    color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.025)
                    visible: isActive && wsBox.appearance.fill
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                }

                // Glass top-edge highlight
                Rectangle {
                    visible: wsBox.appearance.fill
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: 1
                    radius: parent.radius
                    color: Qt.rgba(1, 1, 1, isActive ? 0.08 : 0.03)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // --- CONTENT ROW ---
                Row {
                    id: wsContentRow
                    anchors.centerIn: parent
                    spacing: 6

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
                        text: getWorkspaceLabel(wsData.displayName || wsData.name)
                        color: wsBox.contentColor
                        style: workspaceRoot.isTransparent ? Text.Outline : Text.Normal
                        styleColor: Theme.foregroundFor(wsBox.contentColor)
                        font.bold: true
                        font.pixelSize: 12
                        font.family: Theme.fontFamily
                        font.letterSpacing: 0.5
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: wsBox.showLabel ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }

                    // Gradient separator
                    Rectangle {
                        width: 1
                        height: 14
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
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter
                        visible: winCount > 0 && workspaceRoot.showApps

                        Repeater {
                            model: wsBox.visibleApps

                            Item {
                                id: appIconItem
                                z: 2
                                width: workspaceRoot.iconSize + 2
                                height: workspaceRoot.iconSize + 4

                                Image {
                                    id: appIconImage
                                    width: workspaceRoot.iconSize
                                    height: workspaceRoot.iconSize
                                    anchors.centerIn: parent
                                    source: modelData.iconSource || ""
                                    sourceSize: Qt.size(48, 48)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    visible: source.toString().length > 0 && status !== Image.Error
                                    opacity: 1.0 // Running-app icons remain legible in inactive workspaces too.
                                    scale: modelData.active ? 1.08 : 1.0

                                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                }

                                Text {
                                    id: appIconText
                                    visible: !appIconImage.visible
                                    text: modelData.icon
                                    color: wsBox.contentColor
                                    style: workspaceRoot.isTransparent ? Text.Outline : Text.Normal
                                    styleColor: Theme.foregroundFor(wsBox.contentColor)
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
                                color: wsBox.contentColor
                                    style: workspaceRoot.isTransparent ? Text.Outline : Text.Normal
                                    styleColor: Theme.foregroundFor(wsBox.contentColor)
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
                    color: wsBox.contentColor
                    visible: wsBox.appearance.indicator === "underline"
                    opacity: isActive ? 1.0 : 0.0
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // --- DOT STYLE ---
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: isActive ? 5 : 3
                    height: isActive ? 5 : 3
                    radius: width / 2
                    color: activeColor
                    visible: wsBox.appearance.indicator === "dot"
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
                    color: wsBox.contentColor
                    visible: wsBox.appearance.indicator === "overline"
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
                    color: wsBox.contentColor
                    visible: wsBox.appearance.indicator === "pipe"
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
                            workspaceRoot.switchToWorkspace(wsData.targetName || wsData.name)
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
