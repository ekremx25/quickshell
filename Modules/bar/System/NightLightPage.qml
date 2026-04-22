import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Widgets"
import "../../../Services" as S
import "../Settings/SettingsPalette.js" as SettingsPalette

// Full Settings page for the blue-light filter.
// All state lives in the S.NightLight singleton — this page is a view.
Item {
    id: nightLightPage

    readonly property color accent: "#f9a03c"

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

            // ── Header ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰽥"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    color: nightLightPage.accent
                }
                Text {
                    text: "Night Light"
                    font.bold: true
                    font.pixelSize: 18
                    color: SettingsPalette.text
                }
                Item { Layout.fillWidth: true }

                // Status pill
                Rectangle {
                    radius: 8
                    color: !S.NightLight.available
                        ? Qt.rgba(243/255, 139/255, 168/255, 0.14)
                        : (S.NightLight.enabled
                            ? Qt.rgba(249/255, 160/255, 60/255, 0.14)
                            : Qt.rgba(255, 255, 255, 0.05))
                    implicitWidth: statusRow.implicitWidth + 16
                    implicitHeight: 28
                    RowLayout {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "●"
                            color: !S.NightLight.available ? "#f38ba8" : (S.NightLight.enabled ? nightLightPage.accent : SettingsPalette.overlay)
                            font.pixelSize: 11
                        }
                        Text {
                            text: !S.NightLight.available
                                ? "gammastep missing"
                                : (S.NightLight.enabled ? ("On — " + S.NightLight.temperature + "K") : "Off")
                            color: SettingsPalette.text
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }

            // ── Unavailable banner ───────────────────────────────────
            Rectangle {
                visible: !S.NightLight.available
                Layout.fillWidth: true
                Layout.preferredHeight: banner.implicitHeight + 24
                radius: 12
                color: Qt.rgba(243/255, 139/255, 168/255, 0.08)
                border.color: Qt.rgba(243/255, 139/255, 168/255, 0.3)
                border.width: 1

                ColumnLayout {
                    id: banner
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: "⚠  gammastep is not installed"
                        color: "#f38ba8"
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        text: "Night Light uses gammastep to adjust the screen's colour temperature. Install it and reload."
                        color: SettingsPalette.subtext
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.preferredWidth: cmdText.implicitWidth + 20
                        Layout.preferredHeight: 28
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.35)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1
                        Text {
                            id: cmdText
                            anchors.centerIn: parent
                            text: "sudo pacman -S gammastep"
                            color: SettingsPalette.text
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // ── Main toggle card ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: S.NightLight.available
                radius: 12
                color: SettingsPalette.surface
                border.color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                implicitHeight: toggleRow.implicitHeight + 28

                RowLayout {
                    id: toggleRow
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Blue-light filter"
                            color: SettingsPalette.text
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Text {
                            text: "Tints the display warm to reduce eye strain in the evening."
                            color: SettingsPalette.subtext
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    // Switch toggle
                    Rectangle {
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 26
                        radius: 13
                        color: S.NightLight.enabled ? nightLightPage.accent : Qt.rgba(255, 255, 255, 0.14)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: SettingsPalette.surface
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
            }

            // ── Temperature card ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: S.NightLight.available
                radius: 12
                color: SettingsPalette.surface
                border.color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                implicitHeight: tempColumn.implicitHeight + 28
                opacity: S.NightLight.enabled ? 1.0 : 0.55
                Behavior on opacity { NumberAnimation { duration: 180 } }

                ColumnLayout {
                    id: tempColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Colour temperature"
                            color: SettingsPalette.text
                            font.pixelSize: 13
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Text {
                            text: S.NightLight.temperature + " K"
                            color: nightLightPage.accent
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    // Slider with gradient background
                    Slider {
                        id: tempSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        from: S.NightLight.minTemperature
                        to: S.NightLight.maxTemperature
                        stepSize: 100
                        value: S.NightLight.temperature
                        onMoved: S.NightLight.setTemperature(value)

                        background: Rectangle {
                            x: tempSlider.leftPadding
                            y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                            width: tempSlider.availableWidth
                            height: 8
                            radius: 4
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#ff8844" }
                                GradientStop { position: 0.5; color: "#ffcc88" }
                                GradientStop { position: 1.0; color: "#aaccff" }
                            }
                        }

                        handle: Rectangle {
                            x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                            y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                            width: 22
                            height: 22
                            radius: 11
                            color: SettingsPalette.surface
                            border.color: nightLightPage.accent
                            border.width: 2
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "1000 K — very warm"; color: SettingsPalette.subtext; font.pixelSize: 10 }
                        Item { Layout.fillWidth: true }
                        Text { text: "6500 K — neutral"; color: SettingsPalette.subtext; font.pixelSize: 10 }
                    }

                    // Presets
                    Text {
                        text: "Presets"
                        color: SettingsPalette.subtext
                        font.pixelSize: 11
                        font.bold: true
                        Layout.topMargin: 4
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { label: "Candle",   k: 2000 },
                                { label: "Warm",     k: 3000 },
                                { label: "Reading",  k: 4000 },
                                { label: "Neutral",  k: 5000 },
                                { label: "Daylight", k: 6500 }
                            ]
                            delegate: Rectangle {
                                id: presetCard
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: 8
                                readonly property bool isActive: S.NightLight.temperature === modelData.k
                                color: isActive
                                    ? Qt.rgba(249/255, 160/255, 60/255, 0.2)
                                    : (presetArea.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                                border.color: isActive ? nightLightPage.accent : Qt.rgba(255, 255, 255, 0.08)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text {
                                        text: presetCard.modelData.label
                                        color: presetCard.isActive ? nightLightPage.accent : SettingsPalette.text
                                        font.pixelSize: 12
                                        font.bold: presetCard.isActive
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: presetCard.modelData.k + " K"
                                        color: SettingsPalette.overlay
                                        font.pixelSize: 9
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: presetArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        S.NightLight.setTemperature(presetCard.modelData.k);
                                        if (!S.NightLight.enabled) S.NightLight.setEnabled(true);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Schedule card ────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: S.NightLight.available
                radius: 12
                color: SettingsPalette.surface
                border.color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                implicitHeight: scheduleCol.implicitHeight + 28

                ColumnLayout {
                    id: scheduleCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Schedule"
                                color: SettingsPalette.text
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: "Turn Night Light on and off automatically at fixed times. Windows that cross midnight (19:00 → 07:00) are supported."
                                color: SettingsPalette.subtext
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        // Toggle
                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 22
                            radius: 11
                            color: S.NightLight.scheduleEnabled ? nightLightPage.accent : Qt.rgba(255, 255, 255, 0.14)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: SettingsPalette.surface
                                y: 2
                                x: S.NightLight.scheduleEnabled ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: S.NightLight.setScheduleEnabled(!S.NightLight.scheduleEnabled)
                            }
                        }
                    }

                    // Time pickers
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 16
                        opacity: S.NightLight.scheduleEnabled ? 1.0 : 0.5
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        // Turn on at
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "Turn on at"
                                color: SettingsPalette.subtext
                                font.pixelSize: 11
                                font.bold: true
                            }

                            RowLayout {
                                spacing: 6

                                Rectangle {
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 40
                                    radius: 8
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                    border.color: onHourInput.activeFocus ? nightLightPage.accent : Qt.rgba(255, 255, 255, 0.1)
                                    border.width: 1

                                    TextInput {
                                        id: onHourInput
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: SettingsPalette.text
                                        font.pixelSize: 18
                                        font.bold: true
                                        font.family: "JetBrainsMono Nerd Font"
                                        text: String(S.NightLight.scheduleOnHour).padStart(2, '0')
                                        selectByMouse: true
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: IntValidator { bottom: 0; top: 23 }
                                        maximumLength: 2
                                        enabled: S.NightLight.scheduleEnabled
                                        onEditingFinished: {
                                            var v = parseInt(text);
                                            if (isNaN(v)) v = S.NightLight.scheduleOnHour;
                                            S.NightLight.setScheduleOn(v, S.NightLight.scheduleOnMinute);
                                            text = String(S.NightLight.scheduleOnHour).padStart(2, '0');
                                        }
                                    }
                                }

                                Text {
                                    text: ":"
                                    color: SettingsPalette.text
                                    font.pixelSize: 20
                                    font.bold: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 40
                                    radius: 8
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                    border.color: onMinuteInput.activeFocus ? nightLightPage.accent : Qt.rgba(255, 255, 255, 0.1)
                                    border.width: 1

                                    TextInput {
                                        id: onMinuteInput
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: SettingsPalette.text
                                        font.pixelSize: 18
                                        font.bold: true
                                        font.family: "JetBrainsMono Nerd Font"
                                        text: String(S.NightLight.scheduleOnMinute).padStart(2, '0')
                                        selectByMouse: true
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: IntValidator { bottom: 0; top: 59 }
                                        maximumLength: 2
                                        enabled: S.NightLight.scheduleEnabled
                                        onEditingFinished: {
                                            var v = parseInt(text);
                                            if (isNaN(v)) v = S.NightLight.scheduleOnMinute;
                                            S.NightLight.setScheduleOn(S.NightLight.scheduleOnHour, v);
                                            text = String(S.NightLight.scheduleOnMinute).padStart(2, '0');
                                        }
                                    }
                                }
                            }
                        }

                        // Arrow separator
                        Text {
                            text: "→"
                            color: SettingsPalette.subtext
                            font.pixelSize: 16
                            Layout.topMargin: 16
                        }

                        // Turn off at
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "Turn off at"
                                color: SettingsPalette.subtext
                                font.pixelSize: 11
                                font.bold: true
                            }

                            RowLayout {
                                spacing: 6

                                Rectangle {
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 40
                                    radius: 8
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                    border.color: offHourInput.activeFocus ? nightLightPage.accent : Qt.rgba(255, 255, 255, 0.1)
                                    border.width: 1

                                    TextInput {
                                        id: offHourInput
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: SettingsPalette.text
                                        font.pixelSize: 18
                                        font.bold: true
                                        font.family: "JetBrainsMono Nerd Font"
                                        text: String(S.NightLight.scheduleOffHour).padStart(2, '0')
                                        selectByMouse: true
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: IntValidator { bottom: 0; top: 23 }
                                        maximumLength: 2
                                        enabled: S.NightLight.scheduleEnabled
                                        onEditingFinished: {
                                            var v = parseInt(text);
                                            if (isNaN(v)) v = S.NightLight.scheduleOffHour;
                                            S.NightLight.setScheduleOff(v, S.NightLight.scheduleOffMinute);
                                            text = String(S.NightLight.scheduleOffHour).padStart(2, '0');
                                        }
                                    }
                                }

                                Text {
                                    text: ":"
                                    color: SettingsPalette.text
                                    font.pixelSize: 20
                                    font.bold: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 60
                                    Layout.preferredHeight: 40
                                    radius: 8
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                    border.color: offMinuteInput.activeFocus ? nightLightPage.accent : Qt.rgba(255, 255, 255, 0.1)
                                    border.width: 1

                                    TextInput {
                                        id: offMinuteInput
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: SettingsPalette.text
                                        font.pixelSize: 18
                                        font.bold: true
                                        font.family: "JetBrainsMono Nerd Font"
                                        text: String(S.NightLight.scheduleOffMinute).padStart(2, '0')
                                        selectByMouse: true
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: IntValidator { bottom: 0; top: 59 }
                                        maximumLength: 2
                                        enabled: S.NightLight.scheduleEnabled
                                        onEditingFinished: {
                                            var v = parseInt(text);
                                            if (isNaN(v)) v = S.NightLight.scheduleOffMinute;
                                            S.NightLight.setScheduleOff(S.NightLight.scheduleOffHour, v);
                                            text = String(S.NightLight.scheduleOffMinute).padStart(2, '0');
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Schedule status hint
                    Text {
                        visible: S.NightLight.scheduleEnabled
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        text: {
                            var h1 = String(S.NightLight.scheduleOnHour).padStart(2, '0');
                            var m1 = String(S.NightLight.scheduleOnMinute).padStart(2, '0');
                            var h2 = String(S.NightLight.scheduleOffHour).padStart(2, '0');
                            var m2 = String(S.NightLight.scheduleOffMinute).padStart(2, '0');
                            var inWindow = S.NightLight.isInScheduleWindow();
                            return (inWindow ? "✓ Active now" : "⏱  Sleeping") + " — next change follows the " + h1 + ":" + m1 + " → " + h2 + ":" + m2 + " schedule.";
                        }
                        color: S.NightLight.isInScheduleWindow() ? nightLightPage.accent : SettingsPalette.subtext
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── Behaviour card ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: S.NightLight.available
                radius: 12
                color: SettingsPalette.surface
                border.color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                implicitHeight: behaviourCol.implicitHeight + 28

                ColumnLayout {
                    id: behaviourCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: "Behaviour"
                        color: SettingsPalette.text
                        font.pixelSize: 13
                        font.bold: true
                    }

                    // Apply on startup
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 4
                            color: S.NightLight.applyOnStartup ? nightLightPage.accent : "transparent"
                            border.color: S.NightLight.applyOnStartup ? nightLightPage.accent : Qt.rgba(255, 255, 255, 0.25)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                visible: S.NightLight.applyOnStartup
                                text: "✓"
                                color: SettingsPalette.surface
                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: S.NightLight.setApplyOnStartup(!S.NightLight.applyOnStartup)
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: labelCol.implicitHeight

                            ColumnLayout {
                                id: labelCol
                                anchors.fill: parent
                                spacing: 2
                                Text {
                                    text: "Apply on startup"
                                    color: SettingsPalette.text
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    text: "Restore the saved temperature when the shell starts."
                                    color: SettingsPalette.subtext
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: S.NightLight.setApplyOnStartup(!S.NightLight.applyOnStartup)
                            }
                        }
                    }
                }
            }

            // ── Config path hint ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: S.NightLight.available
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.02)
                border.color: Qt.rgba(255, 255, 255, 0.04)
                border.width: 1
                implicitHeight: hintCol.implicitHeight + 20

                ColumnLayout {
                    id: hintCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text: "ℹ  How it works"
                        color: SettingsPalette.subtext
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        text: "Calls gammastep with -O <K> to apply the temperature and -x to reset. Uses the wlr-gamma-control protocol, so it works under Niri, Hyprland and MangoWC. Settings are stored in ~/.config/quickshell/nightlight_config.json."
                        color: SettingsPalette.subtext
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
