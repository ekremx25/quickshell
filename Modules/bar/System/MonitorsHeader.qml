import QtQuick
import QtQuick.Layouts
import "../Settings/SettingsPalette.js" as SettingsPalette
import "../../../Widgets"

// Header card at the top of the Displays page.
// Shows display count, a status pill (unsaved / up to date), and refresh /
// identify actions. All state is read through `page`.
Rectangle {
    id: root
    required property var page

    radius: 14
    color: page.cardColor
    border.color: page.cardBorder
    border.width: 1
    implicitHeight: headerContent.implicitHeight + 28

    RowLayout {
        id: headerContent
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Rectangle {
            width: 42
            height: 42
            radius: 12
            color: root.page.accentSoft
            border.color: root.page.accentBorder
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.page.outputs.length
                color: Theme.primary
                font.pixelSize: 18
                font.bold: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: "Displays"
                color: SettingsPalette.text
                font.pixelSize: 20
                font.bold: true
            }

            Text {
                text: root.page.selectedOutput
                    ? (root.page.displayCountText() + " connected. Arrange your displays, choose the main screen, and tune resolution, scale, and color.")
                    : "No active display detected."
                color: SettingsPalette.subtext
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Rectangle {
            visible: root.page.selectedOutput !== null
            radius: 9
            color: root.page.pendingChanges() ? root.page.accentSoft : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.16)
            border.color: root.page.pendingChanges() ? root.page.accentBorder : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.55)
            border.width: 1
            implicitWidth: statusText.implicitWidth + 20
            implicitHeight: 34

            Text {
                id: statusText
                anchors.centerIn: parent
                text: root.page.pendingChanges() ? "Unsaved changes" : "Up to date"
                color: root.page.pendingChanges() ? Theme.primary : "#a6e3a1"
                font.pixelSize: 12
                font.bold: true
            }
        }

        Rectangle {
            width: 38
            height: 38
            radius: 10
            color: refreshArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
            border.color: root.page.softBorder
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "R"
                color: SettingsPalette.text
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                id: refreshArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.page.refresh()
            }
        }

        Rectangle {
            radius: 10
            color: identifyHeaderArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
            border.color: root.page.softBorder
            border.width: 1
            implicitWidth: identifyHeaderText.implicitWidth + 20
            implicitHeight: 38

            Text {
                id: identifyHeaderText
                anchors.centerIn: parent
                text: "Identify"
                color: SettingsPalette.text
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                id: identifyHeaderArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.page.triggerIdentify()
            }
        }
    }
}
