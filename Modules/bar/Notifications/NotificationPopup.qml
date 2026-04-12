import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "."
import "../../../Widgets"
import "../../../Services" as S

// Popup window showing the list of notifications
PanelWindow {
    id: root
    NotificationPopupBackend { id: backend }

    // Window Dimensions
    implicitWidth: mainRect.width
    implicitHeight: mainRect.height

    anchors {
        top: backend.anchorTop
        bottom: backend.anchorBottom
        left: backend.anchorLeft
        right: backend.anchorRight
    }
    margins {
        top: 60
        bottom: 60
        left: 10
        right: 10
    }

    color: "transparent"
    WlrLayershell.layer: notifService.overlayEnabled ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace: "notification-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore



    property var notifService: S.Notifications

    Rectangle {
        id: mainRect
        width: 360
        height: 500
        color: Theme.background
        radius: Theme.radius
        border.width: 1
        border.color: Theme.surface

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // HEADER
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Bildirimler" // Notifications
                    font.bold: true
                    font.pixelSize: 18
                    color: Theme.text
                }
                Item { Layout.fillWidth: true }
                
                // Clear All Button
                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: "transparent"
                    border.width: 1; border.color: Theme.surface
                    visible: notifService.notifications.length > 0

                    Text {
                        anchors.centerIn: parent
                        text: "" // Trash icon
                        font.family: "JetBrainsMono Nerd Font"
                        color: Theme.red
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                             backend.clearAll()
                        }
                    }
                }
            }

            // DURATION CONTROL
            ColumnLayout {
                Layout.fillWidth: true
                visible: true
                spacing: 8

                // Time Input
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Text {
                        text: "Show for:"
                        color: Theme.subtext
                        font.pixelSize: 14
                    }

                    Rectangle {
                        width: 60; height: 30
                        color: Theme.surface
                        radius: 5
                        border.width: 1
                        border.color: Theme.overlay
                        
                        TextInput {
                            anchors.fill: parent
                            anchors.margins: 4
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            
                            text: backend.displaySeconds.toString()
                            color: Theme.text
                            font.pixelSize: 14
                            
                            validator: IntValidator { bottom: 1; top: 3600 } // 1s to 1h
                            
                            onEditingFinished: {
                                backend.setDisplaySeconds(text)
                                text = backend.displaySeconds.toString()
                            }
                            
                            // Update on Enter as well
                            onAccepted: focus = false
                        }
                    }

                    Text {
                        text: "seconds"
                        color: Theme.subtext
                        font.pixelSize: 14
                    }
                }

                // Buttons Row
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    // [-1m] Button
                    Rectangle {
                        width: 40; height: 30; radius: 15
                        color: "transparent"
                        border.width: 1; border.color: Theme.surface
                        
                        Text { anchors.centerIn: parent; text: "-1m"; color: Theme.text; font.pixelSize: 12 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.adjustDisplayDuration(-60000)
                            }
                        }
                    }

                    // [-5s] Button
                    Rectangle {
                        width: 40; height: 30; radius: 15
                        color: "transparent"
                        border.width: 1; border.color: Theme.surface
                        
                        Text { anchors.centerIn: parent; text: "-5s"; color: Theme.text; font.pixelSize: 12 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.adjustDisplayDuration(-5000)
                            }
                        }
                    }

                    // [+5s] Button
                    Rectangle {
                        width: 40; height: 30; radius: 15
                        color: "transparent"
                        border.width: 1; border.color: Theme.surface
                        
                        Text { anchors.centerIn: parent; text: "+5s"; color: Theme.text; font.pixelSize: 12 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.adjustDisplayDuration(5000)
                            }
                        }
                    }

                    // [+1m] Button
                    Rectangle {
                        width: 40; height: 30; radius: 15
                        color: "transparent"
                        border.width: 1; border.color: Theme.surface
                        
                        Text { anchors.centerIn: parent; text: "+1m"; color: Theme.text; font.pixelSize: 12 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.adjustDisplayDuration(60000)
                            }
                        }
                    }
                }
            }

            // LIST
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 10
                
                // Show all notifications (history included? User logic in Service handles this)
                // The service has `notifications` list.
                model: notifService.notifications

                delegate: Rectangle {
                    // Notification Item
                    required property var modelData
                    required property int index
                    property int modelIndex: index

                    width: ListView.view.width
                    height: itemCol.implicitHeight + 20
                    color: Theme.surface
                    radius: 12

                    RowLayout {
                        id: itemCol
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top
                            margins: 10
                        }
                        spacing: 12

                        // Icon (App Icon or Image)
                        Rectangle {
                            width: 40; height: 40; radius: 10
                            color: Theme.base
                            clip: true

                            // If it's a file/image
                            Image {
                                anchors.fill: parent
                                source: modelData.appIcon
                                fillMode: Image.PreserveAspectCrop
                                visible: backend.showsImage(modelData.appIcon)
                            }
                            
                            // Fallback Icon
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                                color: Theme.text
                                visible: !backend.showsImage(modelData.appIcon)
                            }
                        }

                        // Content
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.appName
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: Theme.subtext
                                }
                                Text {
                                    text: Qt.formatTime(modelData.timestamp, "HH:mm")
                                    font.pixelSize: 10
                                    color: Theme.overlay2
                                }
                            }

                            Text {
                                text: backend.notificationSummary(modelData)
                                font.bold: true
                                font.pixelSize: 14
                                color: Theme.text
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: backend.notificationBody(modelData)
                                font.pixelSize: 13
                                color: Theme.subtext
                                elide: Text.ElideRight
                                maximumLineCount: notifService.compactMode ? 1 : 2
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        // Close Button
                        Text {
                            text: ""
                            font.family: "JetBrainsMono Nerd Font"
                            color: Theme.overlay2
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    notifService.removeNotification(modelIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
