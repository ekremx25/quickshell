import QtQuick
import QtQuick.Layouts
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

// Draggable monitor layout canvas card.
// All state access flows through the `page` reference.
Rectangle {
    id: root
    required property var page

    radius: 16
    color: page.cardColor
    border.color: page.cardBorder
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    font.family: Theme.fontFamily
                    text: "Rearrange your displays"
                    color: SettingsPalette.text
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    font.family: Theme.fontFamily
                    text: "Drag the display tiles to match how your monitors are physically placed on your desk."
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.04)
                border.color: page.softBorder
                border.width: 1
                implicitWidth: hintText.implicitWidth + 16
                implicitHeight: 30

                Text {
                    font.family: Theme.fontFamily
                    id: hintText
                    anchors.centerIn: parent
                    text: "Tip: select a display, then drag to snap"
                    color: SettingsPalette.subtext
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: Qt.rgba(12 / 255, 15 / 255, 21 / 255, 0.55)
            border.color: Qt.rgba(255, 255, 255, 0.06)
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: parent.radius - 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(45 / 255, 53 / 255, 69 / 255, 0.45) }
                    GradientStop { position: 1.0; color: Qt.rgba(16 / 255, 21 / 255, 29 / 255, 0.20) }
                }
            }

            Item {
                id: layoutCanvas
                anchors.fill: parent
                anchors.margins: 12

                Repeater {
                    model: page.outputs

                    Rectangle {
                        required property var modelData
                        required property int index
                        property real dragOffsetX: 0
                        property real dragOffsetY: 0

                        x: page.boxXForOutput(modelData, layoutCanvas.width, layoutCanvas.height)
                        y: page.boxYForOutput(modelData, layoutCanvas.width, layoutCanvas.height)
                        width: page.boxWidthForOutput(modelData, layoutCanvas.width, layoutCanvas.height)
                        height: page.boxHeightForOutput(modelData, layoutCanvas.width, layoutCanvas.height)
                        radius: 14
                        color: page.selectedIdx === index ? Qt.rgba(65 / 255, 101 / 255, 166 / 255, 0.60) : Qt.rgba(65 / 255, 72 / 255, 84 / 255, 0.78)
                        border.color: page.selectedIdx === index ? "#8dbbff" : Qt.rgba(255, 255, 255, 0.16)
                        border.width: page.selectedIdx === index ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    width: 26; height: 26; radius: 8
                                    color: Qt.rgba(255, 255, 255, page.selectedIdx === index ? 0.18 : 0.10)
                                    border.color: Qt.rgba(255, 255, 255, 0.22)
                                    border.width: 1

                                    Text {
                                        font.family: Theme.fontFamily
                                        anchors.centerIn: parent
                                        text: page.monitorLabel(index)
                                        color: "white"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    visible: page.defaultMonitorName === modelData.name
                                    radius: 7
                                    color: Qt.rgba(255, 255, 255, 0.12)
                                    border.color: Qt.rgba(255, 255, 255, 0.18)
                                    border.width: 1
                                    implicitWidth: mainText.implicitWidth + 14
                                    implicitHeight: 24

                                    Text {
                                        font.family: Theme.fontFamily
                                        id: mainText
                                        anchors.centerIn: parent
                                        text: "Main display"
                                        color: "white"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                font.family: Theme.fontFamily
                                text: modelData.name
                                color: "white"
                                font.pixelSize: Math.max(13, Math.min(17, parent.width / 7))
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                font.family: Theme.fontFamily
                                text: page.effectiveWidth(modelData) + " x " + page.effectiveHeight(modelData)
                                color: Qt.rgba(255, 255, 255, 0.86)
                                font.pixelSize: 10
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                font.family: Theme.fontFamily
                                text: Math.round(page.outputPosX(modelData)) + ", " + Math.round(page.outputPosY(modelData))
                                color: Qt.rgba(255, 255, 255, 0.74)
                                font.pixelSize: 10
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Item { Layout.fillHeight: true }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width * 0.45, 86)
                            height: width
                            radius: width / 2
                            color: Qt.rgba(11 / 255, 17 / 255, 26 / 255, 0.88)
                            border.color: Qt.rgba(255, 255, 255, 0.28)
                            border.width: 2
                            visible: page.identifyMode
                            opacity: page.identifyMode ? 1 : 0

                            Behavior on opacity { NumberAnimation { duration: 160 } }

                            Text {
                                font.family: Theme.fontFamily
                                anchors.centerIn: parent
                                text: page.monitorLabel(index)
                                color: "white"
                                font.pixelSize: Math.max(24, parent.width * 0.34)
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            onPressed: function(mouse) {
                                page.selectOutput(index);
                                parent.dragOffsetX = mouse.x;
                                parent.dragOffsetY = mouse.y;
                            }
                            onPositionChanged: function(mouse) {
                                if (!pressed) return;
                                page.selectOutput(index);
                                var newX = page.canvasToLayoutX(parent.x + mouse.x - parent.dragOffsetX, layoutCanvas.width, layoutCanvas.height);
                                var newY = page.canvasToLayoutY(parent.y + mouse.y - parent.dragOffsetY, layoutCanvas.width, layoutCanvas.height);
                                var snapped = page.snapDraggedPosition(modelData.name, newX, newY);
                                if (page.selectedOutput && page.selectedOutput.name === modelData.name) {
                                    page.selPosX = snapped.x;
                                    page.selPosY = snapped.y;
                                }
                            }
                            onClicked: page.selectOutput(index)
                        }
                    }
                }
            }
        }
    }
}
