import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette

ColumnLayout {
    id: diskPage
    spacing: 12
    anchors.margins: 16

    DiskService { id: diskService }
    property var settingsPopup: null
    property var selectedDisk: null
    property bool mountDialogVisible: false
    property string mountPointDraft: ""
    property bool mountPickerVisible: false

    function openMountDialog(disk) {
        selectedDisk = disk;
        mountPointDraft = disk.inFstab && disk.fstabMountpoint.length > 0
            ? disk.fstabMountpoint
            : diskService.defaultMountPoint(disk);
        mountDialogVisible = true;
    }

    // --- Title ---
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
            color: SettingsPalette.text
        }
        Item { Layout.fillWidth: true }
        // Refresh button
        Rectangle {
            width: 32; height: 32; radius: 16
            color: refreshMA.containsMouse ? SettingsPalette.surface : "transparent"
            Text { anchors.centerIn: parent; text: "↻"; color: SettingsPalette.text; font.pixelSize: 18 }
            MouseArea {
                id: refreshMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: diskService.refresh()
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: SettingsPalette.surface }

    Rectangle {
        Layout.fillWidth: true
        visible: diskService.actionStatus.length > 0
        radius: 10
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
        border.width: 1
        implicitHeight: statusText.implicitHeight + 18

        Text {
            id: statusText
            anchors.fill: parent
            anchors.margins: 9
            wrapMode: Text.Wrap
            text: diskService.actionStatus
            color: SettingsPalette.text
            font.pixelSize: 12
        }
    }

    // --- Disk List ---
    ListView {
        id: diskListView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: diskService.disks

        delegate: Rectangle {
            required property var modelData
            width: diskListView.width
            height: 112
            color: SettingsPalette.surface
            radius: 12
            // Visual frame only, not interactive
            border.color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                // Left Side: Chart or Icon
                Item {
                    width: 50; height: 50

                    // For mounted disks: Circle Chart
                    Item {
                        anchors.fill: parent
                        visible: modelData.mountpoint !== "" && modelData.fsused !== ""

                        // Background ring
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: Qt.rgba(245/255, 247/255, 255/255, 0.1)
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

                        // Fill ring
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: {
                                    var p = parseFloat(modelData.usePercent.replace("%","")) || 0;
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
                                    sweepAngle: 3.6 * (parseFloat(modelData.usePercent.replace("%","")) || 0)
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.usePercent ? modelData.usePercent : "?"
                            font.pixelSize: 10
                            font.bold: true
                            color: SettingsPalette.text
                        }
                    }

                    // For UNMOUNTED disks: Icon
                    Rectangle {
                        visible: modelData.mountpoint === "" || modelData.fsused === ""
                        anchors.fill: parent
                        radius: 25
                        color: Qt.rgba(174/255, 184/255, 203/255, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: "󰋊"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 24
                            color: SettingsPalette.subtext
                        }
                    }
                }

                // Info
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // Name and Mount Point
                    RowLayout {
                        Text {
                            text: modelData.name
                            color: SettingsPalette.text
                            font.bold: true
                            font.pixelSize: 15
                        }
                        
                        Text {
                            visible: modelData.mountpoint !== ""
                            text: " (" + modelData.mountpoint + ")"
                            color: SettingsPalette.subtext
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Details (Used / Total / Free)
                    Text {
                        text: {
                            if (modelData.mountpoint && modelData.fsused) {
                                return "Used: " + modelData.fsused + " / " + modelData.size + "  •  Free: " + modelData.fsavail
                            } else {
                                return "Capacity: " + modelData.size + " (Not Mounted)"
                            }
                        }
                        color: modelData.mountpoint ? SettingsPalette.text : SettingsPalette.overlay2
                        font.pixelSize: 12
                        opacity: 0.8
                    }
                    
                    // FSType (small info)
                    Text {
                        visible: modelData.fstype !== ""
                        text: modelData.fstype.toUpperCase()
                        color: SettingsPalette.overlay
                        font.pixelSize: 10
                    }

                    Text {
                        visible: modelData.uuid !== ""
                        text: "UUID: " + modelData.uuid
                        color: SettingsPalette.overlay2
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

                    Rectangle {
                        visible: modelData.inFstab
                        radius: 8
                        color: Qt.rgba(0.56, 0.89, 0.63, 0.16)
                        border.color: Qt.rgba(0.56, 0.89, 0.63, 0.32)
                        border.width: 1
                        implicitWidth: badgeText.implicitWidth + 14
                        implicitHeight: badgeText.implicitHeight + 8

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: "fstab"
                            color: "#a6e3a1"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Rectangle {
                        visible: diskService.canPersist(modelData)
                        width: 132
                        height: 34
                        radius: 10
                        color: persistMouse.containsMouse ? Qt.lighter(Theme.primary, 1.08) : Theme.primary
                        opacity: diskService.busyDeviceName === modelData.name ? 0.75 : 1

                        Text {
                            anchors.centerIn: parent
                            text: diskService.busyDeviceName === modelData.name
                                ? "Working..."
                                : diskService.mountLabel(modelData)
                            color: "#1e1e2e"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: persistMouse
                            anchors.fill: parent
                            enabled: diskService.busyDeviceName === "" || diskService.busyDeviceName === modelData.name
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.inFstab && modelData.mountpoint === "") {
                                    if (diskPage.settingsPopup) diskPage.settingsPopup.closeSettings()
                                    diskService.mountExisting(modelData)
                                } else {
                                    diskPage.openMountDialog(modelData)
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: modelData.mountpoint !== "" && !modelData.isSystemMount
                        width: 132
                        height: 32
                        radius: 10
                        color: unmountMouse.containsMouse ? Qt.rgba(0.95, 0.45, 0.45, 0.95) : Qt.rgba(0.95, 0.45, 0.45, 0.82)
                        opacity: diskService.busyDeviceName === modelData.name ? 0.75 : 1

                        Text {
                            anchors.centerIn: parent
                            text: diskService.busyDeviceName === modelData.name
                                ? "Working..."
                                : (modelData.inFstab ? "Unmount & Remove" : "Unmount")
                            color: "#1e1e2e"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            id: unmountMouse
                            anchors.fill: parent
                            enabled: diskService.busyDeviceName === "" || diskService.busyDeviceName === modelData.name
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (diskPage.settingsPopup) diskPage.settingsPopup.closeSettings()
                                diskService.unmountDisk(modelData)
                            }
                        }
                    }

                    Text {
                        visible: modelData.inFstab && modelData.fstabMountpoint !== ""
                        text: modelData.fstabMountpoint
                        color: SettingsPalette.subtext
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    Rectangle {
        parent: diskPage.parent ? diskPage.parent : diskPage
        anchors.fill: parent
        visible: mountDialogVisible
        z: 200
        color: Qt.rgba(0, 0, 0, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: mountDialogVisible = false
        }

        Rectangle {
            width: 520
            radius: 14
            color: SettingsPalette.background
            border.color: SettingsPalette.surface
            border.width: 1
            anchors.centerIn: parent
            implicitHeight: dialogColumn.implicitHeight + 28

            MouseArea {
                anchors.fill: parent
                onClicked: mouse.accepted = true
            }

            ColumnLayout {
                id: dialogColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Bind Disk to fstab"; color: SettingsPalette.text; font.pixelSize: 17; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "✕"
                        color: SettingsPalette.subtext
                        font.pixelSize: 15
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mountDialogVisible = false }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: SettingsPalette.surface }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: selectedDisk
                        ? (selectedDisk.name + " • " + selectedDisk.fstype.toUpperCase() + " • UUID " + selectedDisk.uuid)
                        : ""
                    color: SettingsPalette.subtext
                    font.pixelSize: 11
                }

                Text {
                    text: "Mount Point"
                    color: SettingsPalette.text
                    font.pixelSize: 12
                    font.bold: true
                }

                TextField {
                    id: mountPointField
                    Layout.fillWidth: true
                    text: mountPointDraft
                    placeholderText: "/mnt/disk"
                    onTextChanged: mountPointDraft = text
                }

                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        width: 132
                        height: 34
                        radius: 8
                        color: Qt.rgba(255,255,255,0.08)
                        Text { anchors.centerIn: parent; text: "Browse folders"; color: SettingsPalette.text; font.pixelSize: 12; font.bold: true }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mountPickerVisible = true
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: SettingsPalette.overlay2
                    font.pixelSize: 11
                    text: selectedDisk
                        ? ("Filesystem: " + diskService.mountFsTypeFor(selectedDisk) +
                           " • Options: " + diskService.mountOptionsFor(selectedDisk) +
                           " • UID:GID " + diskService.userId + ":" + diskService.groupId)
                        : ""
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 110
                        height: 36
                        radius: 10
                        color: SettingsPalette.surface
                        Text { anchors.centerIn: parent; text: "Cancel"; color: SettingsPalette.text; font.pixelSize: 12; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mountDialogVisible = false }
                    }

                    Rectangle {
                        width: 150
                        height: 36
                        radius: 10
                        color: Qt.lighter(Theme.primary, 1.04)
                        Text { anchors.centerIn: parent; text: "Bind & Mount"; color: "#1e1e2e"; font.pixelSize: 12; font.bold: true }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!selectedDisk) return
                                if (diskPage.settingsPopup) diskPage.settingsPopup.closeSettings()
                                diskService.bindToFstab(selectedDisk, mountPointDraft)
                                mountDialogVisible = false
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        parent: diskPage.parent ? diskPage.parent : diskPage
        anchors.fill: parent
        visible: mountPickerVisible
        z: 250
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: mountPickerVisible = false
        }

        FilePicker {
            width: 620
            height: 520
            anchors.centerIn: parent
            title: "Select Mount Directory"
            directoryMode: true
            allowCreateFolder: true
            currentPath: mountPointDraft.length > 0 ? mountPointDraft : "/mnt"
            onDirectorySelected: function(path) {
                mountPointDraft = path
                mountPointField.text = path
                mountPickerVisible = false
            }
            onCanceled: mountPickerVisible = false
        }
    }
}
