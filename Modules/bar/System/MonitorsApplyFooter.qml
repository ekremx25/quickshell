import QtQuick
import QtQuick.Layouts
import "../Settings/SettingsPalette.js" as SettingsPalette
import "../../../Widgets"

// Bottom footer with status copy + Revert / Apply buttons.
// All state is read through `page`; the buttons call back into `page` methods.
Rectangle {
    id: root
    required property var page

    radius: 14
    color: page.cardColor
    border.color: page.cardBorder
    border.width: 1
    implicitHeight: 72

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.page.pendingChanges()
                    ? "Review your changes before applying them."
                    : "Your current display configuration is saved."
                color: SettingsPalette.text
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                text: root.page.selectedOutput
                    ? ("Selected display: " + root.page.selectedOutput.name + " | Position " + root.page.selPosX + ", " + root.page.selPosY)
                    : "No display selected."
                color: SettingsPalette.subtext
                font.pixelSize: 11
            }
        }

        Rectangle {
            radius: 10
            color: revertArea.enabled
                ? (revertArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03))
                : Qt.rgba(255, 255, 255, 0.02)
            border.color: revertArea.enabled ? root.page.softBorder : Qt.rgba(255, 255, 255, 0.03)
            border.width: 1
            implicitWidth: 90
            implicitHeight: 40

            Text {
                anchors.centerIn: parent
                text: "Revert"
                color: revertArea.enabled ? SettingsPalette.text : SettingsPalette.subtext
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                id: revertArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.page.selectedOutput !== null && root.page.pendingChanges()
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.page.syncSelection()
            }
        }

        Rectangle {
            radius: 10
            color: applyArea.enabled
                ? (applyArea.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
                : Qt.rgba(255, 255, 255, 0.08)
            border.color: applyArea.enabled ? Qt.lighter(Theme.primary, 1.2) : Qt.rgba(255, 255, 255, 0.05)
            border.width: 1
            implicitWidth: 118
            implicitHeight: 40

            Text {
                anchors.centerIn: parent
                text: root.page.pendingChanges() ? "Apply" : "Saved"
                color: applyArea.enabled ? "#11151b" : SettingsPalette.subtext
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                id: applyArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.page.selectedOutput !== null && root.page.pendingChanges()
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.page.applySettings()
            }
        }
    }
}
