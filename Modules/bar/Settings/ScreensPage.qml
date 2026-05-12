import QtQuick
import QtQuick.Layouts
import "SettingsPalette.js" as SettingsPalette
import Quickshell
import "../../../Widgets"
import "../../../Services"

Item {
    id: screensPage

    readonly property var componentIds: ["bar", "dock", "workspaces", "notifications", "weather", "toast", "osd", "appdrawer"]
    readonly property var componentIcons: ({
        "bar": "󰒍",
        "dock": "⚓",
        "workspaces": "󰖲",
        "notifications": "󰂚",
        "weather": "󰖕",
        "toast": "󱅫",
        "osd": "󰕾",
        "appdrawer": "󰀻"
    })

    function toggleScreenSelection(currentPref, screenName) {
        var current = (currentPref || []).slice();
        if (current.indexOf("all") !== -1 || current.indexOf("none") !== -1) {
            current = [];
        }

        var idx = current.indexOf(screenName);
        if (idx !== -1) {
            current.splice(idx, 1);
        } else {
            current.push(screenName);
        }

        return current.length === 0 ? ["all"] : current;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "󰍹"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
            Text {  text: "Screen Preferences"; font.bold: true; font.pixelSize: 18; color: SettingsPalette.text; font.family: Theme.fontFamily }
        }

        Text {
            font.family: Theme.fontFamily
            text: "Choose which screens display each component. 'All' shows on every connected monitor."
            color: SettingsPalette.overlay2
            font.pixelSize: 12
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // Connected screens info
        Rectangle {
            Layout.fillWidth: true
            height: screenInfoRow.height + 16
            radius: 8
            color: Qt.rgba(137/255, 180/255, 250/255, 0.08)

            RowLayout {
                id: screenInfoRow
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 12
                spacing: 8

                Text { text: "󰍹"; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                Text {  text: "Connected: " + Quickshell.screens.length + " screen(s)"; font.pixelSize: 12; color: SettingsPalette.text; font.family: Theme.fontFamily }
                Item { Layout.fillWidth: true }

                Repeater {
                    model: ScreenManager.getAvailableScreenNames()
                    Rectangle {
                        width: screenNameText.width + 14; height: 22; radius: 6
                        color: Qt.rgba(255,255,255,0.08)
                        Text {  id: screenNameText; anchors.centerIn: parent; text: modelData; font.pixelSize: 10; color: SettingsPalette.subtext; font.family: Theme.fontFamily }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: SettingsPalette.surface }

        // Per-component screen selection
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: componentColumn.height
            clip: true

            ColumnLayout {
                id: componentColumn
                width: parent.width
                spacing: 8

                Repeater {
                    model: screensPage.componentIds

                    Rectangle {
                        Layout.fillWidth: true
                        height: compContent.height + 24
                        radius: 10
                        color: Qt.rgba(255,255,255,0.03)
                        border.color: Qt.rgba(255,255,255,0.06)
                        border.width: 1

                        property string compId: modelData
                        property var currentPref: ScreenManager.screenPreferences[modelData] || ["all"]

                        ColumnLayout {
                            id: compContent
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: screensPage.componentIcons[compId] || "?"
                                    font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary
                                }
                                Text {
                                    font.family: Theme.fontFamily
                                    text: compId.charAt(0).toUpperCase() + compId.slice(1)
                                    font.pixelSize: 14; font.bold: true; color: SettingsPalette.text
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    font.family: Theme.fontFamily
                                    text: currentPref.indexOf("all") !== -1 ? "All screens" : currentPref.join(", ")
                                    font.pixelSize: 11; color: SettingsPalette.overlay2
                                }
                            }

                            // Screen selection buttons
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                // "All" button
                                Rectangle {
                                    width: allText.width + 18; height: 28; radius: 8
                                    color: currentPref.indexOf("all") !== -1 ? Qt.rgba(137/255, 180/255, 250/255, 0.2) : Qt.rgba(255,255,255,0.06)
                                    border.color: currentPref.indexOf("all") !== -1 ? Theme.primary : "transparent"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {  id: allText; anchors.centerIn: parent; text: "All"; font.pixelSize: 11; color: currentPref.indexOf("all") !== -1 ? Theme.primary : SettingsPalette.subtext; font.family: Theme.fontFamily }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: ScreenManager.setScreenPreference(compId, ["all"])
                                    }
                                }

                                // "Disable" button
                                Rectangle {
                                    width: disableText.width + 18; height: 28; radius: 8
                                    color: currentPref.indexOf("none") !== -1 ? Qt.rgba(243/255, 139/255, 168/255, 0.2) : Qt.rgba(255,255,255,0.06)
                                    border.color: currentPref.indexOf("none") !== -1 ? Theme.red : "transparent"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {  id: disableText; anchors.centerIn: parent; text: "Disable"; font.pixelSize: 11; color: currentPref.indexOf("none") !== -1 ? Theme.red : SettingsPalette.subtext; font.family: Theme.fontFamily }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: ScreenManager.setScreenPreference(compId, ["none"])
                                    }
                                }

                                // Per-screen buttons
                                Repeater {
                                    model: ScreenManager.getAvailableScreenNames()

                                    Rectangle {
                                        property bool isSelected: currentPref.indexOf(modelData) !== -1 && currentPref.indexOf("all") === -1
                                        width: scrText.width + 18; height: 28; radius: 8
                                        color: isSelected ? Qt.rgba(166/255, 227/255, 161/255, 0.2) : Qt.rgba(255,255,255,0.06)
                                        border.color: isSelected ? Theme.green : "transparent"
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {  id: scrText; anchors.centerIn: parent; text: modelData; font.pixelSize: 11; color: isSelected ? Theme.green : SettingsPalette.subtext; font.family: Theme.fontFamily }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                ScreenManager.setScreenPreference(
                                                    compId,
                                                    screensPage.toggleScreenSelection(currentPref, modelData)
                                                );
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
