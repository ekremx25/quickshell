import QtQuick
import QtQuick.Layouts
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

    readonly property color accentColor: SettingsPalette.readableAccent(Theme.primary)
    readonly property color accentTextColor: SettingsPalette.foregroundFor(accentColor)

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
                color: root.accentColor
            }

            Text {
                font.family: Theme.fontFamily
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
                font.family: Theme.fontFamily
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
                        if (currentPosition === modelData.key) return Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18);
                        if (positionMouseArea.containsMouse) return Theme.withAlpha(Theme.text, 0.08);
                        return Theme.withAlpha(Theme.text, 0.04);
                    }

                    border.color: {
                        var currentPosition = root.barConfig.barPosition || "top";
                        return currentPosition === modelData.key ? root.accentColor : SettingsPalette.border;
                    }
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        font.family: Theme.fontFamily
                        anchors.centerIn: parent
                        text: modelData.label
                        color: (root.barConfig.barPosition || "top") === modelData.key ? root.accentColor : SettingsPalette.subtext
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
            font.family: Theme.fontFamily
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
                groupColor: SettingsPalette.readableAccent(Theme.ramColor)
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: function(groupName, sourceIndex, moduleName) {
                    root.beginDrag(groupName, sourceIndex, moduleName);
                }
                onDropRequested: function(groupName, targetIndex) {
                    root.handleDrop(groupName, targetIndex);
                }
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "center"
                title: "● Center"
                groupModel: root.centerModel
                groupColor: SettingsPalette.readableAccent(Theme.workspacesColor)
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: function(groupName, sourceIndex, moduleName) {
                    root.beginDrag(groupName, sourceIndex, moduleName);
                }
                onDropRequested: function(groupName, targetIndex) {
                    root.handleDrop(groupName, targetIndex);
                }
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "right"
                title: "▶ Right"
                groupModel: root.rightModel
                groupColor: SettingsPalette.readableAccent(Theme.displayColor)
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: function(groupName, sourceIndex, moduleName) {
                    root.beginDrag(groupName, sourceIndex, moduleName);
                }
                onDropRequested: function(groupName, targetIndex) {
                    root.handleDrop(groupName, targetIndex);
                }
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "inactive"
                title: "⊘ Inactive"
                groupModel: root.inactiveModel
                groupColor: SettingsPalette.overlay2
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: function(groupName, sourceIndex, moduleName) {
                    root.beginDrag(groupName, sourceIndex, moduleName);
                }
                onDropRequested: function(groupName, targetIndex) {
                    root.handleDrop(groupName, targetIndex);
                }
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "dockLeft"
                title: "◀ Dock L"
                groupModel: root.dockLeftModel
                groupColor: SettingsPalette.readableAccent(Theme.weatherColor)
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: function(groupName, sourceIndex, moduleName) {
                    root.beginDrag(groupName, sourceIndex, moduleName);
                }
                onDropRequested: function(groupName, targetIndex) {
                    root.handleDrop(groupName, targetIndex);
                }
                onDragFinished: root.resetDragState()
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: SettingsPalette.surface }

            ModuleDropGroup {
                groupName: "dockRight"
                title: "▶ Dock R"
                groupModel: root.dockRightModel
                groupColor: SettingsPalette.readableAccent(Theme.mediaColor)
                moduleInfo: root.backend ? root.backend.moduleInfo : ({})
                dragLayer: root.dragLayer
                onDragStarted: function(groupName, sourceIndex, moduleName) {
                    root.beginDrag(groupName, sourceIndex, moduleName);
                }
                onDropRequested: function(groupName, targetIndex) {
                    root.handleDrop(groupName, targetIndex);
                }
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
                font.family: Theme.fontFamily
                text: "Drag modules to move"
                color: SettingsPalette.overlay
                font.pixelSize: 11
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 140
                height: 38
                radius: 10
                color: saveMouseArea.containsMouse ? Qt.lighter(root.accentColor, 1.12) : root.accentColor

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    font.family: Theme.fontFamily
                    anchors.centerIn: parent
                    text: "💾  Save"
                    color: root.accentTextColor
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
