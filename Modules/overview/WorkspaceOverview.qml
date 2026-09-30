import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../Services"
import "../bar/BarDefaults.js" as BarDefaults
import "OverviewLogic.js" as OverviewLogic
import "../../Widgets"

Scope {
    id: root
    property bool opened: false
    property string monitorName: ""
    property string errorMessage: ""
    property int revision: WorkspaceService.revision
    property var workspaceConfig: BarDefaults.createWorkspacesConfig()
    property var sourceWorkspaces: {
        root.revision
        return root.collectAllWorkspaces()
    }
    property var model: OverviewLogic.buildOverviewModel(sourceWorkspaces, function(appId, title) {
        var source = WorkspaceService.iconSourceFor(appId)
        return {appName: appId || "Application", iconSource: source}
    })
    property var monitorSections: {
        root.revision
        return OverviewLogic.groupByMonitor(root.model, WorkspaceService.state.monitorOrder || [], root.monitorName)
    }
    property var groupedRegularWorkspaces: {
        var workspaces = []
        for (var i = 0; i < root.monitorSections.length; ++i)
            workspaces = workspaces.concat(root.monitorSections[i].regular)
        return workspaces
    }
    property var groupedSpecialWorkspaces: {
        var workspaces = []
        for (var i = 0; i < root.monitorSections.length; ++i)
            workspaces = workspaces.concat(root.monitorSections[i].special)
        return workspaces
    }
    property var draggedWindow: null
    property real dragX: 0
    property real dragY: 0
    property var activeOverviewWindow: null

    function collectAllWorkspaces() {
        var groups = []
        var monitors = WorkspaceService.state.monitorOrder || []
        for (var i = 0; i < monitors.length; ++i)
            groups.push(WorkspaceService.overviewWorkspacesForMonitor(monitors[i], workspaceConfig))
        return OverviewLogic.mergeWorkspaceGroups(groups)
    }

    function normalizedAddress(value) {
        var address = String(value || "").toLowerCase()
        return address.indexOf("0x") === 0 ? address.substring(2) : address
    }

    function waylandToplevel(windowId) {
        var expected = normalizedAddress(windowId)
        var toplevels = Hyprland.toplevels.values || []
        for (var i = 0; i < toplevels.length; ++i) {
            var candidate = toplevels[i]
            if (normalizedAddress(candidate.address) === expected)
                return candidate.wayland || null
        }
        return null
    }

    function beginDrag(windowData, scenePosition) {
        draggedWindow = windowData
        dragX = scenePosition.x
        dragY = scenePosition.y
    }
    function updateDrag(scenePosition) {
        dragX = scenePosition.x
        dragY = scenePosition.y
    }
    function endDrag() {
        if (activeOverviewWindow) activeOverviewWindow.finishDrag()
        Qt.callLater(function() { root.draggedWindow = null })
    }

    function open() {
        if (!CompositorService.isHyprland) { errorMessage = "Workspace Overview currently requires Hyprland."; return }
        monitorName = WorkspaceService.focusedMonitorName()
        if (!monitorName) { errorMessage = "No focused monitor is available."; return }
        errorMessage = ""; opened = true; WorkspaceService.requestRefresh()
    }
    function close() { opened = false }
    function toggle() { opened ? close() : open() }
    function activate(target) { WorkspaceService.runOverviewAction("workspace", "", target) }
    function focusWindow(windowId) { WorkspaceService.runOverviewAction("focus", windowId, "") }
    function moveWindow(windowData, target, monitorName) {
        if (!OverviewLogic.canDrop(windowData.id, windowData.sourceWorkspace, target)) return
        WorkspaceService.runOverviewAction("move", windowData.id, target, monitorName)
    }

    IpcHandler {
        target: "workspace-overview"
        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.close() }
        function status(): string {
            var monitors = []
            for (var i = 0; i < root.monitorSections.length; ++i) {
                var section = root.monitorSections[i]
                monitors.push({
                    name: section.name,
                    focused: section.focused,
                    workspaceCount: section.workspaceCount,
                    windowCount: section.windowCount
                })
            }
            return JSON.stringify({
                visible: root.opened,
                monitor: root.monitorName,
                phase: WorkspaceService.overviewActionBusy ? "moving" : "open",
                monitorCount: monitors.length,
                workspaceCount: root.model.regular.length,
                windowCount: root.model.windowCount,
                monitors: monitors
            })
        }
    }

    Connections {
        target: WorkspaceService
        function onOverviewActionFinished(kind, success) {
            if (success && (kind === "focus" || kind === "workspace")) root.close()
            if (!success) root.errorMessage = WorkspaceService.overviewActionError
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: overviewWindow
            required property var modelData
            function finishDrag() {
                if (dragGhost.Drag.active) dragGhost.Drag.drop()
            }
            screen: modelData
            visible: root.opened && modelData.name === root.monitorName
            onVisibleChanged: {
                if (visible) root.activeOverviewWindow = overviewWindow
                else if (root.activeOverviewWindow === overviewWindow) root.activeOverviewWindow = null
            }
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Shortcut { sequence: "Escape"; enabled: overviewWindow.visible; onActivated: root.close() }
            Rectangle {
                anchors.fill: parent
                color: Theme.withAlpha(Theme.background, 0.82)
                MouseArea { anchors.fill: parent; onClicked: root.close() }
            }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width * 0.84, 1900)
                height: Math.min(parent.height * 0.76, 1050)
                radius: 20
                color: Theme.withAlpha(Theme.panelSurface, 0.96)
                border.color: Theme.withAlpha(Theme.primary, 0.35)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 20; spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Workspace Overview"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 22; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.monitorSections.length + " monitors · " + root.model.regular.length + " workspaces · " + root.model.windowCount + " apps"
                            color: Theme.subtext; font.family: Theme.fontFamily
                        }
                    }
                    Text { visible: root.errorMessage !== ""; text: root.errorMessage; color: Theme.red; font.family: Theme.fontFamily; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    GridLayout {
                        id: monitorSummary
                        Layout.fillWidth: true
                        columns: Math.max(1, Math.min(3, root.monitorSections.length))
                        rowSpacing: 8; columnSpacing: 8
                        Repeater {
                            model: root.monitorSections
                            delegate: Rectangle {
                                id: monitorCard
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 68
                                radius: 10
                                color: modelData.focused ? Theme.withAlpha(Theme.primary, 0.18) : Theme.withAlpha(Theme.surface, 0.72)
                                border.width: modelData.focused ? 2 : 1
                                border.color: modelData.focused ? Theme.primary : Theme.withAlpha(Theme.text, 0.16)
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 9; spacing: 3
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: monitorCard.modelData.name; color: Theme.text; font.family: Theme.fontFamily; font.bold: true; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }
                                        Text { visible: monitorCard.modelData.focused; text: "Focused"; color: Theme.primary; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true }
                                        Text { text: monitorCard.modelData.windowCount + " apps"; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 10 }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: monitorCard.modelData.regular.length > 0
                                            ? "Workspaces  " + monitorCard.modelData.regular.map(function(workspace) { return workspace.displayName }).join(" · ")
                                            : "No regular workspaces"
                                        color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 10; elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                    GridLayout {
                        id: regularGrid
                        Layout.fillWidth: true; Layout.fillHeight: true
                        columns: width > 1200 ? 5 : (width > 760 ? 3 : 2)
                        rowSpacing: 10; columnSpacing: 10
                        Repeater {
                            id: regularRepeater
                            model: root.groupedRegularWorkspaces
                            delegate: Rectangle {
                                id: workspaceCard
                                required property var modelData
                                function handleClick(x, y) {
                                    for (var i = windowRepeater.count - 1; i >= 0; --i) {
                                        var item = windowRepeater.itemAt(i)
                                        if (!item) continue
                                        var point = item.mapToItem(workspaceCard, 0, 0)
                                        if (x >= point.x && x <= point.x + item.width && y >= point.y && y <= point.y + item.height) {
                                            root.focusWindow(item.windowData.id)
                                            return
                                        }
                                    }
                                    root.activate(modelData.targetName)
                                }
                                Layout.fillWidth: true; Layout.fillHeight: true
                                Layout.minimumWidth: 180; Layout.minimumHeight: 150
                                radius: 14
                                color: modelData.active ? Theme.withAlpha(Theme.primary, 0.16) : Theme.withAlpha(Theme.surface, 0.72)
                                border.width: dropArea.containsDrag ? 2 : 1
                                border.color: dropArea.containsDrag ? Theme.primary : Theme.withAlpha(Theme.text, 0.15)
                                DropArea { id: dropArea; anchors.fill: parent; z: 0; keys: ["overview-window"]; onDropped: drop => root.moveWindow(drop.source.windowData, workspaceCard.modelData.targetName, workspaceCard.modelData.monitor) }
                                MouseArea {
                                    anchors.fill: parent; z: -1; preventStealing: false
                                    onClicked: mouse => workspaceCard.handleClick(mouse.x, mouse.y)
                                }
                                ColumnLayout {
                                    z: 1
                                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: workspaceCard.modelData.displayName; color: Theme.text; font.family: Theme.fontFamily; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            implicitWidth: workspaceMonitorLabel.implicitWidth + 12; implicitHeight: 22; radius: 11
                                            color: workspaceCard.modelData.monitor === root.monitorName
                                                ? Theme.withAlpha(Theme.primary, 0.20)
                                                : Theme.withAlpha(Theme.text, 0.08)
                                            Text {
                                                id: workspaceMonitorLabel
                                                anchors.centerIn: parent
                                                text: workspaceCard.modelData.monitor || "Unassigned"
                                                color: workspaceCard.modelData.monitor === root.monitorName ? Theme.primary : Theme.subtext
                                                font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true
                                            }
                                        }
                                    }
                                    GridLayout {
                                        Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 6; columnSpacing: 6
                                        Repeater {
                                            id: windowRepeater
                                            model: workspaceCard.modelData.windows
                                            delegate: Rectangle {
                                                id: windowCard
                                                required property var modelData
                                                property var windowData: modelData
                                                property var captureSource: root.waylandToplevel(windowData.id)
                                                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 96
                                                radius: 8; color: Theme.withAlpha(Theme.background, 0.72); clip: true
                                                border.color: modelData.urgent ? Theme.red : "transparent"
                                                opacity: dragHandler.active ? 0.35 : 1
                                                ScreencopyView {
                                                    id: livePreview
                                                    anchors.fill: parent
                                                    captureSource: windowCard.captureSource
                                                    live: overviewWindow.visible && captureSource !== null
                                                    paintCursor: false
                                                    constraintSize: Qt.size(width, height)
                                                    visible: hasContent
                                                }
                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    visible: !livePreview.hasContent
                                                    Image { source: modelData.iconSource || "image://icon/application-x-executable"; sourceSize: Qt.size(38,38); Layout.preferredWidth: 38; Layout.preferredHeight: 38; Layout.alignment: Qt.AlignHCenter }
                                                    Text { text: modelData.appName; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight; Layout.maximumWidth: windowCard.width - 16 }
                                                }
                                                Rectangle {
                                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                                    height: 34; color: Theme.withAlpha(Theme.background, 0.78)
                                                    RowLayout { anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7; spacing: 6
                                                        Image { source: modelData.iconSource || "image://icon/application-x-executable"; sourceSize: Qt.size(20,20); Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                                                        ColumnLayout { Layout.fillWidth: true; spacing: 0
                                                            Text { text: modelData.appName; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                                            Text { text: modelData.title; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 8; elide: Text.ElideRight; Layout.fillWidth: true }
                                                        }
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent; enabled: !WorkspaceService.overviewActionBusy
                                                    onClicked: root.focusWindow(windowCard.windowData.id)
                                                }
                                                DragHandler {
                                                    id: dragHandler
                                                    enabled: !WorkspaceService.overviewActionBusy
                                                    target: null
                                                    onCentroidChanged: if (active) root.updateDrag(centroid.scenePosition)
                                                    onActiveChanged: active ? root.beginDrag(windowCard.windowData, centroid.scenePosition) : root.endDrag()
                                                }
                                            }
                                        }
                                    }
                                    Text { visible: workspaceCard.modelData.empty; text: "Empty"; color: Theme.subtext; font.family: Theme.fontFamily; Layout.alignment: Qt.AlignCenter }
                                }
                            }
                        }
                    }
                    RowLayout {
                        visible: root.groupedSpecialWorkspaces.length > 0; Layout.fillWidth: true; spacing: 8
                        Text { text: "Special"; color: Theme.subtext; font.family: Theme.fontFamily }
                        Repeater {
                            id: specialRepeater
                            model: root.groupedSpecialWorkspaces
                            delegate: Rectangle {
                            id: specialCard
                            required property var modelData
                            Layout.preferredWidth: 320; Layout.preferredHeight: 96; radius: 10
                            color: Theme.withAlpha(Theme.surface, 0.8); border.color: specialDrop.containsDrag ? Theme.primary : Theme.withAlpha(Theme.text,0.15)
                            DropArea { id: specialDrop; anchors.fill: parent; keys:["overview-window"]; onDropped: drop => root.moveWindow(drop.source.windowData, specialCard.modelData.targetName, specialCard.modelData.monitor) }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.activate(specialCard.modelData.targetName)
                            }
                            RowLayout { anchors.fill: parent; anchors.margins: 8
                                ColumnLayout {
                                    spacing: 2
                                    Text { text: specialCard.modelData.displayName; color: Theme.text; font.family: Theme.fontFamily; font.bold: true }
                                    Text { text: specialCard.modelData.monitor || "Unassigned"; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 9 }
                                }
                                Item { Layout.fillWidth: true }
                                Repeater { id: specialWindowRepeater; model: specialCard.modelData.windows; delegate: Rectangle {
                                    id: specialWindow
                                    required property var modelData; property var windowData: modelData
                                    property var captureSource: root.waylandToplevel(windowData.id)
                                    Layout.preferredWidth: 108; Layout.preferredHeight: 72; radius: 7; color: Theme.withAlpha(Theme.background, 0.75); clip: true
                                    opacity: specialDrag.active ? 0.35 : 1
                                    ScreencopyView {
                                        id: specialPreview
                                        anchors.fill: parent
                                        captureSource: specialWindow.captureSource
                                        live: overviewWindow.visible && captureSource !== null
                                        paintCursor: false
                                        constraintSize: Qt.size(width, height)
                                        visible: hasContent
                                    }
                                    Image { anchors.centerIn: parent; width: 30; height: 30; visible: !specialPreview.hasContent; source: modelData.iconSource || "image://icon/application-x-executable"; sourceSize: Qt.size(30,30) }
                                    Rectangle {
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                        height: 20; color: Theme.withAlpha(Theme.background, 0.78)
                                        Text { anchors.fill: parent; anchors.leftMargin: 5; anchors.rightMargin: 5; text: modelData.appName; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 8; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; enabled: !WorkspaceService.overviewActionBusy
                                        onClicked: root.focusWindow(specialWindow.windowData.id)
                                    }
                                    DragHandler {
                                        id: specialDrag
                                        enabled: !WorkspaceService.overviewActionBusy
                                        target: null
                                        onCentroidChanged: if (active) root.updateDrag(centroid.scenePosition)
                                        onActiveChanged: active ? root.beginDrag(specialWindow.windowData, centroid.scenePosition) : root.endDrag()
                                    }
                                }}
                            }
                        }}
                    }
                }
            }

            Rectangle {
                id: dragGhost
                visible: root.draggedWindow !== null
                width: 180; height: 52; radius: 8; z: 1000
                x: root.dragX - width / 2; y: root.dragY - height / 2
                color: Theme.withAlpha(Theme.primary, 0.88)
                border.color: Theme.text
                property var windowData: root.draggedWindow
                Drag.active: visible
                Drag.source: dragGhost
                Drag.keys: ["overview-window"]
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    text: root.draggedWindow ? root.draggedWindow.appName : ""
                    color: Theme.foregroundFor(Theme.primary)
                    font.family: Theme.fontFamily; font.bold: true
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
