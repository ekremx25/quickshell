import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../Widgets"

Item {
    id: root
    property var settingsPopup

    // ─── flat config vars ───────────────────────────────────────
    property bool   cfg_showDock:            true
    property bool   cfg_autoHide:            false
    property bool   cfg_intelligentAutoHide: false
    property bool   cfg_showBackground:      true
    property real   cfg_dockTransparency:    0.85
    property bool   cfg_showBorder:          true
    property real   cfg_dockScale:           1.0
    property int    cfg_iconSize:            28
    property int    cfg_dockPadding:         8
    property int    cfg_itemSpacing:         2
    property int    cfg_bottomMargin:        5
    property string cfg_indicatorStyle:      "circle"
    property bool   cfg_showLauncher:        true
    property string cfg_dockPosition:        "bottom"
    property string cfg_dockAlignment:       "center"
    property var    cfg_pinned:              []
    property var    cfg_leftModules:         []
    property var    cfg_rightModules:        []

    property bool isLoaded: false

    // ─── colors (matching NotificationsPage pattern) ────────────
    property color colorText:       "#cdd6f4"
    property color colorSubtext:    "#a6adc8"
    property color colorSurface:    "#313244"
    property color colorPrimary:    "#cba6f7"
    property color colorBackground: "#1e1e2e"

    // ─── read ────────────────────────────────────────────────────
    Process {
        id: dockReadProc
        command: ["cat", settingsPopup.dockConfigPath]
        property string buf: ""
        stdout: SplitParser { onRead: (d) => dockReadProc.buf += d }
        onExited: {
            var raw = dockReadProc.buf.trim()
            dockReadProc.buf = ""
            if (raw !== "") {
                try {
                    var p = JSON.parse(raw)
                    function g(k, d) { return p[k] !== undefined ? p[k] : d }
                    root.cfg_showDock            = g("showDock", true)
                    root.cfg_autoHide            = g("autoHide", false)
                    root.cfg_intelligentAutoHide = g("intelligentAutoHide", false)
                    root.cfg_showBackground      = g("showBackground", true)
                    root.cfg_dockTransparency    = g("dockTransparency", 0.85)
                    root.cfg_showBorder          = g("showBorder", true)
                    root.cfg_dockScale           = g("dockScale", 1.0)
                    root.cfg_iconSize            = g("iconSize", 28)
                    root.cfg_dockPadding         = g("dockPadding", 8)
                    root.cfg_itemSpacing         = g("itemSpacing", 2)
                    root.cfg_bottomMargin        = g("bottomMargin", 5)
                    root.cfg_indicatorStyle      = g("indicatorStyle", "circle")
                    root.cfg_showLauncher        = g("showLauncher", true)
                    root.cfg_dockPosition        = g("dockPosition", "bottom")
                    root.cfg_dockAlignment       = g("dockAlignment", "center")
                    root.cfg_pinned              = g("pinned", [])
                    root.cfg_leftModules         = g("leftModules", [])
                    root.cfg_rightModules        = g("rightModules", [])
                } catch(e) { console.log("DockPage parse: " + e) }
            }
            root.isLoaded = true
        }
    }

    // ─── write ───────────────────────────────────────────────────
    Process {
        id: dockWriteProc
        command: []
        running: false
    }

    function save() {
        if (!root.isLoaded) return
        var obj = {
            showDock: root.cfg_showDock, autoHide: root.cfg_autoHide,
            intelligentAutoHide: root.cfg_intelligentAutoHide,
            showBackground: root.cfg_showBackground,
            dockTransparency: root.cfg_dockTransparency,
            showBorder: root.cfg_showBorder,
            dockScale: root.cfg_dockScale, iconSize: root.cfg_iconSize,
            dockPadding: root.cfg_dockPadding, itemSpacing: root.cfg_itemSpacing,
            bottomMargin: root.cfg_bottomMargin,
            indicatorStyle: root.cfg_indicatorStyle,
            showLauncher: root.cfg_showLauncher,
            dockPosition: root.cfg_dockPosition,
            dockAlignment: root.cfg_dockAlignment,
            pinned: root.cfg_pinned, leftModules: root.cfg_leftModules, rightModules: root.cfg_rightModules
        }
        var js = JSON.stringify(obj, null, 2)
        dockWriteProc.running = false
        dockWriteProc.command = ["sh", "-c", "printf '%s' '" + js.replace(/'/g,"'\\''") + "' > " + settingsPopup.dockConfigPath]
        dockWriteProc.running = true
    }

    function loadConfig() {
        root.isLoaded = false
        dockReadProc.buf = ""
        dockReadProc.running = false
        dockReadProc.running = true
    }

    Component.onCompleted: loadConfig()
    Connections {
        target: settingsPopup
        function onVisibleChanged() { if (settingsPopup.visible) loadConfig() }
    }

    // ─── UI (Flickable + ColumnLayout — same pattern as NotificationsPage) ──
    Flickable {
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight + 48
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentCol
            width: parent.width - 48
            x: 24
            y: 24
            spacing: 20

            Text { text: "Dock Settings"; font.bold: true; font.pixelSize: 24; color: colorText }
            Text { text: "Configure dock appearance and behavior."; font.pixelSize: 14; color: colorSubtext }

            Item { height: 10 }

            // ═══ POSITION ═══
            Rectangle {
                Layout.fillWidth: true; height: 90
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "Position"; font.pixelSize: 14; color: colorText }
                        Text { text: "Where the dock sits on the screen."; font.pixelSize: 11; color: colorSubtext }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 6
                        Repeater {
                            model: ListModel {
                                ListElement { name: "Top"; val: "top" }
                                ListElement { name: "Bottom"; val: "bottom" }
                                ListElement { name: "Left"; val: "left" }
                                ListElement { name: "Right"; val: "right" }
                            }
                            delegate: Rectangle {
                                width: 80; height: 30; radius: 6
                                color: root.cfg_dockPosition === model.val ? colorPrimary : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.8)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.cfg_dockPosition === model.val ? "✓ " + model.name : model.name
                                    font.pixelSize: 12; color: root.cfg_dockPosition === model.val ? colorBackground : colorText
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.cfg_dockPosition = model.val; save() }
                                }
                            }
                        }
                    }
                }
            }

            // Alignment (Left / Center / Right)
            Rectangle {
                Layout.fillWidth: true; height: 90
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "Alignment"; font.pixelSize: 14; color: colorText }
                        Text { text: "Align dock to the left, center, or right of the edge."; font.pixelSize: 11; color: colorSubtext }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 6
                        Repeater {
                            model: ListModel {
                                ListElement { name: "Left"; val: "left" }
                                ListElement { name: "Center"; val: "center" }
                                ListElement { name: "Right"; val: "right" }
                            }
                            delegate: Rectangle {
                                width: 80; height: 30; radius: 6
                                color: root.cfg_dockAlignment === model.val ? colorPrimary : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.8)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.cfg_dockAlignment === model.val ? "✓ " + model.name : model.name
                                    font.pixelSize: 12; color: root.cfg_dockAlignment === model.val ? colorBackground : colorText
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.cfg_dockAlignment = model.val; save() }
                                }
                            }
                        }
                    }
                }
            }

            // ═══ VISIBILITY ═══

            // Show Dock
            Rectangle {
                Layout.fillWidth: true; height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 16
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "Show Dock"; font.pixelSize: 14; color: colorText }
                        Text { text: "Display a dock with pinned and running applications."; font.pixelSize: 11; color: colorSubtext }
                    }
                    Switch {
                        checked: root.cfg_showDock
                        onToggled: { root.cfg_showDock = checked; save() }
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // Auto-hide
            Rectangle {
                Layout.fillWidth: true; height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 16
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "Auto-hide Dock"; font.pixelSize: 14; color: colorText }
                        Text { text: "Reveal when hovering near the dock area."; font.pixelSize: 11; color: colorSubtext }
                    }
                    Switch {
                        checked: root.cfg_autoHide
                        onToggled: { root.cfg_autoHide = checked; save() }
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // Intelligent Auto-hide
            Rectangle {
                Layout.fillWidth: true; height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 16
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "Intelligent Auto-hide"; font.pixelSize: 14; color: colorText }
                        Text { text: "Show dock when floating windows don't overlap its area."; font.pixelSize: 11; color: colorSubtext }
                    }
                    Switch {
                        checked: root.cfg_intelligentAutoHide
                        onToggled: { root.cfg_intelligentAutoHide = checked; save() }
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // ═══ SIZING ═══

            // Dock Scale
            Rectangle {
                Layout.fillWidth: true; height: 80
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: "Dock Scale"; font.pixelSize: 14; color: colorText }
                            Text { text: "Overall size multiplier (1.0 = normal, 1.5 = 4K)."; font.pixelSize: 11; color: colorSubtext }
                        }
                        Text { text: root.cfg_dockScale.toFixed(1) + "x"; font.pixelSize: 14; color: colorPrimary; font.bold: true }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 0.5; to: 2.5; stepSize: 0.1
                        value: root.cfg_dockScale
                        onValueChanged: { root.cfg_dockScale = Math.round(value * 10) / 10; save() }
                        background: Rectangle {
                            x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 200; implicitHeight: 4; width: parent.availableWidth; height: implicitHeight; radius: 2; color: colorSurface
                            Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; color: colorPrimary; radius: 2 }
                        }
                        handle: Rectangle {
                            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: parent.pressed ? Qt.darker(colorPrimary, 1.2) : colorPrimary
                        }
                    }
                }
            }

            // Icon Size
            Rectangle {
                Layout.fillWidth: true; height: 80
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: "Icon Size"; font.pixelSize: 14; color: colorText }
                            Text { text: "Size of application icons in the dock."; font.pixelSize: 11; color: colorSubtext }
                        }
                        Text { text: root.cfg_iconSize + "px"; font.pixelSize: 14; color: colorPrimary; font.bold: true }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 16; to: 64; stepSize: 2
                        value: root.cfg_iconSize
                        onValueChanged: { root.cfg_iconSize = Math.round(value); save() }
                        background: Rectangle {
                            x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 200; implicitHeight: 4; width: parent.availableWidth; height: implicitHeight; radius: 2; color: colorSurface
                            Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; color: colorPrimary; radius: 2 }
                        }
                        handle: Rectangle {
                            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: parent.pressed ? Qt.darker(colorPrimary, 1.2) : colorPrimary
                        }
                    }
                }
            }

            // ═══ APPEARANCE ═══

            // Show Background
            Rectangle {
                Layout.fillWidth: true; height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 16
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "Show Background"; font.pixelSize: 14; color: colorText }
                        Text { text: "Semi-transparent panel behind dock items."; font.pixelSize: 11; color: colorSubtext }
                    }
                    Switch {
                        checked: root.cfg_showBackground
                        onToggled: { root.cfg_showBackground = checked; save() }
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // Transparency
            Rectangle {
                Layout.fillWidth: true; height: 80
                visible: root.cfg_showBackground
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: "Background Opacity"; font.pixelSize: 14; color: colorText }
                            Text { text: "How opaque the dock background is."; font.pixelSize: 11; color: colorSubtext }
                        }
                        Text { text: Math.round(root.cfg_dockTransparency * 100) + "%"; font.pixelSize: 14; color: colorPrimary; font.bold: true }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 0.0; to: 1.0; stepSize: 0.05
                        value: root.cfg_dockTransparency
                        onValueChanged: { root.cfg_dockTransparency = Math.round(value * 20) / 20; save() }
                        background: Rectangle {
                            x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 200; implicitHeight: 4; width: parent.availableWidth; height: implicitHeight; radius: 2; color: colorSurface
                            Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; color: colorPrimary; radius: 2 }
                        }
                        handle: Rectangle {
                            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: parent.pressed ? Qt.darker(colorPrimary, 1.2) : colorPrimary
                        }
                    }
                }
            }

            // Show Border
            Rectangle {
                Layout.fillWidth: true; height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 16
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "Show Border"; font.pixelSize: 14; color: colorText }
                        Text { text: "Add a border around the dock container."; font.pixelSize: 11; color: colorSubtext }
                    }
                    Switch {
                        checked: root.cfg_showBorder
                        onToggled: { root.cfg_showBorder = checked; save() }
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }

            // ═══ SPACING ═══

            // Padding
            Rectangle {
                Layout.fillWidth: true; height: 80
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: "Padding"; font.pixelSize: 14; color: colorText }
                            Text { text: "Internal padding of the dock container."; font.pixelSize: 11; color: colorSubtext }
                        }
                        Text { text: root.cfg_dockPadding + "px"; font.pixelSize: 14; color: colorPrimary; font.bold: true }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 0; to: 40; stepSize: 1
                        value: root.cfg_dockPadding
                        onValueChanged: { root.cfg_dockPadding = Math.round(value); save() }
                        background: Rectangle {
                            x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 200; implicitHeight: 4; width: parent.availableWidth; height: implicitHeight; radius: 2; color: colorSurface
                            Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; color: colorPrimary; radius: 2 }
                        }
                        handle: Rectangle {
                            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: parent.pressed ? Qt.darker(colorPrimary, 1.2) : colorPrimary
                        }
                    }
                }
            }

            // Item Spacing
            Rectangle {
                Layout.fillWidth: true; height: 80
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: "Item Spacing"; font.pixelSize: 14; color: colorText }
                            Text { text: "Space between dock items."; font.pixelSize: 11; color: colorSubtext }
                        }
                        Text { text: root.cfg_itemSpacing + "px"; font.pixelSize: 14; color: colorPrimary; font.bold: true }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 0; to: 16; stepSize: 1
                        value: root.cfg_itemSpacing
                        onValueChanged: { root.cfg_itemSpacing = Math.round(value); save() }
                        background: Rectangle {
                            x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 200; implicitHeight: 4; width: parent.availableWidth; height: implicitHeight; radius: 2; color: colorSurface
                            Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; color: colorPrimary; radius: 2 }
                        }
                        handle: Rectangle {
                            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: parent.pressed ? Qt.darker(colorPrimary, 1.2) : colorPrimary
                        }
                    }
                }
            }

            // Bottom Margin
            Rectangle {
                Layout.fillWidth: true; height: 80
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: "Bottom Margin"; font.pixelSize: 14; color: colorText }
                            Text { text: "Distance from screen bottom edge."; font.pixelSize: 11; color: colorSubtext }
                        }
                        Text { text: root.cfg_bottomMargin + "px"; font.pixelSize: 14; color: colorPrimary; font.bold: true }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 0; to: 40; stepSize: 1
                        value: root.cfg_bottomMargin
                        onValueChanged: { root.cfg_bottomMargin = Math.round(value); save() }
                        background: Rectangle {
                            x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 200; implicitHeight: 4; width: parent.availableWidth; height: implicitHeight; radius: 2; color: colorSurface
                            Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; color: colorPrimary; radius: 2 }
                        }
                        handle: Rectangle {
                            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                            y: parent.topPadding + parent.availableHeight / 2 - height / 2
                            implicitWidth: 16; implicitHeight: 16; radius: 8
                            color: parent.pressed ? Qt.darker(colorPrimary, 1.2) : colorPrimary
                        }
                    }
                }
            }

            // ═══ BEHAVIOR ═══

            // Indicator Style
            Rectangle {
                Layout.fillWidth: true; height: 90
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "Indicator Style"; font.pixelSize: 14; color: colorText }
                        Text { text: "Running app indicator style on the dock."; font.pixelSize: 11; color: colorSubtext }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 6
                        Repeater {
                            model: ListModel {
                                ListElement { name: "Circle"; val: "circle" }
                                ListElement { name: "Line"; val: "line" }
                            }
                            delegate: Rectangle {
                                width: 80; height: 30; radius: 6
                                color: root.cfg_indicatorStyle === model.val ? colorPrimary : Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.8)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.cfg_indicatorStyle === model.val ? "✓ " + model.name : model.name
                                    font.pixelSize: 12; color: root.cfg_indicatorStyle === model.val ? colorBackground : colorText
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.cfg_indicatorStyle = model.val; save() }
                                }
                            }
                        }
                    }
                }
            }

            // Show Launcher
            Rectangle {
                Layout.fillWidth: true; height: 70
                color: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.3); radius: 10
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 16
                    ColumnLayout { Layout.fillWidth: true; spacing: 2
                        Text { text: "Show Launcher Button"; font.pixelSize: 14; color: colorText }
                        Text { text: "Display an app launcher button in the dock."; font.pixelSize: 11; color: colorSubtext }
                    }
                    Switch {
                        checked: root.cfg_showLauncher
                        onToggled: { root.cfg_showLauncher = checked; save() }
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 20; radius: 10
                            color: parent.checked ? colorPrimary : colorSurface
                            border.color: Qt.rgba(255,255,255,0.1)
                            Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; color: "#ffffff"; Behavior on x { NumberAnimation { duration: 100 } } }
                        }
                    }
                }
            }
        }
    }
}
