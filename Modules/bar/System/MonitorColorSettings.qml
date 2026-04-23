import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Settings/SettingsPalette.js" as SettingsPalette
import "../../../Widgets"
import "../../../Services"

// Advanced color settings card for Hyprland (HDR, bit depth, VRR, color profile, SDR sliders).
// Visibility is managed internally (visible only on Hyprland).
// All state read/write flows through the `page` reference.
Rectangle {
    id: root
    required property var page

    radius: 14
    color: page.cardColor
    border.color: page.cardBorder
    border.width: 1
    visible: CompositorService.isHyprland
    implicitHeight: advancedSettings.implicitHeight + 28

    ColumnLayout {
        id: advancedSettings
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Text {
            font.family: Theme.fontFamily
            text: "Advanced color"
            color: SettingsPalette.text
            font.pixelSize: 15
            font.bold: true
        }

        // HDR toggle
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                font.family: Theme.fontFamily
                text: "HDR"
                color: SettingsPalette.subtext
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 130
            }

            Rectangle {
                width: 48
                height: 28
                radius: 14
                color: page.selHdr ? Theme.primary : Qt.rgba(255, 255, 255, 0.10)

                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    x: page.selHdr ? parent.width - width - 3 : 3
                    color: "white"
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        page.selHdr = !page.selHdr;
                        if (page.selHdr) page.selColorManagement = "hdr";
                        else if (page.isHdrColorMode(page.selColorManagement) && page.selColorManagement !== "hdredid") page.selColorManagement = "srgb";
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                font.family: Theme.fontFamily
                text: page.selHdr ? "High dynamic range is enabled" : "Use SDR for a more stable desktop"
                color: SettingsPalette.subtext
                font.pixelSize: 11
            }
        }

        // Bit depth selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                font.family: Theme.fontFamily
                text: "Bit depth"
                color: SettingsPalette.subtext
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 130
            }

            Repeater {
                model: [8, 10]

                Rectangle {
                    required property int modelData
                    radius: 8
                    color: page.selBitdepth === modelData ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                    border.color: page.selBitdepth === modelData ? page.accentBorder : page.softBorder
                    border.width: 1
                    implicitWidth: 62
                    implicitHeight: 32

                    Text {
                        font.family: Theme.fontFamily
                        anchors.centerIn: parent
                        text: modelData + "-bit"
                        color: page.selBitdepth === modelData ? Theme.primary : SettingsPalette.text
                        font.pixelSize: 11
                        font.bold: page.selBitdepth === modelData
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.selBitdepth = modelData
                    }
                }
            }
        }

        // Variable refresh rate selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                font.family: Theme.fontFamily
                text: "Variable refresh rate"
                color: SettingsPalette.subtext
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 130
            }

            Repeater {
                model: [
                    { value: 0, label: "Off" },
                    { value: 1, label: "On" },
                    { value: 2, label: "Fullscreen only" }
                ]

                Rectangle {
                    required property var modelData
                    radius: 8
                    color: page.selVrr === modelData.value ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                    border.color: page.selVrr === modelData.value ? page.accentBorder : page.softBorder
                    border.width: 1
                    implicitWidth: vrrLabel.implicitWidth + 22
                    implicitHeight: 32

                    Text {
                        font.family: Theme.fontFamily
                        id: vrrLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        color: page.selVrr === modelData.value ? Theme.primary : SettingsPalette.text
                        font.pixelSize: 11
                        font.bold: page.selVrr === modelData.value
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.selVrr = modelData.value
                    }
                }
            }
        }

        // Color profile selector
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                font.family: Theme.fontFamily
                text: "Color profile"
                color: SettingsPalette.subtext
                font.pixelSize: 12
                font.bold: true
                Layout.preferredWidth: 130
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { value: "srgb",    label: "sRGB" },
                        { value: "default", label: "Default" },
                        { value: "hdr",     label: "HDR" },
                        { value: "dcip3",   label: "DCI-P3" },
                        { value: "hdredid", label: "HDR (EDID)" }
                    ]

                    Rectangle {
                        required property var modelData
                        radius: 8
                        color: page.selColorManagement === modelData.value ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                        border.color: page.selColorManagement === modelData.value ? page.accentBorder : page.softBorder
                        border.width: 1
                        implicitWidth: profileText.implicitWidth + 22
                        implicitHeight: 32

                        Text {
                            font.family: Theme.fontFamily
                            id: profileText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: page.selColorManagement === modelData.value ? Theme.primary : SettingsPalette.text
                            font.pixelSize: 11
                            font.bold: page.selColorManagement === modelData.value
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.selColorManagement = modelData.value;
                                if (page.isHdrColorMode(modelData.value)) page.selHdr = true;
                                else if (page.selHdr && !page.isHdrColorMode(modelData.value)) page.selHdr = false;
                            }
                        }
                    }
                }
            }
        }

        // SDR sliders (only visible when HDR is enabled)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: page.selHdr

            // SDR luminance
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Text {
                    font.family: Theme.fontFamily
                    text: "SDR luminance"
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                    font.bold: true
                    Layout.preferredWidth: 130
                }

                Item {
                    Layout.fillWidth: true
                    height: 32

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, (page.selSdrLuminance - page.sdrLuminanceMin) / Math.max(1, page.sdrLuminanceMax - page.sdrLuminanceMin)))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
                        }
                    }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * Math.max(0, Math.min(1, (page.selSdrLuminance - page.sdrLuminanceMin) / Math.max(1, page.sdrLuminanceMax - page.sdrLuminanceMin))) - 9
                        color: Theme.primary
                        border.color: Qt.lighter(Theme.primary, 1.4)
                        border.width: 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setVal(mx) {
                            var ratio = Math.max(0, Math.min(1, mx / width));
                            page.selSdrLuminance = Math.round(page.sdrLuminanceMin + ratio * (page.sdrLuminanceMax - page.sdrLuminanceMin));
                        }
                        onPressed: function(mouse) { setVal(mouse.x); }
                        onPositionChanged: function(mouse) { if (pressed) setVal(mouse.x); }
                    }
                }

                Text {
                    font.family: Theme.fontFamily
                    text: page.selSdrLuminance + " nits"
                    color: Theme.primary
                    font.pixelSize: 12
                    font.bold: true
                    Layout.preferredWidth: 72
                    horizontalAlignment: Text.AlignRight
                }
            }

            // SDR brightness
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Text {
                    font.family: Theme.fontFamily
                    text: "SDR brightness"
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                    font.bold: true
                    Layout.preferredWidth: 130
                }

                Item {
                    Layout.fillWidth: true
                    height: 32

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, (page.selSdrBrightness - 0.5) / 1.5))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
                        }
                    }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * Math.max(0, Math.min(1, (page.selSdrBrightness - 0.5) / 1.5)) - 9
                        color: Theme.primary
                        border.color: Qt.lighter(Theme.primary, 1.4)
                        border.width: 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setVal(mx) {
                            var ratio = Math.max(0, Math.min(1, mx / width));
                            page.selSdrBrightness = Math.round((0.5 + ratio * 1.5) * 10) / 10;
                        }
                        onPressed: function(mouse) { setVal(mouse.x); }
                        onPositionChanged: function(mouse) { if (pressed) setVal(mouse.x); }
                    }
                }

                Text {
                    font.family: Theme.fontFamily
                    text: page.selSdrBrightness.toFixed(1) + "x"
                    color: Theme.primary
                    font.pixelSize: 12
                    font.bold: true
                    Layout.preferredWidth: 72
                    horizontalAlignment: Text.AlignRight
                }
            }

            // SDR saturation
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Text {
                    font.family: Theme.fontFamily
                    text: "SDR saturation"
                    color: SettingsPalette.subtext
                    font.pixelSize: 12
                    font.bold: true
                    Layout.preferredWidth: 130
                }

                Item {
                    Layout.fillWidth: true
                    height: 32

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Qt.rgba(255, 255, 255, 0.08)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, (page.selSdrSaturation - 0.5) / 1.5))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
                        }
                    }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * Math.max(0, Math.min(1, (page.selSdrSaturation - 0.5) / 1.5)) - 9
                        color: Theme.primary
                        border.color: Qt.lighter(Theme.primary, 1.4)
                        border.width: 2
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setVal(mx) {
                            var ratio = Math.max(0, Math.min(1, mx / width));
                            page.selSdrSaturation = Math.round((0.5 + ratio * 1.5) * 10) / 10;
                        }
                        onPressed: function(mouse) { setVal(mouse.x); }
                        onPositionChanged: function(mouse) { if (pressed) setVal(mouse.x); }
                    }
                }

                Text {
                    font.family: Theme.fontFamily
                    text: page.selSdrSaturation.toFixed(1) + "x"
                    color: Theme.primary
                    font.pixelSize: 12
                    font.bold: true
                    Layout.preferredWidth: 72
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
