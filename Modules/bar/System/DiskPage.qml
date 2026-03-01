import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../../../Widgets"

ColumnLayout {
    spacing: 12
    anchors.margins: 16

    // --- Başlık ---
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "󰋊"
            font.pixelSize: 22
            font.family: "JetBrainsMono Nerd Font"
            color: Theme.primary
        }
        Text {
            text: "Disk Management"
            font.bold: true
            font.pixelSize: 20
            color: Theme.text
        }
        Item { Layout.fillWidth: true }
        // Yenile butonu
        Rectangle {
            width: 32; height: 32; radius: 16
            color: refreshMA.containsMouse ? Theme.surface : "transparent"
            Text { anchors.centerIn: parent; text: "↻"; color: Theme.text; font.pixelSize: 18 }
            MouseArea {
                id: refreshMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: refreshData()
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

    // --- Disk Listesi ---
    ListView {
        id: diskListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: ListModel { id: diskModel }

        delegate: Rectangle {
            width: diskListView.width
            height: 80
            color: Theme.surface
            radius: 12
            // Sadece görsel çerçeve, interactive değil
            border.color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                // Sol Taraf: Grafik veya İkon
                Item {
                    width: 50; height: 50
                    
                    // Bağlı diskler için: Daire Grafik
                    Item {
                        anchors.fill: parent
                        visible: model.mountpoint !== "" && model.fsused !== ""

                        // Arkaplan halkası
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.1)
                                strokeWidth: 4
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 25; centerY: 25
                                    radiusX: 23; radiusY: 23
                                    startAngle: 0
                                    sweepAngle: 360
                                }
                            }
                        }

                        // Doluluk halkası
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: {
                                    var p = parseFloat(model.usePercent.replace("%","")) || 0;
                                    if (p > 90) return Theme.red;
                                    if (p > 75) return Theme.yellow;
                                    return Theme.primary;
                                }
                                strokeWidth: 4
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 25; centerY: 25
                                    radiusX: 23; radiusY: 23
                                    startAngle: -90
                                    sweepAngle: 3.6 * (parseFloat(model.usePercent.replace("%","")) || 0)
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: model.usePercent ? model.usePercent : "?"
                            font.pixelSize: 10
                            font.bold: true
                            color: Theme.text
                        }
                    }

                    // Bağlı OLMAYAN diskler için: İkon
                    Rectangle {
                        visible: model.mountpoint === "" || model.fsused === ""
                        anchors.fill: parent
                        radius: 25
                        color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: "󰋊"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 24
                            color: Theme.subtext
                        }
                    }
                }

                // Bilgiler
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    // İsim ve Bağlama Noktası
                    RowLayout {
                        Text {
                            text: model.name
                            color: Theme.text
                            font.bold: true
                            font.pixelSize: 15
                        }
                        
                        Text {
                            visible: model.mountpoint !== ""
                            text: " (" + model.mountpoint + ")"
                            color: Theme.subtext
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Detaylar (Kullanılan / Toplam / Boş)
                    Text {
                        text: {
                            if (model.mountpoint && model.fsused) {
                                return "Used: " + model.fsused + " / " + model.size + "  •  Free: " + model.fsavail
                            } else {
                                return "Capacity: " + model.size + " (Not Mounted)"
                            }
                        }
                        color: model.mountpoint ? Theme.text : Theme.overlay2
                        font.pixelSize: 12
                        opacity: 0.8
                    }
                    
                    // FSType (küçük bilgi)
                    Text {
                        visible: model.fstype !== ""
                        text: model.fstype.toUpperCase()
                        color: Theme.overlay
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
    
    function refreshData() {
        diskListProc.output = "";
        diskListProc.running = false;
        diskListProc.running = true;
    }

    // lsblk ile tüm verileri alıyoruz (util-linux >= 2.33 gerekli FS sütunları için)
    Process {
        id: diskListProc
        property string output: ""
        // FSAVAIL, FSUSED, FSUSE% sütunları doğrudan lsblk'dan gelir
        command: ["lsblk", "-J", "-o", "NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,FSAVAIL,FSUSED,FSUSE%"]
        stdout: SplitParser { onRead: data => diskListProc.output += data }
        onExited: {
            try {
                if (diskListProc.output.trim() === "") return;
                var json = JSON.parse(diskListProc.output);
                diskModel.clear();
                
                function processDevices(devices) {
                    for (var i = 0; i < devices.length; i++) {
                        var dev = devices[i];
                        // Partisyonları veya mount edilmiş diskleri göster
                        if (dev.type === "part" || (dev.type === "disk" && !dev.children) || (dev.type === "lvm")) {
                             diskModel.append({
                                 name: dev.name,
                                 size: dev.size,
                                 type: dev.type,
                                 mountpoint: dev.mountpoint || "",
                                 fstype: dev.fstype || "",
                                 fsavail: dev.fsavail || "",
                                 fsused: dev.fsused || "",
                                 usePercent: dev["fsuse%"] || "" // lsblk json key might be "fsuse%"
                             });
                        }
                        if (dev.children) processDevices(dev.children);
                    }
                }
                
                if (json.blockdevices) processDevices(json.blockdevices);
            } catch (e) {
                console.log("JSON Error: " + e);
            }
            diskListProc.output = "";
        }
    }
    
    Component.onCompleted: refreshData()
}
