import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "SettingsPalette.js" as SettingsPalette
import "../../../Widgets"

// Panel shown for any non-local provider.
// Owns the API-base / model / API-key form and the test + save buttons.
// Pure view component — emits change signals, does not write files itself.
Item {
    id: remotePanel

    required property string selectedProviderId
    required property var currentProvider

    // Two-way-ish state: remotePanel reads these, and emits *Changed signals
    // when the user edits a field. The owning page re-assigns them back.
    property string apiBase: ""
    property string modelValue: ""
    property string apiKey: ""
    property bool keyVisible: false

    property string testStatus: ""
    property string testMessage: ""
    property string saveStatus: ""
    property string saveMessage: ""

    signal apiBaseEdited(string v)
    signal modelEdited(string v)
    signal apiKeyEdited(string v)
    signal keyVisibilityToggled()
    signal testRequested()
    signal saveRequested()

    implicitHeight: detailsBox.implicitHeight

    Rectangle {
        id: detailsBox
        anchors.fill: parent
        implicitHeight: detailsColumn.implicitHeight + 32
        radius: 12
        color: Qt.rgba(255, 255, 255, 0.025)
        border.color: Qt.rgba(255, 255, 255, 0.06)
        border.width: 1

        ColumnLayout {
            id: detailsColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Get API key link
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: remotePanel.currentProvider.signup_url.length > 0

                Text {
                    font.family: Theme.fontFamily
                    text: "Get an API key: "
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                }
                Rectangle {
                    Layout.preferredWidth: linkText.implicitWidth + 16
                    Layout.preferredHeight: 24
                    radius: 6
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                    border.width: 1
                    Text {
                        font.family: Theme.fontFamily
                        id: linkText
                        anchors.centerIn: parent
                        text: remotePanel.currentProvider.signup_url
                        color: Theme.primary
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(remotePanel.currentProvider.signup_url)
                    }
                }
            }

            // Model picker
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    font.family: Theme.fontFamily
                    text: "Model"
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                    Layout.preferredWidth: 80
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: remotePanel.currentProvider.models.length > 0

                    Repeater {
                        model: remotePanel.currentProvider.models
                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool isSelected: remotePanel.modelValue === modelData
                            implicitWidth: modelLabel.implicitWidth + 20
                            implicitHeight: 28
                            radius: 6
                            color: isSelected
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                : Qt.rgba(255, 255, 255, 0.04)
                            border.color: isSelected
                                ? Theme.primary
                                : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1

                            Text {
                                font.family: Theme.fontFamily
                                id: modelLabel
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: parent.isSelected ? Theme.primary : SettingsPalette.text
                                font.pixelSize: 11
                                font.bold: parent.isSelected
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: remotePanel.modelEdited(parent.modelData)
                            }
                        }
                    }
                }

                // For custom provider: editable model field
                Rectangle {
                    visible: remotePanel.selectedProviderId === "custom"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 6
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.1)
                    border.width: 1

                    TextInput {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: SettingsPalette.text
                        font.pixelSize: 12
                        text: remotePanel.modelValue
                        selectByMouse: true
                        onTextChanged: remotePanel.modelEdited(text)
                    }
                }
            }

            // API Base URL (editable for custom)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    font.family: Theme.fontFamily
                    text: "API Base"
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                    Layout.preferredWidth: 80
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 6
                    color: remotePanel.selectedProviderId === "custom"
                        ? Qt.rgba(255, 255, 255, 0.04)
                        : Qt.rgba(255, 255, 255, 0.02)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    TextInput {
                        id: baseInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: SettingsPalette.text
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                        text: remotePanel.apiBase
                        selectByMouse: true
                        readOnly: remotePanel.selectedProviderId !== "custom"
                        onTextChanged: if (!readOnly) remotePanel.apiBaseEdited(text)
                    }
                }
            }

            // API Key input
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    font.family: Theme.fontFamily
                    text: "API Key"
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                    Layout.preferredWidth: 80
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 6
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: keyInput.activeFocus
                        ? Theme.primary
                        : Qt.rgba(255, 255, 255, 0.1)
                    border.width: 1

                    TextInput {
                        id: keyInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: SettingsPalette.text
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                        text: remotePanel.apiKey
                        selectByMouse: true
                        echoMode: remotePanel.keyVisible ? TextInput.Normal : TextInput.Password
                        onTextChanged: remotePanel.apiKeyEdited(text)
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: keyInput.text.length === 0 && !keyInput.activeFocus
                            text: remotePanel.currentProvider.key_example
                            color: SettingsPalette.overlay2
                            font: keyInput.font
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 6
                    color: remotePanel.keyVisible
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        : Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.1)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: remotePanel.keyVisible ? "󰈈" : "󰈉"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: remotePanel.keyVisible ? Theme.primary : SettingsPalette.subtext
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: remotePanel.keyVisibilityToggled()
                    }
                }
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8

                // Test connection
                Rectangle {
                    id: testButton
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 36
                    radius: 8
                    color: testArea.containsMouse
                        ? Qt.rgba(255, 255, 255, 0.08)
                        : Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.12)
                    border.width: 1
                    enabled: remotePanel.testStatus !== "testing"
                    opacity: enabled ? 1 : 0.5

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: remotePanel.testStatus === "testing" ? "󰑮" : "🧪"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: SettingsPalette.text
                            RotationAnimation on rotation {
                                running: remotePanel.testStatus === "testing"
                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                            }
                        }
                        Text {
                            font.family: Theme.fontFamily
                            text: remotePanel.testStatus === "testing" ? "Testing..." : "Test connection"
                            color: SettingsPalette.text
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: testArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: testButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (testButton.enabled) remotePanel.testRequested()
                    }
                }

                Item { Layout.fillWidth: true }

                // Save & activate
                Rectangle {
                    id: saveButton
                    Layout.preferredWidth: 160
                    Layout.preferredHeight: 36
                    radius: 8
                    color: saveArea.containsMouse
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    border.color: Theme.primary
                    border.width: 1
                    enabled: remotePanel.saveStatus !== "saving" && remotePanel.apiKey.length > 0

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "💾"
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.primary
                        }
                        Text {
                            font.family: Theme.fontFamily
                            text: remotePanel.saveStatus === "saving" ? "Saving..." : "Save & Activate"
                            color: Theme.primary
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: saveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: saveButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (saveButton.enabled) remotePanel.saveRequested()
                    }
                }
            }

            // Status messages
            Rectangle {
                visible: remotePanel.testStatus !== "" || remotePanel.saveStatus !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: statusCol.implicitHeight + 20
                radius: 8
                color: Qt.rgba(0, 0, 0, 0.2)
                border.color: {
                    if (remotePanel.testStatus === "success" || remotePanel.saveStatus === "saved") {
                        return Qt.rgba(166/255, 227/255, 161/255, 0.4);
                    }
                    if (remotePanel.testStatus === "error" || remotePanel.saveStatus === "error") {
                        return Qt.rgba(243/255, 139/255, 168/255, 0.4);
                    }
                    return Qt.rgba(255, 255, 255, 0.08);
                }
                border.width: 1

                ColumnLayout {
                    id: statusCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        font.family: Theme.fontFamily
                        visible: remotePanel.testStatus !== ""
                        text: "🧪 " + (remotePanel.testStatus === "success" ? "✓ " : (remotePanel.testStatus === "error" ? "✗ " : "… ")) + remotePanel.testMessage
                        color: {
                            if (remotePanel.testStatus === "success") return "#a6e3a1";
                            if (remotePanel.testStatus === "error") return "#f38ba8";
                            return SettingsPalette.text;
                        }
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Text {
                        font.family: Theme.fontFamily
                        visible: remotePanel.saveStatus !== ""
                        text: "💾 " + (remotePanel.saveStatus === "saved" ? "✓ " : (remotePanel.saveStatus === "error" ? "✗ " : "… ")) + remotePanel.saveMessage
                        color: {
                            if (remotePanel.saveStatus === "saved") return "#a6e3a1";
                            if (remotePanel.saveStatus === "error") return "#f38ba8";
                            return SettingsPalette.text;
                        }
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
