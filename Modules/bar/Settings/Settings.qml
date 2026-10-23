import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "."
import "../../../Widgets"
import "../System" as Sys

PanelWindow {
    PopupEntrance {}  // liquid ring open animation
    id: settingsWindow
    SettingsBackend {
        id: settingsBackend
        leftModel: leftModulesModel
        centerModel: centerModulesModel
        rightModel: rightModulesModel
        inactiveModel: inactiveModulesModel
        dockLeftModel: dockLeftModulesModel
        dockRightModel: dockRightModulesModel
    }
    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    signal configSaved(var newConfig)


    function closeSettings() {
        settingsWindow.visible = false;
    }
    property alias barConfig: settingsBackend.barConfig
    property alias dockConfig: settingsBackend.dockConfig
    property alias configPath: settingsBackend.configPath
    property alias dockConfigPath: settingsBackend.dockConfigPath
    property alias dockLeftModulesList: settingsBackend.dockLeftModulesList
    property alias dockRightModulesList: settingsBackend.dockRightModulesList
    readonly property color sidebarTitleColor: SettingsPalette.text
    readonly property color sidebarMutedColor: SettingsPalette.subtext
    readonly property color contentBackgroundColor: SettingsPalette.surface
    readonly property color contentPanelColor: SettingsPalette.background
    readonly property color accentColor: SettingsPalette.readableAccent(Theme.primary)
    readonly property color dangerColor: SettingsPalette.readableAccent(Theme.red)

    // Active page
    property string currentPage: "bar"

    // Module info
    readonly property alias moduleInfo: settingsBackend.moduleInfo

    // Sidebar menu categories
    readonly property var menuCategories: [
        {
            title: "SYSTEM",
            items: [
                { key: "sysinfo",    icon: "󰻀", label: "System Info" },
                { key: "disks",      icon: "󰋊", label: "Disks" },
                { key: "about",      icon: "", label: "About" }
            ]
        },
        {
            title: "APPEARANCE",
            items: [
                { key: "bar",        icon: "󰒍", label: "Bar Settings" },
                { key: "dock",       icon: "⚓", label: "Dock Settings" },
                { key: "effects",    icon: "󰁨", label: "Effects" },
                { key: "layout",     icon: "󰕰", label: "Layout Presets" },
                { key: "hyprland",   icon: "󰖲", label: "Hyprland" },
                { key: "fonts",      icon: "󰛖", label: "Fonts" },
                { key: "materialyou",icon: "󰏘", label: "Material You" },
                { key: "nightlight", icon: "󰽥", label: "Night Light" }
            ]
        },
        {
            title: "FEATURES",
            items: [
                { key: "workspaces", icon: "󰖲", label: "Workspaces" },
                { key: "notifications", icon: "󰂚", label: "Notifications" },
                { key: "weather",    icon: "󰖕", label: "Weather" },
                { key: "worldclocks",icon: "󱑂", label: "World Clocks" },
                { key: "markets",    icon: "󰄪", label: "Markets" },
                { key: "apikeys",    icon: "󰌆", label: "API Keys" }
            ]
        },
        {
            title: "HARDWARE",
            items: [
                { key: "monitors",   icon: "󰍹", label: "Monitors" },
                { key: "lockscreen", icon: "󰌾", label: "Lock Screen" },
                { key: "mouse",      icon: "🖱", label: "Mouse" },
                { key: "screens",    icon: "󰹑", label: "Screen Prefs" },
                { key: "sound",      icon: "󰕾", label: "Sound" },
                { key: "network",    icon: "󰤨", label: "Network" },
            ]
        }
    ]

    function loadConfig() { settingsBackend.loadConfig(); }
    function saveConfig() {
        settingsBackend.saveConfig(function(cfg) {
            settingsWindow.configSaved(cfg);
        });
    }

    function shouldApplyUiFont(item) {
        if (!item || item.text === undefined || item.font === undefined) return false;

        var text = String(item.text || "");
        var family = String(item.font.family || "");

        if (!text.length) return false;
        if (family === Theme.iconFontFamily || family.indexOf("Nerd") !== -1) return false;
        if (text.length <= 2 && !/[A-Za-z0-9]/.test(text)) return false;
        return true;
    }

    function applyUiFont(item) {
        if (!item) return;

        if (shouldApplyUiFont(item)) {
            item.font.family = Theme.fontFamily;
        }

        var kids = item.children || [];
        for (var i = 0; i < kids.length; ++i) {
            applyUiFont(kids[i]);
        }
    }

    function scheduleApplyUiFont() {
        if (!settingsWindow.visible || settingsWindow.currentPage === "fonts") return;
        Qt.callLater(function() {
            applyUiFont(settingsContent);
        });
    }

    onCurrentPageChanged: scheduleApplyUiFont()

    Connections {
        target: Theme
        function onFontFamilyChanged() {
            settingsWindow.scheduleApplyUiFont();
        }
    }



    ListModel { id: leftModulesModel }
    ListModel { id: centerModulesModel }
    ListModel { id: rightModulesModel }
    ListModel { id: inactiveModulesModel }
    ListModel { id: dockLeftModulesModel }
    ListModel { id: dockRightModulesModel }

    onVisibleChanged: {
        if (visible) {
            loadConfig();
            Theme.reloadSystemFonts();
            scheduleApplyUiFont();
        }
    }

    Component.onCompleted: {
        loadConfig();
        scheduleApplyUiFont();
    }

    // ── Background dim ──
    Rectangle {
        id: bgDim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }
    }

    // ── Floating Settings Window ──
    Rectangle {
        id: settingsContent
        width: 1000
        height: 700
        
        // Start at the center of the screen
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        color: SettingsPalette.background
        border.color: SettingsPalette.surface
        border.width: 1
        radius: Theme.radius
        clip: true

        property real minW: 700
        property real minH: 450
        property bool resizing: false

        // Disable layout animations during resize
        Behavior on width { enabled: !settingsContent.resizing; NumberAnimation { duration: 0 } }
        Behavior on height { enabled: !settingsContent.resizing; NumberAnimation { duration: 0 } }

        // Prevent click-through to background (do NOT block press/move — sliders need them)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
        }
    
        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0
            z: 200

            // ═══ SIDEBAR ═══
            Rectangle {
                Layout.preferredWidth: 190
                Layout.fillHeight: true
                color: SettingsPalette.surface
                radius: Theme.radius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    // Title (drag handle) — draggable
                    Item {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 12
                        height: 30

                        // Drag handler - drag the window from the title area
                        MouseArea {
                            id: titleDragArea
                            anchors.fill: parent
                            cursorShape: Qt.OpenHandCursor
                            property real startX: 0
                            property real startY: 0
                            property real startWinX: 0
                            property real startWinY: 0
                            onPressed: (mouse) => {
                                cursorShape = Qt.ClosedHandCursor
                                var global = titleDragArea.mapToGlobal(mouse.x, mouse.y)
                                startX = global.x
                                startY = global.y
                                startWinX = settingsContent.x
                                startWinY = settingsContent.y
                            }
                            onPositionChanged: (mouse) => {
                                var global = titleDragArea.mapToGlobal(mouse.x, mouse.y)
                                settingsContent.x = startWinX + (global.x - startX)
                                settingsContent.y = startWinY + (global.y - startY)
                            }
                            onReleased: {
                                cursorShape = Qt.OpenHandCursor
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                font.family: Theme.fontFamily
                                text: "⚙"
                                font.pixelSize: 18
                                color: settingsWindow.accentColor
                            }
                            Text {
                                font.family: Theme.fontFamily
                                text: "Settings"
                                color: sidebarTitleColor
                                font.pixelSize: 16
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 24; height: 24; radius: 12
                                color: closeMA.containsMouse ? settingsWindow.dangerColor : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: closeMA.containsMouse
                                        ? SettingsPalette.foregroundFor(settingsWindow.dangerColor)
                                        : sidebarTitleColor
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                }
                                MouseArea {
                                    id: closeMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWindow.closeSettings()
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.withAlpha(Theme.text, 0.06) }
                    Item { height: 6 }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: sidebarContent.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: sidebarContent
                            width: parent.width
                            spacing: 12

                            // Menu categories
                            Repeater {
                                model: settingsWindow.menuCategories

                                ColumnLayout {
                                    id: categoryColumn
                                    Layout.fillWidth: true
                                    spacing: 4
                                    property bool isExpanded: true

                                    // Category Title (Clickable)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        color: headerMA.containsMouse ? Theme.withAlpha(Theme.text, 0.05) : "transparent"
                                        radius: 6

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Text {
                                                text: categoryColumn.isExpanded ? "󰅔" : "󰅂" // Keyboard arrow down/right
                                                color: headerMA.containsMouse ? sidebarTitleColor : sidebarMutedColor
                                                font.pixelSize: 14
                                                font.family: "JetBrainsMono Nerd Font"
                                            }

                                            Text {
                                                font.family: Theme.fontFamily
                                                text: modelData.title
                                                color: headerMA.containsMouse ? sidebarTitleColor : sidebarMutedColor
                                                font.pixelSize: 11
                                                font.bold: true
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: headerMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: categoryColumn.isExpanded = !categoryColumn.isExpanded
                                        }
                                    }

                                    // Category items
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        visible: categoryColumn.isExpanded

                                        Repeater {
                                            model: modelData.items

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 38
                                                radius: 10
                                                color: {
                                                    if (settingsWindow.currentPage === modelData.key) return Qt.rgba(settingsWindow.accentColor.r, settingsWindow.accentColor.g, settingsWindow.accentColor.b, 0.14);
                                                    if (menuMA.containsMouse) return Theme.withAlpha(Theme.text, 0.05);
                                                    return "transparent";
                                                }
                                                Behavior on color { ColorAnimation { duration: settingsContent.resizing ? 0 : 120 } }

                                                // Left accent line
                                                Rectangle {
                                                    visible: settingsWindow.currentPage === modelData.key
                                                    width: 3; height: 18; radius: 2
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: settingsWindow.accentColor
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 16
                                                    anchors.rightMargin: 12
                                                    spacing: 12

                                                    Text {
                                                        text: modelData.icon
                                                        font.pixelSize: 15
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        color: settingsWindow.currentPage === modelData.key ? settingsWindow.accentColor : sidebarMutedColor
                                                    }

                                                    Text {
                                                        font.family: Theme.fontFamily
                                                        text: modelData.label
                                                        color: settingsWindow.currentPage === modelData.key ? sidebarTitleColor : sidebarMutedColor
                                                        font.pixelSize: 13
                                                        font.bold: settingsWindow.currentPage === modelData.key
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                MouseArea {
                                                    id: menuMA
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.currentPage = modelData.key
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Item { height: 16 } // Bottom spacing
                        }
                    }
                }
            }

            // Separator
            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.withAlpha(Theme.text, 0.06) }

            // ═══ CONTENT ═══
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                color: contentBackgroundColor

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 12
                    radius: Math.max(Theme.radius - 2, 10)
                    color: contentPanelColor
                    border.color: Theme.withAlpha(Theme.text, 0.06)
                    border.width: 1
                    clip: true

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "bar"
                        sourceComponent: Component {
                            BarSettingsPage {
                                anchors.fill: parent
                                anchors.margins: 16
                                visible: settingsWindow.currentPage === "bar"
                                backend: settingsBackend
                                barConfig: settingsWindow.barConfig
                                leftModel: leftModulesModel
                                centerModel: centerModulesModel
                                rightModel: rightModulesModel
                                inactiveModel: inactiveModulesModel
                                dockLeftModel: dockLeftModulesModel
                                dockRightModel: dockRightModulesModel
                                dragLayer: settingsContent
                                onBarConfigEdited: settingsWindow.barConfig = cfg
                                onSaveRequested: {
                                    saveConfig();
                                    settingsWindow.closeSettings();
                                }
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    // ── WORKSPACES PAGE ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "workspaces"
                        sourceComponent: Component {
                            WorkspacesPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "workspaces"
                                settingsPopup: settingsWindow
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    // ── NOTIFICATIONS PAGE ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "notifications"
                        sourceComponent: Component {
                            NotificationsPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "notifications"
                                settingsPopup: settingsWindow
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    // ── API KEYS (SmartComplete AI reranker) ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "apikeys"
                        sourceComponent: Component {
                            ApiKeysPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "apikeys"
                                z: visible ? 100 : 0
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    // ── DOCK PAGE ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "dock"
                        sourceComponent: Component {
                            DockPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "dock"
                                settingsPopup: settingsWindow
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    // ── EFFECTS PAGE ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "effects"
                        sourceComponent: Component {
                            EffectsPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "effects"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "fonts"
                        visible: status === Loader.Ready
                        sourceComponent: Component {
                            FontsPage {
                                anchors.fill: parent
                            }
                        }
                    }

                    // ── SYSTEM PAGES ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "sysinfo"
                        sourceComponent: Component {
                            Sys.SystemInfoPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "sysinfo"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "lockscreen"
                        sourceComponent: Component {
                            Sys.LockPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "lockscreen"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "nightlight"
                        sourceComponent: Component {
                            Sys.NightLightPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "nightlight"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "disks"
                        sourceComponent: Component {
                            Sys.DiskPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "disks"
                                settingsPopup: settingsWindow
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "weather"
                        sourceComponent: Component {
                            Sys.WeatherPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "weather"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "worldclocks"
                        sourceComponent: Component {
                            Sys.WorldClocksPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "worldclocks"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "markets"
                        sourceComponent: Component {
                            Sys.MarketsPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "markets"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "monitors"
                        sourceComponent: Component {
                            Sys.MonitorsPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "monitors"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "mouse"
                        sourceComponent: Component {
                            Sys.MousePage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "mouse"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "hyprland"
                        sourceComponent: Component {
                            Sys.HyprlandPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "hyprland"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "sound"
                        sourceComponent: Component {
                            Sys.SoundPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "sound"
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "network"
                        sourceComponent: Component {
                            Sys.NetworkPage {
                                id: networkPage
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "network"
                                z: visible ? 100 : 0
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    // ── LAYOUT PRESETS ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "layout"
                        sourceComponent: Component {
                            LayoutPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "layout"
                                z: visible ? 100 : 0
                                onPresetApplied: {
                                    loadConfig();
                                }
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }



                    // ── SCREEN PREFERENCES ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "screens"
                        sourceComponent: Component {
                            ScreensPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "screens"
                                z: visible ? 100 : 0
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }



                    // ── MATERIAL YOU ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "materialyou"
                        sourceComponent: Component {
                            MaterialYouPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "materialyou"
                                z: visible ? 100 : 0
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                    // ── ABOUT ──
                    Loader {
                        anchors.fill: parent
                        active: settingsWindow.visible && settingsWindow.currentPage === "about"
                        sourceComponent: Component {
                            AboutPage {
                                anchors.fill: parent
                                visible: settingsWindow.currentPage === "about"
                                z: visible ? 100 : 0
                            }
                        }
                        onLoaded: settingsWindow.scheduleApplyUiFont()
                    }

                }
            }
        }

        // ═══ RESIZE HANDLES ═══
        // Shared properties for resize handles
        property point startMousePos
        property size startSize
        property point startPos

        function startResize(mouseArea, mouse) {
            resizing = true
            var global = mouseArea.mapToGlobal(mouse.x, mouse.y)
            startMousePos = Qt.point(global.x, global.y)
            startSize = Qt.size(settingsContent.width, settingsContent.height)
            startPos = Qt.point(settingsContent.x, settingsContent.y)
        }

        function endResize() {
            resizing = false
        }
        
        function updateResize(mouseArea, mouse, isLeft, isTop, isHorizontal, isVertical) {
            var global = mouseArea.mapToGlobal(mouse.x, mouse.y)
            var dx = isHorizontal ? (global.x - startMousePos.x) : 0
            var dy = isVertical ? (global.y - startMousePos.y) : 0

            var newW = settingsContent.width
            var newH = settingsContent.height
            var newX = settingsContent.x
            var newY = settingsContent.y

            if (dx !== 0) {
                if (isLeft) {
                    newW = Math.max(minW, startSize.width - dx)
                    if (newW !== startSize.width - dx) dx = startSize.width - newW
                    newX = startPos.x + dx
                } else {
                    newW = Math.max(minW, startSize.width + dx)
                }
            }

            if (dy !== 0) {
                if (isTop) {
                    newH = Math.max(minH, startSize.height - dy)
                    if (newH !== startSize.height - dy) dy = startSize.height - newH
                    newY = startPos.y + dy
                } else {
                    newH = Math.max(minH, startSize.height + dy)
                }
            }
            
            // Batch all geometry updates together
            settingsContent.x = newX
            settingsContent.y = newY
            settingsContent.width = newW
            settingsContent.height = newH
        }

        // Right
        MouseArea {
            width: 10; height: parent.height
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            cursorShape: Qt.SizeHorCursor
            onPressed: (mouse) => settingsContent.startResize(this, mouse)
            onPositionChanged: (mouse) => settingsContent.updateResize(this, mouse, false, false, true, false)
            onReleased: settingsContent.endResize()
        }
        
        // Left
        MouseArea {
            width: 10; height: parent.height
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            cursorShape: Qt.SizeHorCursor
            onPressed: (mouse) => settingsContent.startResize(this, mouse)
            onPositionChanged: (mouse) => settingsContent.updateResize(this, mouse, true, false, true, false)
            onReleased: settingsContent.endResize()
        }
        
        // Bottom
        MouseArea {
            height: 10; width: parent.width
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            cursorShape: Qt.SizeVerCursor
            onPressed: (mouse) => settingsContent.startResize(this, mouse)
            onPositionChanged: (mouse) => settingsContent.updateResize(this, mouse, false, false, false, true)
            onReleased: settingsContent.endResize()
        }
        
        // Top
        MouseArea {
            height: 10; width: parent.width
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            cursorShape: Qt.SizeVerCursor
            onPressed: (mouse) => settingsContent.startResize(this, mouse)
            onPositionChanged: (mouse) => settingsContent.updateResize(this, mouse, false, true, false, true)
            onReleased: settingsContent.endResize()
        }

        // Bottom-Right
        MouseArea {
            width: 30; height: 30
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            cursorShape: Qt.SizeFDiagCursor
            z: 100
            onPressed: (mouse) => settingsContent.startResize(this, mouse)
            onPositionChanged: (mouse) => settingsContent.updateResize(this, mouse, false, false, true, true)
            onReleased: settingsContent.endResize()
        }
        
        // Bottom-Left
        MouseArea {
            width: 30; height: 30
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            cursorShape: Qt.SizeBDiagCursor
            z: 100
            onPressed: (mouse) => settingsContent.startResize(this, mouse)
            onPositionChanged: (mouse) => settingsContent.updateResize(this, mouse, true, false, true, true)
            onReleased: settingsContent.endResize()
        }
        
        // Top-Right
        MouseArea {
            width: 30; height: 30
            anchors.top: parent.top
            anchors.right: parent.right
            cursorShape: Qt.SizeBDiagCursor
            z: 100
            onPressed: (mouse) => settingsContent.startResize(this, mouse)
            onPositionChanged: (mouse) => settingsContent.updateResize(this, mouse, false, true, true, true)
            onReleased: settingsContent.endResize()
        }
        
        // Top-Left
        MouseArea {
            width: 30; height: 30
            anchors.top: parent.top
            anchors.left: parent.left
            cursorShape: Qt.SizeFDiagCursor
            z: 100
            onPressed: (mouse) => settingsContent.startResize(this, mouse)
            onPositionChanged: (mouse) => settingsContent.updateResize(this, mouse, true, true, true, true)
            onReleased: settingsContent.endResize()
        }
    }

}
