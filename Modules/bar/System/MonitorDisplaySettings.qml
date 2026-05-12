import QtQuick
import QtQuick.Layouts
import "../Settings/SettingsPalette.js" as SettingsPalette
import "../../../Widgets"

// Display settings card: resolution, refresh rate, scale, position.
// All state read/write flows through the `page` reference.
Rectangle {
    id: root
    required property var page

    radius: 14
    color: page.cardColor
    border.color: page.cardBorder
    border.width: 1
    implicitHeight: displaySettings.implicitHeight + 28

    ColumnLayout {
        id: displaySettings
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                font.family: Theme.fontFamily
                text: "Display settings"
                color: SettingsPalette.text
                font.pixelSize: 15
                font.bold: true
            }

            Text {
                font.family: Theme.fontFamily
                text: page.selectedOutput
                    ? "Choose the sharpest mode first, then tune scale and placement."
                    : "Select a display above to edit its settings."
                color: SettingsPalette.subtext
                font.pixelSize: 11
            }
        }

        // Resolution selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                font.family: Theme.fontFamily
                text: "Display resolution"
                color: SettingsPalette.subtext
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 130
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: page.getUniqueRes()

                    Rectangle {
                        required property string modelData
                        radius: 9
                        color: page.selRes === modelData ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                        border.color: page.selRes === modelData ? page.accentBorder : page.softBorder
                        border.width: 1
                        implicitWidth: resolutionText.implicitWidth + 22
                        implicitHeight: 34

                        Text {
                            font.family: Theme.fontFamily
                            id: resolutionText
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            text: modelData.replace("x", " x ")
                            color: page.selRes === modelData ? Theme.primary : SettingsPalette.text
                            font.pixelSize: 12
                            font.bold: page.selRes === modelData
                        }

                        Rectangle {
                            visible: page.isRecommendedResolution(modelData)
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            radius: 6
                            color: page.selRes === modelData ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.16)
                            border.color: page.selRes === modelData ? Qt.rgba(255, 255, 255, 0.26) : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.44)
                            border.width: 1
                            implicitWidth: recommendedText.implicitWidth + 12
                            implicitHeight: 20

                            Text {
                                font.family: Theme.fontFamily
                                id: recommendedText
                                anchors.centerIn: parent
                                text: "Recommended"
                                color: page.selRes === modelData ? "white" : "#a6e3a1"
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.selRes = modelData;
                                var rates = page.getRefreshRates();
                                var safe = rates[0];
                                page.selHz = safe ? safe.hz : page.selHz;
                            }
                        }
                    }
                }
            }
        }

        // Refresh rate selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                font.family: Theme.fontFamily
                text: "Refresh rate"
                color: SettingsPalette.subtext
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 130
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: page.getRefreshRates()

                    Rectangle {
                        required property var modelData
                        radius: 9
                        color: page.selHz === modelData.hz ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                        border.color: page.selHz === modelData.hz ? page.accentBorder : page.softBorder
                        border.width: 1
                        implicitWidth: refreshText.implicitWidth + 22
                        implicitHeight: 34

                        Text {
                            font.family: Theme.fontFamily
                            id: refreshText
                            anchors.centerIn: parent
                            text: parseFloat(modelData.hz).toFixed(1) + " Hz"
                            color: page.selHz === modelData.hz ? Theme.primary : SettingsPalette.text
                            font.pixelSize: 12
                            font.bold: page.selHz === modelData.hz
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.selHz = modelData.hz
                        }
                    }
                }
            }
        }

        // Scale selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                font.family: Theme.fontFamily
                text: "Scale"
                color: SettingsPalette.subtext
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 130
            }

            ScaleSelector {
                Layout.fillWidth: true
                scaleOptions: page.getScaleCandidates()
                selectedScale: page.selScale
                summaryText: page.selectedScalePercentText()
                detailText: page.selectedScaleResolutionText()
                helperText: page.scaleSupportText()
                canStepDown: page.canStepScale(-1)
                canStepUp: page.canStepScale(1)
                onScaleSelected: value => page.setScaleValue(value)
                onStepRequested: direction => page.stepScale(direction)
            }
        }

        // Position controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                font.family: Theme.fontFamily
                text: "Position"
                color: SettingsPalette.subtext
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 130
            }

            RowLayout {
                spacing: 6

                Repeater {
                    model: [
                        { label: "X-", axis: "x", delta: -100 },
                        { label: "X+", axis: "x", delta: 100 },
                        { label: "Y-", axis: "y", delta: -100 },
                        { label: "Y+", axis: "y", delta: 100 }
                    ]

                    Rectangle {
                        required property var modelData
                        radius: 8
                        color: buttonArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
                        border.color: page.softBorder
                        border.width: 1
                        implicitWidth: 44
                        implicitHeight: 32

                        Text {
                            font.family: Theme.fontFamily
                            anchors.centerIn: parent
                            text: modelData.label
                            color: SettingsPalette.text
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: buttonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.adjustSelectedPosition(modelData.axis, modelData.delta)
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.03)
                border.color: page.softBorder
                border.width: 1
                implicitWidth: 90
                implicitHeight: 32

                Text {
                    font.family: Theme.fontFamily
                    anchors.centerIn: parent
                    text: "X: " + page.selPosX
                    color: SettingsPalette.text
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Rectangle {
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.03)
                border.color: page.softBorder
                border.width: 1
                implicitWidth: 90
                implicitHeight: 32

                Text {
                    font.family: Theme.fontFamily
                    anchors.centerIn: parent
                    text: "Y: " + page.selPosY
                    color: SettingsPalette.text
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Rectangle {
                radius: 8
                color: resetYArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
                border.color: page.softBorder
                border.width: 1
                implicitWidth: 86
                implicitHeight: 32

                Text {
                    font.family: Theme.fontFamily
                    anchors.centerIn: parent
                    text: "Reset Y"
                    color: SettingsPalette.text
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    id: resetYArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.selPosY = 0
                }
            }
        }
    }
}
