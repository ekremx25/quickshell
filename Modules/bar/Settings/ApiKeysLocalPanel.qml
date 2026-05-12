import QtQuick
import QtQuick.Layouts
import "SettingsPalette.js" as SettingsPalette
import "../../../Widgets"

// Panel shown when the "Local only" provider is selected.
// Explains what SmartComplete uses offline and offers a single activate button.
Rectangle {
    id: localPanel

    required property string saveStatus
    required property string saveMessage

    signal activateRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: localCol.implicitHeight + 32
    radius: 12
    color: Qt.rgba(166/255, 227/255, 161/255, 0.08)
    border.color: Qt.rgba(166/255, 227/255, 161/255, 0.3)
    border.width: 1

    ColumnLayout {
        id: localCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 10
                color: Qt.rgba(166/255, 227/255, 161/255, 0.15)
                border.color: Qt.rgba(166/255, 227/255, 161/255, 0.4)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "󰒘"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    color: "#a6e3a1"
                }
            }

            ColumnLayout {
                spacing: 2
                Text {
                    font.family: Theme.fontFamily
                    text: "100% Local Mode"
                    color: "#a6e3a1"
                    font.pixelSize: 15
                    font.bold: true
                }
                Text {
                    font.family: Theme.fontFamily
                    text: "No network, no API key, no data leaves your machine"
                    color: SettingsPalette.subtext
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(166/255, 227/255, 161/255, 0.2)
        }

        Text {
            font.family: Theme.fontFamily
            text: "SmartComplete will use only the built-in data on your system:"
            color: SettingsPalette.text
            font.pixelSize: 12
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 4

            Repeater {
                model: [
                    { icon: "󰂺", label: "Dictionary", detail: "74,000+ English words" },
                    { icon: "󰨸", label: "Grammar rules", detail: "25,000+ pair and triple patterns" },
                    { icon: "󰒡", label: "N-grams + phrases", detail: "48,000 bigrams, 787 phrase completions" },
                    { icon: "󰈸", label: "Emoji shortcodes", detail: "303 entries (:smile → 😊)" },
                    { icon: "󰔠", label: "Your learned words", detail: "Saved to ~/.local/share/linuxcomplete/" }
                ]
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: modelData.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: "#a6e3a1"
                        Layout.preferredWidth: 20
                    }
                    Text {
                        font.family: Theme.fontFamily
                        text: modelData.label
                        color: SettingsPalette.text
                        font.pixelSize: 11
                        font.bold: true
                        Layout.preferredWidth: 150
                    }
                    Text {
                        font.family: Theme.fontFamily
                        text: modelData.detail
                        color: SettingsPalette.subtext
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 8

            Item { Layout.fillWidth: true }

            Rectangle {
                id: activateButton
                Layout.preferredWidth: 180
                Layout.preferredHeight: 36
                radius: 8
                color: localSaveArea.containsMouse
                    ? Qt.rgba(166/255, 227/255, 161/255, 0.25)
                    : Qt.rgba(166/255, 227/255, 161/255, 0.15)
                border.color: "#a6e3a1"
                border.width: 1
                enabled: localPanel.saveStatus !== "saving"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰒘"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: "#a6e3a1"
                    }
                    Text {
                        font.family: Theme.fontFamily
                        text: localPanel.saveStatus === "saving" ? "Saving..." : "Activate Local-Only Mode"
                        color: "#a6e3a1"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                MouseArea {
                    id: localSaveArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: activateButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (activateButton.enabled) localPanel.activateRequested()
                }
            }
        }

        // Status message for local mode save
        Rectangle {
            visible: localPanel.saveStatus !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: localStatusText.implicitHeight + 16
            radius: 6
            color: Qt.rgba(0, 0, 0, 0.2)
            border.color: localPanel.saveStatus === "saved"
                ? Qt.rgba(166/255, 227/255, 161/255, 0.4)
                : Qt.rgba(243/255, 139/255, 168/255, 0.4)
            border.width: 1
            Text {
                font.family: Theme.fontFamily
                id: localStatusText
                anchors.fill: parent
                anchors.margins: 8
                text: "💾 " + (localPanel.saveStatus === "saved" ? "✓ " : (localPanel.saveStatus === "error" ? "✗ " : "… ")) + localPanel.saveMessage
                color: {
                    if (localPanel.saveStatus === "saved") return "#a6e3a1";
                    if (localPanel.saveStatus === "error") return "#f38ba8";
                    return SettingsPalette.text;
                }
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
    }
}
