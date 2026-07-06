import QtQuick
import QtQuick.Layouts
import "../../../Widgets"

// 10-band EQ controls: wave canvas, band sliders, preset chips, status bar.
// All state flows through `eq` (Equalizer root) and `backend` (EqualizerBackend).
Rectangle {
    id: card
    required property var eq
    required property var backend

    radius: 18
    color: eq.glassCard
    border.width: 1
    border.color: eq.glassStroke
    implicitHeight: eqControlsLayout.implicitHeight + 28

    component MetaChip: Rectangle {
        required property string label
        property color fillColor: Qt.rgba(255,255,255,0.05)
        property color strokeColor: Qt.rgba(255,255,255,0.08)
        property color textColor: card.eq.softText
        radius: 9; color: fillColor; border.width: 1; border.color: strokeColor
        implicitWidth: metaChipText.implicitWidth + 16; implicitHeight: 26
        Text {  id: metaChipText; anchors.centerIn: parent; text: parent.label; color: parent.textColor; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
    }

    component PresetChip: Rectangle {
        required property string presetName
        Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 10
        color: card.eq.selectedPreset === presetName ? Qt.rgba(card.eq.eqAccent.r, card.eq.eqAccent.g, card.eq.eqAccent.b, 0.22) : Qt.rgba(255,255,255,0.035)
        border.width: 1
        border.color: card.eq.selectedPreset === presetName ? Qt.rgba(card.eq.eqAccent.r, card.eq.eqAccent.g, card.eq.eqAccent.b, 0.46) : Qt.rgba(255,255,255,0.06)
        Rectangle {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 10
            width: 5; height: parent.height - 14; radius: 2.5
            visible: card.eq.selectedPreset === parent.presetName; color: card.eq.eqAccent
        }
        Text {  anchors.centerIn: parent; text: parent.presetName; color: card.eq.selectedPreset === parent.presetName ? card.eq.softText : card.eq.dimText; font.pixelSize: 10; font.bold: card.eq.selectedPreset === parent.presetName; font.family: Theme.fontFamily }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.eq.applyPreset(parent.presetName) }
    }

    ColumnLayout {
        id: eqControlsLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {  text: "Equalizer"; color: eq.softText; font.bold: true; font.pixelSize: 15; font.family: Theme.fontFamily }
            Text {  text: "10-band"; color: eq.dimText; font.pixelSize: 11; font.family: Theme.fontFamily }
            Item { Layout.fillWidth: true }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 132
            clip: false

            EqCanvas {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 8
                anchors.topMargin: 8; anchors.bottomMargin: 28
                z: 0
                eqBands: eq.eqBands; wavePhase: eq.wavePhase
                eqAccent: eq.eqAccent; waveGlowColor: eq.waveGlowColor; waveLineColor: eq.waveLineColor
            }

            RowLayout {
                anchors.fill: parent; spacing: 6; z: 1

                Repeater {
                    model: eq.eqFrequencies
                    delegate: ColumnLayout {
                        Layout.fillWidth: true; spacing: 5
                        Item {
                            Layout.alignment: Qt.AlignHCenter; width: 24; height: 100
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 4; height: parent.height; radius: 2; color: eq.trackColor }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter; width: 16; height: 36; radius: 8
                                color: Qt.rgba(eq.eqAccent.r, eq.eqAccent.g, eq.eqAccent.b, 0.92)
                                y: { var db = eq.eqBands[index]; return (1 - (db + 12) / 24.0) * (parent.height - height); }
                                border.width: 1; border.color: Qt.rgba(255,255,255,0.35)
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter; width: 20; height: 20; radius: 10
                                y: { var db2 = eq.eqBands[index]; return (1 - (db2 + 12) / 24.0) * (parent.height - height); }
                                color: "#dff8ff"; border.width: 1; border.color: Qt.rgba(255,255,255,0.35)
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onPressed: (mouse) => { backend.beginBandDrag(); eq.setBandFromY(index, mouse.y, height); }
                                onPositionChanged: (mouse) => { if (pressed) eq.setBandFromY(index, mouse.y, height); }
                                onReleased: backend.commitBandDrag(); onCanceled: backend.commitBandDrag()
                            }
                        }
                        Text {  Layout.alignment: Qt.AlignHCenter; text: modelData; color: eq.dimText; font.pixelSize: 10; font.bold: true; font.family: Theme.fontFamily }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; spacing: 6
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 46; radius: 12
                color: Qt.rgba(255,255,255,0.035); border.width: 1; border.color: Qt.rgba(255,255,255,0.06)
                RowLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 10
                    ColumnLayout {
                        spacing: 1
                        Text {  text: "Sound Profiles"; color: eq.softText; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                        Text {  text: "Curated starting points for quick tuning."; color: eq.dimText; font.pixelSize: 9; font.family: Theme.fontFamily }
                    }
                    Item { Layout.fillWidth: true }
                    MetaChip { label: eq.eqModeLabel; fillColor: Qt.rgba(255,255,255,0.045); strokeColor: Qt.rgba(255,255,255,0.08); textColor: eq.softText }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Repeater { model: Math.min(5, eq.presetNames.length); delegate: PresetChip { required property int index; presetName: eq.presetNames[index] } }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Repeater { model: Math.max(0, eq.presetNames.length - 5); delegate: PresetChip { required property int index; presetName: eq.presetNames[index + 5] } }
            }
        }

        Rectangle {
            Layout.fillWidth: true; implicitHeight: 38; radius: 12
            color: Qt.rgba(255,255,255,0.03); border.width: 1; border.color: Qt.rgba(255,255,255,0.06)
            RowLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 10
                MetaChip { label: eq.eqModeLabel; fillColor: Qt.rgba(eq.eqAccent.r, eq.eqAccent.g, eq.eqAccent.b, 0.14); strokeColor: Qt.rgba(eq.eqAccent.r, eq.eqAccent.g, eq.eqAccent.b, 0.26); textColor: eq.softText }
                MetaChip {
                    label: eq.eqStateLabel
                    fillColor: backend.isBusy ? Qt.rgba(250/255, 204/255, 21/255, 0.16) : (eq.eqIsBypassed ? Qt.rgba(243/255, 139/255, 168/255, 0.12) : Qt.rgba(255,255,255,0.045))
                    strokeColor: backend.isBusy ? Qt.rgba(250/255, 204/255, 21/255, 0.26) : (eq.eqIsBypassed ? Qt.rgba(243/255, 139/255, 168/255, 0.24) : Qt.rgba(255,255,255,0.08))
                    textColor: eq.softText
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: disableEqText.implicitWidth + 28; implicitHeight: 28; radius: 9
                    color: Qt.rgba(243/255,139/255,168/255,0.12); border.width: 1; border.color: Qt.rgba(243/255,139/255,168/255,0.26)
                    Text {  id: disableEqText; anchors.centerIn: parent; text: eq.eqIsBypassed ? "EQ Bypassed" : "Bypass EQ"; color: "#f7b4c5"; font.bold: true; font.pixelSize: 11; font.family: Theme.fontFamily }
                    MouseArea { anchors.fill: parent; enabled: !backend.isBusy && !eq.eqIsBypassed; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: eq.disablePipeWireEq() }
                }
            }
        }
    }
}
