import QtQuick
import "../../../Widgets"

// Single dock slot.
// If modelData.isModule, renders the module component from panel.moduleMap.
// Otherwise renders the app icon with hover/drag/right-click behaviour.
Item {
    id: itemRoot

    required property var modelData
    required property int index
    required property real dockScale
    required property var panel
    required property var backend
    required property var repeater
    required property var row
    required property var content
    required property var moduleMap
    required property var settingsPopup

    width: modelData.isModule
        ? (moduleLoader.item ? moduleLoader.item.implicitWidth : panel.cfgIconSize * dockScale)
        : panel.cfgIconSize * dockScale
    height: Math.max((panel.cfgIconSize + 8) * dockScale, moduleLoader.item ? moduleLoader.item.implicitHeight : 0)

    Loader {
        id: moduleLoader
        active: itemRoot.modelData.isModule
        sourceComponent: itemRoot.modelData.isModule
            ? (itemRoot.moduleMap[itemRoot.modelData.moduleName] || null)
            : null
        anchors.centerIn: parent
    }

    // App-item wrapper (skipped when the slot hosts a module).
    Item {
        anchors.fill: parent
        visible: !itemRoot.modelData.isModule

        // Thin separator between the last pinned app and the first running app.
        Rectangle {
            visible: itemRoot.panel.shouldShowPinnedSeparator(itemRoot.index)
            width: (itemRoot.panel.isHorizontal ? 1 : itemRoot.panel.cfgIconSize * 0.6) * itemRoot.dockScale
            height: (itemRoot.panel.isHorizontal ? itemRoot.panel.cfgIconSize * 0.6 : 1) * itemRoot.dockScale
            color: Qt.rgba(147/255, 153/255, 178/255, 0.35)
            x: itemRoot.panel.isHorizontal ? -3 : (parent.width - width) / 2
            y: itemRoot.panel.isHorizontal ? (parent.height - height) / 2 : -3
        }

        Rectangle {
            id: dockItem
            anchors.centerIn: parent
            width: itemRoot.panel.cfgIconSize * itemRoot.dockScale
            height: itemRoot.panel.cfgIconSize * itemRoot.dockScale
            radius: (itemRoot.panel.cfgIconSize * 0.25) * itemRoot.dockScale
            color: itemMouse.containsMouse
                ? Theme.withAlpha(Theme.primary, 0.18)
                : "transparent"

            // While dragging, hide the source slot completely (still reserves space).
            opacity: itemRoot.panel.isDragging && itemRoot.panel.dragFromIndex === itemRoot.index ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 180 } }

            property real hoverScale: itemMouse.containsMouse && !itemRoot.panel.isDragging ? 1.22 : 1.0
            Behavior on hoverScale {
                NumberAnimation { duration: 200; easing.type: Easing.OutBack }
            }

            transform: Scale {
                origin.x: dockItem.width / 2
                origin.y: dockItem.height
                xScale: dockItem.hoverScale
                yScale: dockItem.hoverScale
            }

            Image {
                id: applicationIcon
                anchors.centerIn: parent
                width: (itemRoot.panel.cfgIconSize - 4) * itemRoot.dockScale
                height: (itemRoot.panel.cfgIconSize - 4) * itemRoot.dockScale
                source: {
                    if (!itemRoot.modelData.icon) return "image://icon/application-x-executable";
                    if (itemRoot.modelData.icon.startsWith("/")) return "file://" + itemRoot.modelData.icon;
                    return "image://icon/" + itemRoot.backend.resolveThemedIconName(itemRoot.modelData.icon);
                }
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                smooth: true
                antialiasing: true
                opacity: itemRoot.panel.isDragging && itemRoot.panel.dragFromIndex === itemRoot.index ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Image {
                    anchors.fill: parent
                    visible: applicationIcon.status === Image.Error
                    source: visible ? "image://icon/application-x-executable" : ""
                    sourceSize: applicationIcon.sourceSize
                    fillMode: Image.PreserveAspectFit
                }
            }

            DockTooltip {
                anchorItem: dockItem
                dockPosition: itemRoot.panel.cfgPosition
                label: itemRoot.modelData.name
                dockScale: itemRoot.dockScale
                shown: itemMouse.containsMouse
                    && !itemRoot.panel.contextMenuVisible
                    && !itemRoot.panel.isDragging
            }

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: itemRoot.panel.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                preventStealing: true

                property real pressX: 0
                property real pressY: 0
                property bool dragStarted: false

                onPressed: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        pressX = mouse.x;
                        pressY = mouse.y;
                        dragStarted = false;
                    }
                }

                onPositionChanged: (mouse) => {
                    if (!pressed) return;

                    if (itemRoot.panel.isDragging) {
                        var pos = mapToItem(itemRoot.panel.contentItem, mouse.x, mouse.y);
                        itemRoot.panel.dragGlobalX = pos.x;
                        itemRoot.panel.dragGlobalY = pos.y;
                    }

                    if (!dragStarted && (Math.abs(mouse.x - pressX) > 4 || Math.abs(mouse.y - pressY) > 4)) {
                        itemRoot.backend.logToFile("Drag started! Index: " + itemRoot.index);
                        dragStarted = true;
                        itemRoot.panel.isDragging = true;
                        itemRoot.panel.dragFromIndex = itemRoot.index;
                        itemRoot.panel.contextMenuVisible = false;
                        itemRoot.panel.dragIcon = itemRoot.modelData.icon;

                        var startPos = mapToItem(itemRoot.panel.contentItem, mouse.x, mouse.y);
                        itemRoot.panel.dragGlobalX = startPos.x;
                        itemRoot.panel.dragGlobalY = startPos.y;
                    }

                    if (dragStarted) {
                        var pointer = mapToItem(itemRoot.row, mouse.x, mouse.y);
                        var horizontal = itemRoot.panel.isHorizontal;
                        var coordinate = horizontal ? pointer.x : pointer.y;
                        var nearest = -1;
                        var distance = Infinity;
                        for (var i = 0; i < itemRoot.panel.dockItems.length; i++) {
                            var slot = itemRoot.repeater.itemAt(i);
                            if (!slot) continue;
                            var origin = slot.mapToItem(itemRoot.row, 0, 0);
                            var center = horizontal ? origin.x + slot.width / 2 : origin.y + slot.height / 2;
                            var delta = Math.abs(coordinate - center);
                            if (delta < distance) { distance = delta; nearest = i; }
                        }
                        itemRoot.panel.dragOverIndex = nearest;
                    }
                }

                onReleased: (mouse) => {
                    if (!dragStarted) return;

                    itemRoot.panel.isDragging = false;
                    var globalPos = mapToItem(itemRoot.content, mouse.x, mouse.y);

                    // Wayland surface grabs clamp coordinates to the surface, so
                    // treat positions outside the dock with a small margin as "dropped off".
                    var isOutside = (globalPos.y < -15
                        || globalPos.y > itemRoot.content.height + 15
                        || globalPos.x < -20
                        || globalPos.x > itemRoot.content.width + 20);
                    var wasPinned = itemRoot.modelData.isPinned;
                    var appIdToDelete = itemRoot.modelData.appId;

                    itemRoot.backend.logToFile("Released. Outside: " + isOutside);

                    if (isOutside) {
                        if (wasPinned) itemRoot.backend.unpinApp(appIdToDelete);
                    } else {
                        itemRoot.panel.handleDrop();
                    }

                    // Reset drag state
                    itemRoot.panel.dragFromIndex = -1;
                    itemRoot.panel.dragOverIndex = -1;
                    itemRoot.panel.dragIcon = "";
                    dragStarted = false;
                }

                onClicked: (mouse) => {
                    if (dragStarted) return;
                    if (mouse.button === Qt.RightButton) {
                        itemRoot.panel.contextMenuIndex = itemRoot.index;
                        itemRoot.panel.contextMenuVisible = true;
                        return;
                    }

                    itemRoot.panel.contextMenuVisible = false;
                    var logMsg = "Clicked: " + itemRoot.modelData.appId
                        + " | Running: " + itemRoot.modelData.isRunning
                        + " | WinID: " + itemRoot.modelData.windowId
                        + " | Cmd: " + itemRoot.modelData.cmd;
                    itemRoot.backend.logToFile(logMsg);

                    if (itemRoot.modelData.isRunning && itemRoot.modelData.windowId && itemRoot.modelData.windowId !== -1) {
                        itemRoot.backend.focusWindow(itemRoot.modelData.windowId);
                    } else {
                        itemRoot.backend.launchApp(itemRoot.modelData.cmd);
                    }
                }
            }
        }

        // Running-window indicator (dot or line, configured via cfgIndicator).
        Rectangle {
            visible: itemRoot.modelData.isRunning
            width:  itemRoot.panel.cfgIndicator === "line"
                ? (itemRoot.panel.cfgIconSize * 0.6 * itemRoot.dockScale)
                : (5 * itemRoot.dockScale)
            height: itemRoot.panel.cfgIndicator === "line" ? (2 * itemRoot.dockScale) : (5 * itemRoot.dockScale)
            radius: itemRoot.panel.cfgIndicator === "line" ? (1 * itemRoot.dockScale) : (2.5 * itemRoot.dockScale)
            color: Theme.primary
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0

            Rectangle {
                visible: itemRoot.panel.cfgIndicator !== "line"
                anchors.centerIn: parent
                width: 9 * itemRoot.dockScale
                height: 9 * itemRoot.dockScale
                radius: 4.5 * itemRoot.dockScale
                color: Theme.withAlpha(Theme.primary, 0.25)
                z: -1
            }
        }

        DockContextMenu {
            anchorItem: dockItem
            dockPosition: itemRoot.panel.cfgPosition
            modelData: itemRoot.modelData
            dockScale: itemRoot.dockScale
            shown: itemRoot.panel.contextMenuVisible
                && itemRoot.panel.contextMenuIndex === itemRoot.index
            backend: itemRoot.backend
            settingsPopup: itemRoot.settingsPopup
            onCloseRequested: itemRoot.panel.contextMenuVisible = false
        }
    }

    // Drop marker (rendered outside the app-item wrapper so it shows for modules too).
    Rectangle {
        visible: itemRoot.panel.isDragging
            && itemRoot.panel.dragOverIndex === itemRoot.index
            && itemRoot.panel.dragFromIndex !== itemRoot.index

        property bool horizontal: itemRoot.panel.isHorizontal
        property bool afterSource: itemRoot.panel.dragOverIndex > itemRoot.panel.dragFromIndex
        width: horizontal ? 2 * itemRoot.dockScale : itemRoot.width
        height: horizontal ? itemRoot.height : 2 * itemRoot.dockScale
        radius: 1 * itemRoot.dockScale
        color: Theme.primary
        x: horizontal ? (afterSource ? parent.width + 2 : -4) : (parent.width - width) / 2
        y: horizontal ? (parent.height - height) / 2 : (afterSource ? parent.height + 2 : -4)

        z: 50

        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 5 * itemRoot.dockScale
            height: parent.height + 5 * itemRoot.dockScale
            radius: 3.5
            color: Theme.withAlpha(Theme.primary, 0.2)
            z: -1
        }
    }
}
