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
        showSpecial: false,
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

    // Main background transparent, only the inner boxes are visible
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

    // --- VISUAL LAYOUT (Stylish Pill Design) ---
    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: workspaceRoot.activeWorkspaces
            delegate: Rectangle {
                id: wsBox
                property var wsData: modelData
                property bool isActive: wsData.is_active
                property int winCount: wsData.winCount
                property var visibleApps: (wsData.groupedWindows || []).slice(0, workspaceRoot.maxIcons)
                property int hiddenAppCount: Math.max(0, (wsData.groupedWindows || []).length - visibleApps.length)

                // Dynamically expanding size based on content
                implicitWidth: wsContent.implicitWidth + 24
                height: 34
                radius: style === "square" ? 6 : 17

                // STYLE LOGIC
                color: {
                   if (style === "fill") {
                       if (isActive) return activeColor;
                       return isTransparent ? "transparent" : Theme.surface;
                   }
                   if (style === "square" || style === "circle") {
                       return isActive ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.4) : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.2); 
                   }
                   return "transparent";
                }

                border.width: (style === "outline" || style === "square" || style === "circle") ? 2 : 0
                border.color: {
                    if (style === "outline" || style === "square" || style === "circle") return isActive ? activeColor : (isTransparent ? "transparent" : Theme.surface);
                    return "transparent";
                }

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                Row {
                    id: wsContent
                    z: 2
                    anchors.centerIn: parent
                    spacing: 8

                    // NUMBER (Formatted)
                    Text {
                        text: getWorkspaceLabel(wsData.name)
                        color: isActive ? Theme.workspaceActiveTextColor : Theme.text
                        font.bold: true
                        font.pixelSize: 14
                        font.family: Theme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // THIN LINE INSERTED BETWEEN (Separator)
                    Rectangle {
                        width: 1
                        height: 14
                        color: (isActive ? Theme.workspaceActiveTextColor : Theme.text) // Dynamic color
                        opacity: 0.25
                        anchors.verticalCenter: parent.verticalCenter
                        visible: winCount > 0 && workspaceRoot.showApps
                    }

                    // APPLICATION ICONS
                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: winCount > 0 && workspaceRoot.showApps

                        Repeater {
                            model: wsBox.visibleApps
                            
                            Item {
                                width: iconText.implicitWidth
                                height: workspaceRoot.iconSize + 4
                                
                                Text {
                                    id: iconText
                                    text: modelData.icon
                                    color: (isActive || modelData.active) ? (isActive ? Theme.workspaceActiveTextColor : Theme.primary) : Theme.text
                                    opacity: modelData.active ? 1.0 : (isActive ? 0.9 : 0.6)
                                    font.pixelSize: workspaceRoot.iconSize
                                    font.family: "JetBrainsMono Nerd Font"
                                    anchors.centerIn: parent
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
                                
                                // Grouping bubble (e.g. if there are 2 of the same app)
                                Rectangle {
                                    visible: (modelData.count !== undefined && modelData.count > 1) && !isActive
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: Theme.surface
                                    border.color: Theme.text
                                    border.width: 1
                                    anchors.right: parent.right
                                    anchors.rightMargin: -6
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -2
                                    z: 2

                                    Text {
                                        font.family: Theme.fontFamily
                                        anchors.centerIn: parent
                                        text: modelData.count !== undefined ? String(modelData.count) : ""
                                        font.pixelSize: 8
                                        color: Theme.text
                                        font.bold: true
                                    }
                                }
                            }
                        }


                        Text {
                            visible: wsBox.hiddenAppCount > 0
                            text: "+" + wsBox.hiddenAppCount
                            color: isActive ? Theme.workspaceActiveTextColor : Theme.text
                            opacity: 0.8
                            font.pixelSize: Math.max(9, workspaceRoot.iconSize - 7)
                            font.bold: true
                            font.family: Theme.fontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // BOTTOM LINE (Underline Style)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.6
                    height: 3
                    radius: 1.5
                    color: activeColor
                    visible: style === "underline" && isActive
                }

                // DOT (Dot Style)
                Rectangle {
                    anchors.top: parent.bottom
                    anchors.topMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 4
                    height: 4
                    radius: 2
                    color: activeColor
                    visible: style === "dot" && isActive
                }

                // TOP LINE (Overline Style)
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.6
                    height: 3
                    radius: 1.5
                    color: activeColor
                    visible: style === "overline" && isActive
                }

                // SIDE LINE (Pipe Style)
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    width: 3
                    height: parent.height * 0.6
                    radius: 1.5
                    color: activeColor
                    visible: style === "pipe" && isActive
                }

                // Click Area
                MouseArea {
                    z: 1
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: workspaceRoot.switchToWorkspace(wsData.name)
                }

                HoverHandler { id: workspaceHover }

                ToolTip.visible: workspaceHover.hovered
                ToolTip.delay: 450
                ToolTip.text: {
                    var title = wsData.is_special ? wsData.name : "Workspace " + getWorkspaceLabel(wsData.name)
                    var windows = wsData.windows || []
                    if (windows.length === 0) return title + "\nEmpty"
                    var lines = []
                    for (var i = 0; i < windows.length && i < 6; ++i) {
                        lines.push("• " + (windows[i].title || windows[i].app_id || "Application"))
                    }
                    if (windows.length > 6) lines.push("+" + (windows.length - 6) + " more")
                    return title + " · " + windows.length + " window" + (windows.length === 1 ? "" : "s") + "\n" + lines.join("\n")
                }
            }
        }
    }
}
