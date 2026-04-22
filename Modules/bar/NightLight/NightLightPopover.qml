import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../../Widgets"
import "../../../Services" as S

// Dropdown popover with on/off toggle + temperature slider.
// Anchored relative to its parent bar item.
PopupWindow {
    id: popover
    visible: false
    implicitWidth: 280
    implicitHeight: 220
    color: "transparent"

    anchor.window: parent ? parent.QsWindow.window : null
    anchor.onAnchoring: {
        if (!anchor.window || !parent) return;
        var win = anchor.window;
        var isVertBar = win.height > win.width;
        var itemPos = win.contentItem.mapFromItem(parent, 0, 0);
        if (isVertBar) {
            popover.anchor.rect.x = -popover.width - 5;
            popover.anchor.rect.y = itemPos.y + parent.height / 2 - popover.height / 2;
        } else {
            popover.anchor.rect.x = Math.max(5, itemPos.x - popover.width / 2 + parent.width / 2);
            popover.anchor.rect.y = win.height + 5;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(30/255, 30/255, 46/255, 0.96)
        border.color: S.NightLight.enabled ? "#f9a03c" : Qt.rgba(1, 1, 1, 0.2)
        border.width: 2
        radius: 12

        // Click blocker behind children
        MouseArea {
            anchors.fill: parent
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── Header ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰽥"
                    font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                    color: S.NightLight.enabled ? "#f9a03c" : Theme.subtext
                }

                Text {
                    text: "Night Light"
                    color: Theme.text
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }

                // ── On/off toggle ────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 22
                    radius: 11
                    color: S.NightLight.enabled ? "#f9a03c" : Qt.rgba(255, 255, 255, 0.12)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: "#1e1e2e"
                        y: 2
                        x: S.NightLight.enabled ? parent.width - width - 2 : 2
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: S.NightLight.setEnabled(!S.NightLight.enabled)
                    }
                }
            }

            // ── Availability warning ─────────────────────────────────
            Rectangle {
                visible: !S.NightLight.available
                Layout.fillWidth: true
                Layout.preferredHeight: unavailText.implicitHeight + 16
                radius: 6
                color: Qt.rgba(243/255, 139/255, 168/255, 0.15)
                border.color: Qt.rgba(243/255, 139/255, 168/255, 0.4)
                border.width: 1
                Text {
                    id: unavailText
                    anchors.fill: parent
                    anchors.margins: 8
                    text: "gammastep is not installed. Run:\n  sudo pacman -S gammastep"
                    color: "#f38ba8"
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                    wrapMode: Text.WordWrap
                }
            }

            // ── Temperature label ────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                visible: S.NightLight.available

                Text {
                    text: "Temperature"
                    color: Theme.subtext
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }
                Text {
                    text: S.NightLight.temperature + "K"
                    color: S.NightLight.enabled ? "#f9a03c" : Theme.text
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            // ── Slider ───────────────────────────────────────────────
            Slider {
                id: tempSlider
                Layout.fillWidth: true
                visible: S.NightLight.available
                from: S.NightLight.minTemperature
                to: S.NightLight.maxTemperature
                stepSize: 100
                value: S.NightLight.temperature
                enabled: S.NightLight.enabled || true  // slider usable even when off — flipping on picks up value

                onMoved: S.NightLight.setTemperature(value)

                background: Rectangle {
                    x: tempSlider.leftPadding
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    width: tempSlider.availableWidth
                    height: 6
                    radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        // 1000K (very warm) → 6500K (neutral daylight)
                        GradientStop { position: 0.0; color: "#ff8844" }
                        GradientStop { position: 0.5; color: "#ffcc88" }
                        GradientStop { position: 1.0; color: "#aaccff" }
                    }
                }

                handle: Rectangle {
                    x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    width: 18
                    height: 18
                    radius: 9
                    color: "#1e1e2e"
                    border.color: S.NightLight.enabled ? "#f9a03c" : Qt.rgba(1, 1, 1, 0.2)
                    border.width: 2
                }
            }

            // ── Quick presets ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                visible: S.NightLight.available
                spacing: 6

                Repeater {
                    model: [
                        { label: "Warm",    k: 3000 },
                        { label: "Reading", k: 4000 },
                        { label: "Neutral", k: 5000 },
                        { label: "Off",     k: 6500 }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: 6
                        readonly property bool isActive: S.NightLight.temperature === modelData.k
                        color: isActive
                            ? Qt.rgba(249/255, 160/255, 60/255, 0.2)
                            : (presetArea.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                        border.color: isActive ? "#f9a03c" : Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.isActive ? "#f9a03c" : Theme.text
                            font.pixelSize: 10
                            font.bold: parent.isActive
                        }

                        MouseArea {
                            id: presetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                S.NightLight.setTemperature(parent.modelData.k);
                                if (!S.NightLight.enabled) S.NightLight.setEnabled(true);
                            }
                        }
                    }
                }
            }

            // ── Apply on startup checkbox ────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: S.NightLight.available
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    radius: 4
                    color: S.NightLight.applyOnStartup ? "#f9a03c" : "transparent"
                    border.color: S.NightLight.applyOnStartup ? "#f9a03c" : Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        visible: S.NightLight.applyOnStartup
                        text: "✓"
                        color: "#1e1e2e"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: S.NightLight.setApplyOnStartup(!S.NightLight.applyOnStartup)
                    }
                }

                Text {
                    text: "Apply on startup"
                    color: Theme.subtext
                    font.pixelSize: 11
                    Layout.fillWidth: true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: S.NightLight.setApplyOnStartup(!S.NightLight.applyOnStartup)
                    }
                }
            }
        }
    }
}
