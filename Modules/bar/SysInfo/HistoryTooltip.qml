import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"

PopupWindow {
    id: root

    required property Item ownerItem
    property color accentColor: "#cba6f7"
    property color surfaceColor: "#1e1e2e"
    property color textColor: "#cdd6f4"
    property string primaryLineLeft: ""
    property string primaryLineRight: ""
    property var historyValues: []
    property int historyMax: 40
    property var detailLines: []

    mask: Region {}
    visible: false
    color: "transparent"
    implicitWidth: 320
    implicitHeight: col.implicitHeight + 20

    anchor.window: ownerItem && ownerItem.QsWindow ? ownerItem.QsWindow.window : null
    anchor.onAnchoring: {
        if (!anchor.window || !ownerItem) return;
        var isVertBar = anchor.window.height > anchor.window.width;
        if (isVertBar) {
            root.anchor.rect.x = -root.width - 5;
            root.anchor.rect.y = anchor.window.contentItem.mapFromItem(ownerItem, 0, 0).y + ownerItem.height / 2 - root.height / 2;
        } else {
            root.anchor.rect.x = anchor.window.contentItem.mapFromItem(ownerItem, 0, 0).x + ownerItem.width / 2 - root.width / 2;
            root.anchor.rect.y = anchor.window.height + 5;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        border.color: root.accentColor
        radius: 10

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {  text: root.primaryLineLeft; color: root.textColor; font.bold: true; font.family: Theme.fontFamily }
                Text {  text: "|"; color: root.accentColor; font.bold: true; visible: root.primaryLineRight.length > 0; font.family: Theme.fontFamily }
                Text {  text: root.primaryLineRight; color: root.accentColor; visible: root.primaryLineRight.length > 0; font.family: Theme.fontFamily }
                Item { Layout.fillWidth: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.accentColor; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

            Canvas {
                id: historyCanvas
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "#313244";
                    ctx.fillRect(0, 0, width, height);
                    ctx.fillStyle = root.accentColor;

                    var barW = width / Math.max(1, root.historyMax);
                    for (var i = 0; i < root.historyValues.length; i++) {
                        var val = root.historyValues[i];
                        var h = (val / 100) * height;
                        if (h < 1 && val > 0) h = 1;
                        ctx.fillRect(i * barW, height - h, barW - 1, h);
                    }

                    ctx.strokeStyle = root.accentColor;
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    ctx.lineTo(width, height);
                    ctx.stroke();
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.accentColor; opacity: 0.3; Layout.topMargin: 2; Layout.bottomMargin: 2 }

            Repeater {
                model: root.detailLines
                delegate: Text {
                    required property var modelData
                    text: modelData.text || ""
                    color: modelData.accent ? root.accentColor : root.textColor
                    font.family: Theme.monoFontFamily
                    font.pixelSize: modelData.small ? 11 : 12
                    elide: Text.ElideRight
                    visible: modelData.visible === undefined ? true : !!modelData.visible
                    Layout.fillWidth: true
                }
            }
        }
    }

    function refreshGraph() {
        historyCanvas.requestPaint();
    }
}
