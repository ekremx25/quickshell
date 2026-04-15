import QtQuick
import QtQuick.Layouts
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

Item {
    id: root

    required property var scaleOptions
    required property real selectedScale
    required property string summaryText
    required property string detailText
    required property string helperText
    required property bool canStepDown
    required property bool canStepUp

    signal scaleSelected(real value)
    signal stepRequested(int direction)

    implicitWidth: selectorLayout.implicitWidth
    implicitHeight: selectorLayout.implicitHeight

    readonly property color chipColor: Qt.rgba(255, 255, 255, 0.03)
    readonly property color chipBorder: Qt.rgba(255, 255, 255, 0.05)
    readonly property color activeChipColor: Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.14)
    readonly property color activeChipBorder: Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.55)

    function isSelected(value) {
        return Math.abs(root.selectedScale - value) < 0.01;
    }

    ColumnLayout {
        id: selectorLayout
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                radius: 9
                color: downArea.containsMouse && root.canStepDown ? Qt.rgba(255, 255, 255, 0.08) : root.chipColor
                border.color: root.canStepDown ? root.chipBorder : Qt.rgba(255, 255, 255, 0.03)
                border.width: 1
                implicitWidth: 34
                implicitHeight: 34

                Text {
                    anchors.centerIn: parent
                    text: "-"
                    color: root.canStepDown ? SettingsPalette.text : SettingsPalette.subtext
                    font.pixelSize: 16
                    font.bold: true
                }

                MouseArea {
                    id: downArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.canStepDown
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.stepRequested(-1)
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.scaleOptions

                    Rectangle {
                        required property real modelData
                        radius: 9
                        color: root.isSelected(modelData) ? root.activeChipColor : root.chipColor
                        border.color: root.isSelected(modelData) ? root.activeChipBorder : root.chipBorder
                        border.width: 1
                        implicitWidth: chipLabel.implicitWidth + 22
                        implicitHeight: 34

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: Math.round(modelData * 100) + "%"
                            color: root.isSelected(modelData) ? Theme.primary : SettingsPalette.text
                            font.pixelSize: 11
                            font.bold: root.isSelected(modelData)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.scaleSelected(modelData)
                        }
                    }
                }
            }

            Rectangle {
                radius: 9
                color: upArea.containsMouse && root.canStepUp ? Qt.rgba(255, 255, 255, 0.08) : root.chipColor
                border.color: root.canStepUp ? root.chipBorder : Qt.rgba(255, 255, 255, 0.03)
                border.width: 1
                implicitWidth: 34
                implicitHeight: 34

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: root.canStepUp ? SettingsPalette.text : SettingsPalette.subtext
                    font.pixelSize: 16
                    font.bold: true
                }

                MouseArea {
                    id: upArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.canStepUp
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.stepRequested(1)
                }
            }

            Rectangle {
                radius: 10
                color: root.activeChipColor
                border.color: root.activeChipBorder
                border.width: 1
                implicitWidth: 96
                implicitHeight: 42

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 1

                    Text {
                        text: root.summaryText
                        color: Theme.primary
                        font.pixelSize: 13
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.detailText
                        color: SettingsPalette.subtext
                        font.pixelSize: 10
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        Text {
            text: root.helperText
            color: SettingsPalette.subtext
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
