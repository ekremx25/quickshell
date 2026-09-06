import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "."
import "../../../../Widgets"

Rectangle {
    id: root
    UsageBackend { id: backend }
    width: layout.implicitWidth + 16
    height: 30
    color: Theme.cpBlue // Blue
    radius: 14

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: mainText
            text: backend.totalUsage
            font.bold: true
            font.family: Theme.fontFamily
            color: Theme.foregroundFor(root.color)
        }
        Text {
            font.family: Theme.iconFontFamily
            text: ""
            font.pixelSize: 14
            color: Theme.foregroundFor(root.color)
        }
    }

    // --- MOUSE & TOOLTIP (LIST VIEW) ---
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        ToolTip {
            visible: parent.containsMouse
            delay: 100
            padding: 0 // We will manage padding ourselves

            background: Rectangle {
                color: Theme.cpBase // Dark Background
                border.color: Theme.cpBlue // Blue Border
                radius: 8
                opacity: 0.95
            }

            // --- BOX THAT PREVENTS CLIPPING ---
            contentItem: Item {
                // Whatever the content is, leave 30px width and 20px height padding around it
                implicitWidth: internalCol.implicitWidth + 30
                implicitHeight: internalCol.implicitHeight + 20

                ColumnLayout {
                    id: internalCol
                    anchors.centerIn: parent
                    spacing: 8

                    // Title
                    Text {
                        text: "Total Load: " + mainText.text
                        font.bold: true
                        font.family: Theme.fontFamily
                        color: Theme.cpMauve
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Line
                    Rectangle { height: 1; width: parent.width; color: "gray"; opacity: 0.5 }

                    // LIST LAYOUT (2 COLUMNS)
                    GridLayout {
                        columns: 2  // Made it two columns (Gives long list feel but fits)
                        columnSpacing: 25 // Spacing between columns
                        rowSpacing: 2     // Spacing between rows

                        Repeater {
                            model: backend.coreModel
                            Row {
                                spacing: 10 // Spacing between Name and Percentage
                                Text {
                                    text: model.name
                                    color: Theme.cpSubtext1
                                    font.pixelSize: 12
                                    font.family: Theme.fontFamily
                                    width: 50 // Fixed width (so alignment is clean)
                                }
                                Text {
                                    text: model.usage
                                    color: Theme.cpGreen // Green Numbers
                                    font.bold: true
                                    font.pixelSize: 12
                                    font.family: Theme.fontFamily
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
