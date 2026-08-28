import QtQuick
import QtQuick.Layouts
import "SettingsPalette.js" as SettingsPalette
import "../../../Widgets"

ColumnLayout {
    id: root

    property string groupName: ""
    property string title: ""
    property ListModel groupModel: null
    property color groupColor: "#cdd6f4"
    property var moduleInfo: ({})
    property Item dragLayer: null

    signal dropRequested(string groupName, int targetIndex)
    signal dragStarted(string groupName, int sourceIndex, string moduleName)
    signal dragFinished()

    function moduleThemeColor(moduleName, fallbackColor) {
        var candidate = fallbackColor;
        switch (moduleName) {
        case "Launcher":          candidate = Theme.launcherColor; break;
        case "Calendar":          candidate = Theme.calendarColor; break;
        case "Notepad":           candidate = Theme.yellow; break;
        case "Workspaces":        candidate = Theme.workspacesColor; break;
        case "Notifications":     candidate = Theme.notificationColor; break;
        case "Weather":           candidate = Theme.weatherColor; break;
        case "Volume":            candidate = Theme.mediaColor; break;
        case "Equalizer":         candidate = Theme.equalizerColor; break;
        case "Tray":              candidate = Theme.trayColor; break;
        case "Clipboard":         candidate = Theme.clipboardColor; break;
        case "Power":             candidate = Theme.powerColor; break;
        case "NightLight":        candidate = Theme.yellow; break;
        case "PowerGroup":        candidate = Theme.powerProfileColor; break;
        case "SysInfoGroup":      candidate = Theme.cpuColor; break;
        case "RamModule":         candidate = Theme.ramColor; break;
        case "Media":             candidate = Theme.mediaColor; break;
        case "CurrencyConverter": candidate = Theme.currencyColor; break;
        }
        return SettingsPalette.readableAccent(candidate, SettingsPalette.card);
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 6

    Text {
        font.family: Theme.fontFamily
        text: root.title
        color: root.groupColor
        font.pixelSize: 13
        font.bold: true
        Layout.alignment: Qt.AlignHCenter
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 10
        color: groupDropArea.containsDrag ? Qt.rgba(root.groupColor.r, root.groupColor.g, root.groupColor.b, 0.1) : "transparent"
        border.color: groupDropArea.containsDrag ? Qt.rgba(root.groupColor.r, root.groupColor.g, root.groupColor.b, 0.3) : "transparent"
        border.width: 2

        Behavior on color { ColorAnimation { duration: 200 } }

        DropArea {
            id: groupDropArea
            anchors.fill: parent
            onDropped: root.dropRequested(root.groupName, root.groupModel ? root.groupModel.count : 0)
        }

        ListView {
            id: listView
            anchors.fill: parent
            anchors.margins: 4
            model: root.groupModel
            spacing: 4
            clip: true

            delegate: Item {
                id: delegateRoot
                width: listView.width
                height: 48

                property var info: root.moduleInfo && root.moduleInfo[model.name]
                    ? root.moduleInfo[model.name]
                    : ({ icon: "?", label: model.name, color: "#cdd6f4" })

                DropArea {
                    anchors.fill: parent
                    onDropped: root.dropRequested(root.groupName, index)
                }

                Rectangle {
                    id: dragRect
                    width: delegateRoot.width
                    height: delegateRoot.height
                    radius: 10
                    color: dragArea.containsMouse ? SettingsPalette.cardStrong : SettingsPalette.card
                    border.color: dragArea.drag.active ? root.groupColor : "transparent"
                    border.width: dragArea.drag.active ? 2 : 0

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Drag.active: dragArea.drag.active
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    states: State {
                        when: dragArea.drag.active && root.dragLayer
                        ParentChange { target: dragRect; parent: root.dragLayer }
                        AnchorChanges {
                            target: dragRect
                            anchors.left: undefined
                            anchors.right: undefined
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            font.family: Theme.fontFamily
                            text: "⠿"
                            color: SettingsPalette.overlay
                            font.pixelSize: 16
                        }

                        Text {
                            text: delegateRoot.info.icon
                            color: root.moduleThemeColor(model.name, delegateRoot.info.color)
                            font.pixelSize: 16
                            font.family: "JetBrainsMono Nerd Font"
                        }

                        Text {
                            font.family: Theme.fontFamily
                            text: delegateRoot.info.label
                            color: SettingsPalette.text
                            font.pixelSize: 12
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        drag.target: dragRect

                        onPressed: root.dragStarted(root.groupName, index, model.name)

                        onReleased: {
                            dragRect.Drag.drop();
                            dragRect.x = 0;
                            dragRect.y = 0;
                            if (dragRect.parent !== delegateRoot) {
                                dragRect.parent = delegateRoot;
                            }
                            root.dragFinished();
                        }
                    }
                }
            }
        }
    }
}
