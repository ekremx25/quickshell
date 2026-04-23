import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette
import "../../../Services"

Item {
    id: mousePage
    property bool themeDropdownOpen: false

    MouseSettingsService {
        id: mouseService
    }

    Flickable {
        anchors.fill: parent
        contentHeight: mainColumn.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn
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
                Text {  text: "🖱"; font.pixelSize: 20; color: Theme.primary; font.family: Theme.fontFamily }
                Text {  text: "Mouse Settings"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text; font.family: Theme.fontFamily }
                Item { Layout.fillWidth: true }
                Rectangle {
                    radius: 8
                    color: mouseService.supported ? Qt.rgba(166/255, 227/255, 161/255, 0.14) : Qt.rgba(243/255, 139/255, 168/255, 0.14)
                    implicitWidth: statusRow.implicitWidth + 16
                    implicitHeight: 28
                    RowLayout {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {  text: mouseService.supported ? "●" : "●"; color: mouseService.supported ? Theme.green : Theme.red; font.pixelSize: 11; font.family: Theme.fontFamily }
                        Text {  text: mouseService.supported ? "Hyprland" : "Unsupported"; color: SettingsPalette.text; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
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
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 96
                        radius: 12
                        color: Qt.rgba(137/255, 180/255, 250/255, 0.10)
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {  text: "🖱"; font.pixelSize: 34; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter; font.family: Theme.fontFamily }
                            Text {  text: "Pointer"; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; Layout.alignment: Qt.AlignHCenter; font.family: Theme.fontFamily }
                            Text {  text: mouseService.sensitivity.toFixed(2); color: Theme.primary; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter; font.family: Theme.fontFamily }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 140
                        Layout.preferredHeight: 96
                        radius: 12
                        color: Qt.rgba(249/255, 226/255, 175/255, 0.10)
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {  text: "↕"; font.pixelSize: 34; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter; font.family: Theme.fontFamily }
                            Text {  text: "Wheel"; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; Layout.alignment: Qt.AlignHCenter; font.family: Theme.fontFamily }
                            Text {  text: mouseService.scrollFactor.toFixed(2) + "x"; color: "#f9e2af"; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter; font.family: Theme.fontFamily }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96
                        radius: 12
                        color: Qt.rgba(203/255, 166/255, 247/255, 0.10)
                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 14
                            spacing: 4
                            Text {  text: "Acceleration Profile"; color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily }
                            Text {  text: mouseService.accelProfile === "flat" ? "Flat / raw response" : "Adaptive / libinput default"; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                            Text {  text: mouseService.managedByQuickshell ? "~/.config/quickshell/mouse_config.json" : "~/.config/hypr/custom/general.conf"; color: Theme.primary; font.pixelSize: 11; font.family: Theme.fontFamily }
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
                            Text {  text: "Pointer Speed"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true; font.family: Theme.fontFamily }
                            Item { Layout.fillWidth: true }
                            Text {  text: mouseService.sensitivity.toFixed(2); color: Theme.primary; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                        }
                        Text {  text: "Controls Hyprland `input.sensitivity`."; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                        Slider {
                            Layout.fillWidth: true
                            from: -1.0
                            to: 1.0
                            stepSize: 0.05
                            value: mouseService.sensitivity
                            onMoved: mouseService.sensitivity = value
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text {  text: "Wheel Scroll Speed"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true; font.family: Theme.fontFamily }
                            Item { Layout.fillWidth: true }
                            Text {  text: mouseService.scrollFactor.toFixed(2) + "x"; color: "#f9e2af"; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                        }
                        Text {  text: "Controls Hyprland `input.scroll_factor`."; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                        Slider {
                            Layout.fillWidth: true
                            from: 0.25
                            to: 5.0
                            stepSize: 0.05
                            value: mouseService.scrollFactor
                            onMoved: mouseService.scrollFactor = value
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {  text: "Acceleration"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true; font.family: Theme.fontFamily }
                        Text {  text: "Choose cursor acceleration profile."; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                        NetworkSegmentButton {
                            Layout.preferredWidth: 220
                            options: ["Adaptive", "Flat"]
                            selectedIndex: mouseService.accelProfile === "flat" ? 1 : 0
                            onSelected: idx => mouseService.setAccelProfile(idx === 1 ? "flat" : "adaptive")
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text {  text: "Cursor Theme"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true; font.family: Theme.fontFamily }
                            Item { Layout.fillWidth: true }
                            Text {  text: mouseService.cursorTheme; color: Theme.primary; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                        }
                        Text {  text: "Select which cursor icon pack Quickshell should apply."; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.iconFontFamily }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                id: themeDropdown
                                Layout.fillWidth: true
                                height: 38
                                radius: 8
                                color: themeDropdownMA.containsMouse ? Qt.rgba(69/255, 71/255, 90/255, 0.8) : Qt.rgba(49/255, 50/255, 68/255, 0.6)
                                border.color: mousePage.themeDropdownOpen ? Theme.primary : Qt.rgba(255,255,255,0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    Text {  text: "🖱"; font.pixelSize: 16; font.family: Theme.fontFamily }
                                    Text {
                                        font.family: Theme.fontFamily
                                        text: mouseService.cursorTheme || "Select theme"
                                        color: SettingsPalette.text
                                        font.pixelSize: 12
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        font.family: Theme.fontFamily
                                        text: mousePage.themeDropdownOpen ? "▴" : "▾"
                                        color: SettingsPalette.subtext
                                        font.pixelSize: 11
                                    }
                                }

                                MouseArea {
                                    id: themeDropdownMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mousePage.themeDropdownOpen = !mousePage.themeDropdownOpen
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: mousePage.themeDropdownOpen
                            implicitHeight: Math.min(themeOptionsCol.implicitHeight + 8, 220)
                            color: Qt.rgba(49/255, 50/255, 68/255, 0.95)
                            radius: 10
                            border.color: Qt.rgba(255,255,255,0.08)
                            border.width: 1
                            clip: true

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 4
                                contentHeight: themeOptionsCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Column {
                                    id: themeOptionsCol
                                    width: parent.width
                                    spacing: 2

                                    Repeater {
                                        model: mouseService.availableCursorThemes

                                        Rectangle {
                                            required property string modelData
                                            width: themeOptionsCol.width
                                            height: 36
                                            radius: 6
                                            color: mouseService.cursorTheme === modelData
                                                ? Qt.rgba(137/255, 180/255, 250/255, 0.15)
                                                : (themeOptionMA.containsMouse ? Qt.rgba(69/255, 71/255, 90/255, 0.5) : "transparent")
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                spacing: 8

                                                Text {  text: "🖱"; font.pixelSize: 14; font.family: Theme.fontFamily }
                                                Text {
                                                    font.family: Theme.fontFamily
                                                    text: modelData
                                                    color: mouseService.cursorTheme === modelData ? Theme.primary : SettingsPalette.text
                                                    font.pixelSize: 12
                                                    font.bold: mouseService.cursorTheme === modelData
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    font.family: Theme.fontFamily
                                                    text: mouseService.cursorTheme === modelData ? "✓" : ""
                                                    color: Theme.primary
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }
                                            }

                                            MouseArea {
                                                id: themeOptionMA
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    mouseService.setCursorTheme(modelData)
                                                    mousePage.themeDropdownOpen = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text {  text: "Cursor Size"; color: SettingsPalette.text; font.pixelSize: 14; font.bold: true; font.family: Theme.fontFamily }
                            Item { Layout.fillWidth: true }
                            Text {  text: mouseService.cursorSize + " px"; color: "#cba6f7"; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                        }
                        Text {  text: "Applied using `hyprctl setcursor`."; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                        Slider {
                            Layout.fillWidth: true
                            from: 16
                            to: 64
                            stepSize: 1
                            value: mouseService.cursorSize
                            onMoved: mouseService.cursorSize = Math.round(value)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: mouseService.supported ? Qt.rgba(137/255, 180/255, 250/255, 0.08) : Qt.rgba(243/255, 139/255, 168/255, 0.08)
                implicitHeight: infoCol.implicitHeight + 24

                ColumnLayout {
                    id: infoCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    Text {
                        font.family: Theme.fontFamily
                        text: mouseService.supported ? "Settings are applied live and saved for future Hyprland sessions." : "Mouse tuning is currently only implemented for Hyprland."
                        color: SettingsPalette.text
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Text {
                        font.family: Theme.fontFamily
                        text: mouseService.statusMessage
                        visible: mouseService.statusMessage !== ""
                        color: mouseService.supported ? Theme.primary : Theme.red
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 96
                    height: 36
                    radius: 8
                    color: reloadMA.containsMouse ? Qt.rgba(255,255,255,0.10) : Qt.rgba(255,255,255,0.06)
                    Text {  anchors.centerIn: parent; text: "Reload"; color: SettingsPalette.text; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                    MouseArea {
                        id: reloadMA
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !mouseService.isBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouseService.loadSettings()
                    }
                }

                Rectangle {
                    width: 120
                    height: 36
                    radius: 8
                    color: applyMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                    opacity: mouseService.supported ? 1.0 : 0.6
                    Text {  anchors.centerIn: parent; text: mouseService.isBusy ? "Applying..." : "Apply"; color: "#1e1e2e"; font.pixelSize: 12; font.bold: true; font.family: Theme.fontFamily }
                    MouseArea {
                        id: applyMA
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: mouseService.supported && !mouseService.isBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouseService.applySettings()
                    }
                }
            }

            Item { height: 20 }
        }
    }
}
