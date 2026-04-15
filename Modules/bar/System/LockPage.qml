import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Item {
    id: lockPage

    property bool pickerVisible: false
    readonly property string backgroundPreviewSource: (lockService.backgroundPath && lockService.backgroundPath.length > 0) ? ("file://" + lockService.backgroundPath) : ""

    LockSettingsService {
        id: lockService
    }

    Flickable {
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentColumn
            width: parent.width
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 20
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: "󰌾"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; color: Theme.primary }
                Text { text: "Lock Screen"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text }
                Item { Layout.fillWidth: true }
                Rectangle {
                    radius: 8
                    color: lockService.hyprlandActive ? Qt.rgba(166/255, 227/255, 161/255, 0.14) : Qt.rgba(249/255, 226/255, 175/255, 0.14)
                    implicitWidth: statusRow.implicitWidth + 16
                    implicitHeight: 28
                    RowLayout {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "●"; color: lockService.hyprlandActive ? Theme.green : "#f9e2af"; font.pixelSize: 11 }
                        Text { text: lockService.hyprlandActive ? "Hyprland active" : "Saved for Hyprland"; color: SettingsPalette.text; font.pixelSize: 11; font.bold: true }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: SettingsPalette.surface
                border.color: Qt.rgba(255,255,255,0.05)
                border.width: 1
                implicitHeight: previewRow.implicitHeight + 24

                RowLayout {
                    id: previewRow
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 124
                        radius: 12
                        color: Qt.rgba(255,255,255,0.06)
                        clip: true

                        Loader {
                            anchors.fill: parent
                            active: lockPage.backgroundPreviewSource.length > 0
                            sourceComponent: Component {
                                Image {
                                    anchors.fill: parent
                                    source: lockPage.backgroundPreviewSource
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.28)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰌾"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 32
                            color: "#ffffff"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "Background"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true }
                        Text {
                            Layout.fillWidth: true
                            text: lockService.backgroundPath
                            color: SettingsPalette.subtext
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                        }

                        RowLayout {
                            spacing: 8
                            Rectangle {
                                width: 110; height: 34; radius: 8
                                color: Qt.rgba(137/255, 180/255, 250/255, 0.18)
                                Text { anchors.centerIn: parent; text: "Browse"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 12 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: lockPage.pickerVisible = true
                                }
                            }
                            Rectangle {
                                width: 110; height: 34; radius: 8
                                color: Qt.rgba(255,255,255,0.08)
                                Text { anchors.centerIn: parent; text: "Lock now"; color: SettingsPalette.text; font.bold: true; font.pixelSize: 12 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: lockService.lockNow()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: SettingsPalette.surface
                implicitHeight: controlsColumn.implicitHeight + 28

                ColumnLayout {
                    id: controlsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Dim screen"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: lockService.dimTimeoutMinutes + " min"; color: Theme.primary; font.pixelSize: 12; font.bold: true }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 1
                            to: 120
                            stepSize: 1
                            value: lockService.dimTimeoutMinutes
                            onMoved: lockService.dimTimeoutMinutes = value
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Lock session"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: lockService.lockTimeoutMinutes + " min"; color: "#f9e2af"; font.pixelSize: 12; font.bold: true }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 1
                            to: 180
                            stepSize: 1
                            value: lockService.lockTimeoutMinutes
                            onMoved: lockService.lockTimeoutMinutes = value
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Screen off"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: lockService.screenOffTimeoutMinutes + " min"; color: "#94e2d5"; font.pixelSize: 12; font.bold: true }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 2
                            to: 240
                            stepSize: 1
                            value: lockService.screenOffTimeoutMinutes
                            onMoved: lockService.screenOffTimeoutMinutes = value
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Suspend"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: lockService.suspendTimeoutMinutes + " min"; color: "#cba6f7"; font.pixelSize: 12; font.bold: true }
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: 5
                            to: 360
                            stepSize: 1
                            value: lockService.suspendTimeoutMinutes
                            onMoved: lockService.suspendTimeoutMinutes = value
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Lock during media playback"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 52
                                height: 28
                                radius: 14
                                color: lockService.ignoreMediaInhibit ? Theme.primary : Qt.rgba(255,255,255,0.12)

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 11
                                    y: 3
                                    x: lockService.ignoreMediaInhibit ? 27 : 3
                                    color: lockService.ignoreMediaInhibit ? "#1e1e2e" : SettingsPalette.text
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: lockService.ignoreMediaInhibit = !lockService.ignoreMediaInhibit
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: lockService.ignoreMediaInhibit ? "Auto lock runs even if YouTube or other apps request idle inhibit." : "Media playback can temporarily prevent auto lock."
                            color: SettingsPalette.subtext
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: !lockService.brightnessctlAvailable
                        text: "brightnessctl was not found. The dim screen rule will be skipped, and the remaining lock rules will continue to work."
                        color: "#f9e2af"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: Qt.rgba(255,255,255,0.04)
                implicitHeight: statusText.implicitHeight + 24

                Text {
                    id: statusText
                    anchors.fill: parent
                    anchors.margins: 12
                    text: lockService.statusMessage.length > 0 ? lockService.statusMessage : (lockService.hyprlandActive ? "Settings are written to hyprlock.conf and hypridle.conf, then hypridle is reloaded." : "Settings are written for the next Hyprland session.")
                    wrapMode: Text.Wrap
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 110; height: 38; radius: 10
                    color: Qt.rgba(255,255,255,0.10)
                    Text { anchors.centerIn: parent; text: "Reload"; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: lockService.reloadIdle()
                    }
                }
                Rectangle {
                    width: 150; height: 38; radius: 10
                    color: lockService.isBusy ? Qt.rgba(137/255, 180/255, 250/255, 0.45) : Theme.primary
                    Text { anchors.centerIn: parent; text: lockService.isBusy ? "Working..." : "Apply"; color: "#1e1e2e"; font.pixelSize: 13; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !lockService.isBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: lockService.applySettings()
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: lockPage.pickerVisible
        color: Qt.rgba(0, 0, 0, 0.42)
        z: 100

        MouseArea { anchors.fill: parent }

        FilePicker {
            anchors.centerIn: parent
            width: 720
            height: 520
            title: "Select Lock Screen Background"
            extensions: ["png", "jpg", "jpeg", "webp"]
            allowCreateFolder: false
            onFileSelected: function(path) {
                lockService.backgroundPath = path
                lockPage.pickerVisible = false
            }
            onCanceled: lockPage.pickerVisible = false
        }
    }
}
