import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"

Rectangle {
    id: root

    PowerProfileService { id: powerProfileService }

    function profileInfo(name) {
        var fallback = {
            icon: "󰾅",
            label: name || "Balanced",
            color: Theme.powerProfileColor
        };

        if (!root.profileData || !name || !root.profileData[name]) return fallback;
        return root.profileData[name];
    }

    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 34
    radius: 17
    color: Theme.powerProfileColor

    Behavior on color { ColorAnimation { duration: 200 } }

    property alias currentProfile: powerProfileService.currentProfile
    property alias available: powerProfileService.available
    readonly property alias profileData: powerProfileService.profileData

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.profileInfo(root.currentProfile).icon
            font.pixelSize: 16
            font.family: "JetBrainsMono Nerd Font"
            color: "#1e1e2e"
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            profilePopup.visible = !profilePopup.visible
            if (profilePopup.visible) powerProfileService.refresh()
        }
    }

    // --- POPUP ---
    PopupWindow {
        id: profilePopup
        visible: false
        implicitWidth: 260
        implicitHeight: 220
        color: "transparent"

        anchor.window: root.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return;
            var win = anchor.window;
            var isVertBar = win.height > win.width;
            var itemPos = win.contentItem.mapFromItem(root, 0, 0);
            if (isVertBar) {
                profilePopup.anchor.rect.x = -profilePopup.width - 5;
                profilePopup.anchor.rect.y = itemPos.y + root.height / 2 - profilePopup.height / 2;
            } else {
                profilePopup.anchor.rect.x = itemPos.x + root.width - profilePopup.width;
                profilePopup.anchor.rect.y = win.height + 5;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.background
            border.color: Theme.powerProfileColor
            border.width: 2
            radius: 12

            MouseArea { anchors.fill: parent; z: -1 }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Header
                Text {
                    text: "󰾅  Power Profile"
                    color: Theme.powerProfileColor
                    font.bold: true
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

                // Not available message
                Text {
                    visible: !root.available
                    text: "powerprofilesctl not found"
                    color: Theme.overlay2
                    font.pixelSize: 12
                    font.family: Theme.fontFamily
                    Layout.alignment: Qt.AlignHCenter
                }

                // Profile buttons
                Repeater {
                    model: ["performance", "balanced", "power-saver"]

                    Rectangle {
                        Layout.fillWidth: true
                        height: 42
                        radius: 10
                        visible: root.available

                        property bool isActive: root.currentProfile === modelData
                        property var pData: root.profileInfo(modelData)

                        color: isActive ? Qt.rgba(255,255,255,0.12) : (profMa.containsMouse ? Qt.rgba(255,255,255,0.05) : "transparent")
                        border.color: isActive ? pData.color : "transparent"
                        border.width: isActive ? 2 : 0

                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: pData.icon
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: isActive ? pData.color : Theme.text
                            }

                            Text {
                                text: pData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: isActive
                                color: isActive ? pData.color : Theme.text
                                Layout.fillWidth: true
                            }

                            Text {
                                font.family: Theme.fontFamily
                                visible: isActive
                                text: "✓"
                                font.pixelSize: 14
                                color: pData.color
                            }
                        }

                        MouseArea {
                            id: profMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: powerProfileService.setProfile(modelData)
                        }
                    }
                }
            }
        }
    }
}
