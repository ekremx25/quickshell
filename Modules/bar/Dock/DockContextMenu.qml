import QtQuick
import "../../../Widgets"

// Right-click menu for a dock item.
// Pin/unpin, close window, open dock settings.
Rectangle {
    id: menu

    required property var modelData
    required property real dockScale
    required property bool shown
    required property var backend
    required property var settingsPopup

    signal closeRequested()

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.top
    anchors.bottomMargin: 14

    width: menuContent.implicitWidth + (16 * dockScale)
    height: menuContent.implicitHeight + (12 * dockScale)
    radius: 12 * dockScale
    color: Qt.rgba(30/255, 30/255, 46/255, 0.96)
    border.color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
    border.width: 1
    z: 100
    visible: shown

    component MenuAction: Rectangle {
        required property string label
        required property color labelColor
        required property var activate

        width: 140 * menu.dockScale
        height: 30 * menu.dockScale
        radius: 8 * menu.dockScale
        color: actionMouse.containsMouse ? Qt.rgba(137/255, 180/255, 250/255, 0.18) : "transparent"

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: parent.labelColor
            font.pixelSize: 12 * menu.dockScale
            font.bold: true
            font.family: Theme.fontFamily
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (parent.activate) parent.activate()
        }
    }

    component MenuSeparator: Rectangle {
        width: 120 * menu.dockScale
        height: 1
        color: Qt.rgba(1, 1, 1, 0.1)
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Column {
        id: menuContent
        anchors.centerIn: parent
        spacing: 2

        MenuAction {
            label: menu.modelData.isPinned ? "  Unpin from Dock" : "  Pin to Dock"
            labelColor: menu.modelData.isPinned ? Theme.red : Theme.primary
            activate: function() {
                if (menu.modelData.isPinned) {
                    menu.backend.unpinApp(menu.modelData.appId);
                } else {
                    menu.backend.pinApp(menu.modelData.appId);
                }
                menu.closeRequested();
            }
        }

        MenuSeparator {}

        MenuAction {
            label: "  Close Application"
            labelColor: Theme.text
            activate: function() {
                if (menu.modelData.isRunning && menu.modelData.windowId) {
                    menu.backend.closeWindow(menu.modelData.windowId);
                }
                menu.closeRequested();
            }
        }

        MenuSeparator {}

        MenuAction {
            label: "  Dock Settings"
            labelColor: Theme.text
            activate: function() {
                menu.settingsPopup.currentPage = "dock";
                menu.settingsPopup.visible = true;
                menu.closeRequested();
            }
        }
    }
}
