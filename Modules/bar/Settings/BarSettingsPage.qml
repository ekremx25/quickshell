import QtQuick
import QtQuick.Layouts
import "SettingsPalette.js" as SettingsPalette
import "../../../Widgets"

Item {
    id: root

    property var backend: null
    property var barConfig: ({})
    property ListModel leftModel: null
    property ListModel centerModel: null
    property ListModel rightModel: null
    property ListModel inactiveModel: null
    property ListModel dockLeftModel: null
    property ListModel dockRightModel: null
    property Item dragLayer: null

    signal barConfigEdited(var cfg)
    signal saveRequested()

    property string dragSourceGroup: ""
    property int dragSourceIndex: -1
    property string dragModuleName: ""

    function beginDrag(groupName, index, moduleName) {
        dragSourceGroup = groupName;
        dragSourceIndex = index;
        dragModuleName = moduleName;
    }

    function resetDragState() {
        dragSourceGroup = "";
        dragSourceIndex = -1;
        dragModuleName = "";
    }

    function handleDrop(targetGroup, targetIndex) {
        if (!backend || dragSourceGroup === "" || dragModuleName === "") return;
        backend.moveModule(dragSourceGroup, dragSourceIndex, targetGroup, targetIndex, dragModuleName);
        resetDragState();
    }

    function updateBarPosition(position) {
        var nextConfig = JSON.parse(JSON.stringify(barConfig || {}));
        nextConfig.barPosition = position;
        barConfigEdited(nextConfig);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "󰒍"
                font.pixelSize: 20
                font.family: "JetBrainsMono Nerd Font"
                color: Theme.primary
            }

            Text {
                text: "Bar Settings"
                font.bold: true
                font.pixelSize: 18
                color: SettingsPalette.text
            }
        }

        Item { height: 4 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Position:"
                color: SettingsPalette.subtext
                font.pixelSize: 12
            }

            Repeater {
                model: [
                    { key: "top", label: "▲ Top" },
                    { key: "bottom", label: "▼ Bottom" },
                    { key: "left", label: "◀ Left" },
                    { key: "right", label: "▶ Right" }
                ]

                Rectangle {
                    width: 80
                    height: 30
                    radius: 8

                    color: {
                        var currentPosition = root.barConfig.barPosition || "top";
                        if (currentPosition === modelData.key) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3);
                        if (positionMouseArea.containsMouse) return Qt.rgba(255, 255, 255, 0.08);
                        return Qt.rgba(255, 255, 255, 0.04);
                    }

                    border.color: {
                        var currentPosition = root.barConfig.barPosition || "top";
                        return currentPosition === modelData.key ? Theme.primary : Qt.rgba(255, 255, 255, 0.1);
                    }
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: (root.barConfig.barPosition || "top") === modelData.key ? Theme.primary : SettingsPalette.subtext
                        font.pixelSize: 11
                        font.bold: (root.barConfig.barPosition || "top") === modelData.key
                    }

                    MouseArea {
                        id: positionMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.updateBarPosition(modelData.key)
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        Item { height: 4 }

        Text {
            text: "Drag and drop modules to reorder"
            color: SettingsPalette.overlay2
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            ModuleDropGroup {
                groupName: "left"
                title: "◀ Left"
                groupModel: root.leftModel
                groupColor: "#a6e3a1"
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: root.beginDrag(groupName, sourceIndex, moduleName)
                onDropRequested: root.handleDrop(groupName, targetIndex)
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "center"
                title: "● Center"
                groupModel: root.centerModel
                groupColor: "#cba6f7"
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: root.beginDrag(groupName, sourceIndex, moduleName)
                onDropRequested: root.handleDrop(groupName, targetIndex)
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "right"
                title: "▶ Right"
                groupModel: root.rightModel
                groupColor: "#89b4fa"
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: root.beginDrag(groupName, sourceIndex, moduleName)
                onDropRequested: root.handleDrop(groupName, targetIndex)
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "inactive"
                title: "⊘ Inactive"
                groupModel: root.inactiveModel
                groupColor: "#6c7086"
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: root.beginDrag(groupName, sourceIndex, moduleName)
                onDropRequested: root.handleDrop(groupName, targetIndex)
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "dockLeft"
                title: "◀ Dock L"
                groupModel: root.dockLeftModel
                groupColor: "#fab387"
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: root.beginDrag(groupName, sourceIndex, moduleName)
                onDropRequested: root.handleDrop(groupName, targetIndex)
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "dockRight"
                title: "▶ Dock R"
                groupModel: root.dockRightModel
                groupColor: "#f9e2af"
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: root.beginDrag(groupName, sourceIndex, moduleName)
                onDropRequested: root.handleDrop(groupName, targetIndex)
                onDragFinished: root.resetDragState()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: SettingsPalette.surface
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Drag modules to move"
                color: SettingsPalette.overlay
                font.pixelSize: 11
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 140
                height: 38
                radius: 10
                color: saveMouseArea.containsMouse ? Qt.lighter(Theme.primary, 1.2) : Theme.primary

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "💾  Save"
                    color: "#1e1e2e"
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    id: saveMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveRequested()
                }
            }
        }
    }
}
