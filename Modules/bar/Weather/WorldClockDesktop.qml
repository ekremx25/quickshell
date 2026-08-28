import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S

WorldClockDataScope {
    id: root

    Variants {
        model: S.ScreenManager.getFilteredScreens("worldclock")

        PanelWindow {
            id: clockWindow
            required property var modelData
            screen: modelData
            visible: root.enabled && root.cities.length > 0
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "world-clock-desktop"
            mask: Region { item: clockFrame }

            readonly property string screenKey: S.ScreenManager.roleForScreenName(modelData.name)
            readonly property point savedPosition: S.DesktopWidgetPositions.position("worldclock", screenKey, 16, 70)

            Rectangle {
                id: clockFrame
                x: Math.max(0, Math.min(clockWindow.width - width, clockWindow.savedPosition.x))
                y: Math.max(0, Math.min(clockWindow.height - height, clockWindow.savedPosition.y))
                width: Math.min(clockWindow.width, Math.min(1160, Math.max(170, root.cities.length * 142 + 28)))
                height: 144
                radius: 20
                color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.78)
                border.width: 1
                border.color: clockDrag.containsMouse
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                    : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: root.cities

                        Rectangle {
                            id: cityCard
                            required property var modelData
                            required property int index
                            width: 132
                            height: 126
                            radius: 15
                            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.42)
                            border.width: 1
                            border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)

                            function localDate() {
                                return new Date(root.clockEpoch + Number(modelData.utcOffsetSeconds || 0) * 1000);
                            }

                            function twoDigits(number) {
                                return number < 10 ? "0" + number : String(number);
                            }

                            function timeText() {
                                var date = localDate();
                                return twoDigits(date.getUTCHours()) + ":" + twoDigits(date.getUTCMinutes());
                            }

                            function dateText() {
                                var date = localDate();
                                var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                                var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                                return days[date.getUTCDay()] + " · " + date.getUTCDate() + " " + months[date.getUTCMonth()];
                            }

                            Canvas {
                                id: clockFace
                                width: 58
                                height: 58
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                antialiasing: true

                                Connections {
                                    target: root
                                    function onClockEpochChanged() { clockFace.requestPaint(); }
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    var cx = width / 2;
                                    var cy = height / 2;
                                    var radius = Math.min(width, height) / 2 - 2;
                                    var date = cityCard.localDate();
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                                    ctx.fillStyle = Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.82);
                                    ctx.fill();
                                    ctx.lineWidth = 1.5;
                                    ctx.strokeStyle = Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45);
                                    ctx.stroke();

                                    for (var tick = 0; tick < 12; tick++) {
                                        var angle = tick * Math.PI / 6 - Math.PI / 2;
                                        var inner = tick % 3 === 0 ? radius - 6 : radius - 4;
                                        ctx.beginPath();
                                        ctx.moveTo(cx + Math.cos(angle) * inner, cy + Math.sin(angle) * inner);
                                        ctx.lineTo(cx + Math.cos(angle) * (radius - 1.5), cy + Math.sin(angle) * (radius - 1.5));
                                        ctx.lineWidth = tick % 3 === 0 ? 1.8 : 1;
                                        ctx.strokeStyle = Theme.text;
                                        ctx.stroke();
                                    }

                                    function hand(angle, length, width, color) {
                                        ctx.beginPath();
                                        ctx.moveTo(cx, cy);
                                        ctx.lineTo(cx + Math.cos(angle) * length, cy + Math.sin(angle) * length);
                                        ctx.lineCap = "round";
                                        ctx.lineWidth = width;
                                        ctx.strokeStyle = color;
                                        ctx.stroke();
                                    }
                                    var minute = date.getUTCMinutes();
                                    hand(((date.getUTCHours() % 12) + minute / 60) * Math.PI / 6 - Math.PI / 2, radius * 0.48, 3.2, Theme.text);
                                    hand(minute * Math.PI / 30 - Math.PI / 2, radius * 0.70, 2, Theme.primary);
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, 2.5, 0, Math.PI * 2);
                                    ctx.fillStyle = Theme.primary;
                                    ctx.fill();
                                }
                            }

                            Text {
                                anchors.top: clockFace.bottom
                                anchors.topMargin: 3
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 12
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.city
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.top: clockFace.bottom
                                anchors.topMargin: 22
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cityCard.timeText() + "  " + modelData.icon + "  " + modelData.temperature + "°"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 7
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cityCard.dateText()
                                color: Theme.overlay2
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }
                        }
                    }
                }

                MouseArea {
                    id: clockDrag
                    anchors.fill: parent
                    z: 20
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: clockFrame
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 0
                    drag.maximumX: Math.max(0, clockWindow.width - clockFrame.width)
                    drag.minimumY: 0
                    drag.maximumY: Math.max(0, clockWindow.height - clockFrame.height)
                    onReleased: S.DesktopWidgetPositions.setPosition(
                        "worldclock", clockWindow.screenKey, clockFrame.x, clockFrame.y)
                }
            }
        }
    }
}
