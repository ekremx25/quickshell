import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import "."
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S
import "../Weather"
import "../Volume"
import "../Tray"
import "../Workspaces"
import "../power"
import "../Notepad"
import "../Launcher"
import "../Settings"
import "../Clipboard"

Variants {
    id: dockRoot
    model: S.ScreenManager.getFilteredScreens("dock")

    PanelWindow {
        id: dockWindow
        required property var modelData
        screen: modelData

        visible: !(dockWindow.dockConfigData && dockWindow.dockConfigData.showDock === false)

        // Position config
        property string cfgPosition: (dockWindow.dockConfigData && dockWindow.dockConfigData.dockPosition) ? dockWindow.dockConfigData.dockPosition : "bottom"
        property bool isHorizontal: cfgPosition === "bottom" || cfgPosition === "top"

        anchors {
            bottom: cfgPosition === "bottom"
            top:    cfgPosition === "top"
            left:   cfgPosition === "left"
            right:  cfgPosition === "right"
        }

        // Convenience computed properties from config
        property real cfgBottomMargin: (dockWindow.dockConfigData && dockWindow.dockConfigData.bottomMargin !== undefined) ? dockWindow.dockConfigData.bottomMargin : 5
        property real cfgIconSize:     (dockWindow.dockConfigData && dockWindow.dockConfigData.iconSize     !== undefined) ? dockWindow.dockConfigData.iconSize     : 28
        property real cfgItemSpacing:  (dockWindow.dockConfigData && dockWindow.dockConfigData.itemSpacing  !== undefined) ? dockWindow.dockConfigData.itemSpacing  : 2
        property real cfgPadding:      (dockWindow.dockConfigData && dockWindow.dockConfigData.dockPadding  !== undefined) ? dockWindow.dockConfigData.dockPadding  : 8
        property real cfgTransparency: (dockWindow.dockConfigData && dockWindow.dockConfigData.dockTransparency !== undefined) ? dockWindow.dockConfigData.dockTransparency : 0.85
        property bool cfgShowBorder:   (dockWindow.dockConfigData && dockWindow.dockConfigData.showBorder !== false)
        property bool cfgIntelligentHide: (dockWindow.dockConfigData && dockWindow.dockConfigData.intelligentAutoHide === true)
        property string cfgIndicator:  (dockWindow.dockConfigData && dockWindow.dockConfigData.indicatorStyle) ? dockWindow.dockConfigData.indicatorStyle : "circle"
        property string cfgAlignment:  (dockWindow.dockConfigData && dockWindow.dockConfigData.dockAlignment) ? dockWindow.dockConfigData.dockAlignment : "center"

        // Hide the dock when auto-hidden
        property bool shouldHide: {
            if (!dockWindow.dockConfigData) return false;
            if (dockWindow.dockConfigData.autoHide) return hasOverlappingWindow;
            if (dockWindow.cfgIntelligentHide) return hasOverlappingWindow;
            return false;
        }
        property real hideOffset: shouldHide ? -(dockThickness + 10) * dockScale : cfgBottomMargin * dockScale
        property real dockThickness: (cfgIconSize + 8)

        margins {
            bottom: cfgPosition === "bottom" ? hideOffset : 0
            top:    cfgPosition === "top"    ? hideOffset : 0
            left:   cfgPosition === "left"   ? hideOffset : 0
            right:  cfgPosition === "right"  ? hideOffset : 0
        }

        color: "transparent"
        // When alignment is not center, use full screen width so dockContent can align left/right
        property real dockContentWidth: dockContent.implicitWidth + (cfgPadding * 2 * dockScale)
        implicitWidth:  isHorizontal ? (cfgAlignment === "center" ? dockContentWidth : screen.width) : (dockThickness * dockScale)
        implicitHeight: isHorizontal ? (dockThickness * dockScale) : (dockContent.implicitHeight + (cfgPadding * 2 * dockScale))
        exclusiveZone: dockThickness * dockScale
        // Auto hide logic integration
        WlrLayershell.exclusiveZone: (dockWindow.dockConfigData && (dockWindow.dockConfigData.autoHide || dockWindow.cfgIntelligentHide)) ? -1 : (dockThickness * dockScale)

        property bool hasOverlappingWindow: false

        Timer {
            id: hideCheckTimer
            interval: 500; running: dockWindow.dockConfigData && dockWindow.dockConfigData.autoHide; repeat: true
            onTriggered: {
                if (!dockWindow.dockConfigData.autoHide) { dockWindow.hasOverlappingWindow = false; return; }

                try {
                    // Heuristic: hide the dock if any window is present on this monitor
                    // unless the mouse is currently over the dock.
                    var activeWindowsCount = dockWindow.runningWindows.length;
                    dockWindow.hasOverlappingWindow = (activeWindowsCount > 0) && !dockContainsMouse;
                } catch(e) {}
            }
        }

        property bool dockContainsMouse: globalMouse.containsMouse || dockRowMouseArea.containsMouse

        DockBackend {
            id: dockBackend
            is4K: dockWindow.is4K
            suspendHotReload: dockWindow.isDragging
            windowTrackingEnabled: dockWindow.visible
            Component.onCompleted: {
                windowRefreshInterval = 2500
            }
        }

        // ── State ──
        property alias pinnedApps: dockBackend.pinnedApps
        property alias runningWindows: dockBackend.runningWindows
        property alias dockItems: dockBackend.dockItems
        property alias leftModules: dockBackend.leftModules
        property alias rightModules: dockBackend.rightModules

        // 4K monitor check — above 1200px height default scale is 1.5, but the user
        // setting (dockScale) always wins when present.
        property bool is4K: modelData.height > 1200
        property real dockScale: (dockWindow.dockConfigData && dockWindow.dockConfigData.dockScale !== undefined)
            ? dockWindow.dockConfigData.dockScale
            : (dockWindow.is4K ? 1.5 : 1.0)

        property alias dockConfigData: dockBackend.dockConfigData
        property int contextMenuIndex: -1
        property bool contextMenuVisible: false

        // ── Drag state ──
        property int dragFromIndex: -1
        property int dragOverIndex: -1
        property bool isDragging: false
        property real dragStartX: 0
        property real dragGlobalX: 0
        property real dragGlobalY: 0
        property string dragIcon: ""

        // Floating drag icon
        DockGhostIcon {
            isDragging: dockWindow.isDragging
            dragIcon: dockWindow.dragIcon
            dragGlobalX: dockWindow.dragGlobalX
            dragGlobalY: dockWindow.dragGlobalY
            dockScale: dockWindow.dockScale
            backend: dockBackend
        }

        // ── appId → icon (Rofi/Wofi style, sourced from .desktop files) ──
        property alias desktopIcons: dockBackend.desktopIcons
        property alias desktopCommands: dockBackend.desktopCommands
        property alias desktopEntries: dockBackend.desktopEntries
        property alias lastDockConfigContent: dockBackend.lastDockConfigContent

        function shouldShowPinnedSeparator(itemIndex) {
            if (itemIndex === 0 || itemIndex >= dockItems.length) return false;
            var prev = dockItems[itemIndex - 1];
            var curr = dockItems[itemIndex];
            return !!(prev && curr && prev.isPinned && !curr.isPinned && !prev.isModule && !curr.isModule);
        }

        // ── Module component map ──
        property var moduleMap: ({
            "Weather": weatherComp,
            "Volume": volumeComp,
            "Tray": trayComp,
            "Notepad": notepadComp,
            "Power": powerComp,
            "Clipboard": clipboardComp,
            "Launcher": launcherComp,
            "Media": mediaComp
        })

        Component { id: weatherComp; Weather { } }
        Component { id: notepadComp; Notepad { } }
        Component { id: volumeComp; Volume { } }
        Component { id: trayComp; Tray { } }
        Component { id: powerComp; Power { } }
        Component { id: clipboardComp; Clipboard { } }
        Component { id: mediaComp; MediaWidget { dockScale: dockWindow.dockScale } }

        Settings {
            id: settingsMenu
        }

        Component {
            id: launcherComp
            Launcher {
                Component.onCompleted: {
                    settingsRequested.connect(function() {
                        settingsMenu.visible = !settingsMenu.visible;
                    });
                }
            }
        }

        // ── Drag-and-drop finalisation ──
        function handleDrop() {
            var fromIndex = dragFromIndex;
            var toIndex = dragOverIndex;
            dockBackend.logToFile("handleDrop called. From: " + fromIndex + " To: " + toIndex);

            if (fromIndex < 0 || fromIndex >= dockItems.length) return;
            if (toIndex < 0) toIndex = 0;
            if (toIndex >= dockItems.length) toIndex = dockItems.length - 1;
            if (fromIndex === toIndex) return;

            var fromItem = dockItems[fromIndex];

            if (fromItem.isPinned) {
                // Reorder a pinned app.
                var fromPinnedIdx = -1;
                var toPinnedIdx = -1;
                for (var i = 0; i < pinnedApps.length; i++) {
                    if (pinnedApps[i].appId === fromItem.appId) fromPinnedIdx = i;
                }
                var toItem = dockItems[toIndex];
                if (toItem && toItem.isPinned) {
                    for (var j = 0; j < pinnedApps.length; j++) {
                        if (pinnedApps[j].appId === toItem.appId) toPinnedIdx = j;
                    }
                } else {
                    toPinnedIdx = pinnedApps.length - 1;
                }
                dockBackend.reorderPinned(fromPinnedIdx, toPinnedIdx);
            } else {
                // Pin a running app.
                var insertIdx = pinnedApps.length;
                if (toIndex < dockItems.length) {
                    var target = dockItems[toIndex];
                    if (target.isPinned) {
                        for (var k = 0; k < pinnedApps.length; k++) {
                            if (pinnedApps[k].appId === target.appId) {
                                insertIdx = k;
                                break;
                            }
                        }
                    }
                }
                dockBackend.pinAppAt(fromItem.appId, insertIdx);
            }
        }

        // ── Global hover / click-outside area ──
        MouseArea {
            id: globalMouse
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            onClicked: { dockWindow.contextMenuVisible = false; }
        }

        Rectangle {
            id: dockContent
            // Use x position for alignment instead of anchors (QML can't dynamically unset anchors)
            x: {
                if (dockWindow.isHorizontal) {
                    if (dockWindow.cfgAlignment === "left")  return 8;
                    if (dockWindow.cfgAlignment === "right") return parent.width - width - 8;
                    return (parent.width - width) / 2; // center
                }
                return 0;
            }
            y: {
                if (!dockWindow.isHorizontal) {
                    return (parent.height - height) / 2;
                }
                if (dockWindow.cfgPosition === "top") return 0;
                return parent.height - height; // bottom
            }
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

            opacity: 0
            scale: 0.82
            transform: Translate {
                id: dockSlide
                y: dockWindow.cfgPosition === "top" ? -60 : 60
            }

            Component.onCompleted: Qt.callLater(function() { dockEnterAnim.start() })

            ParallelAnimation {
                id: dockEnterAnim
                NumberAnimation { target: dockContent; property: "opacity"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
                NumberAnimation { target: dockContent; property: "scale";   from: 0.82; to: 1; duration: 540; easing.type: Easing.OutBack }
                NumberAnimation { target: dockSlide;   property: "y";       to: 0;          duration: 540; easing.type: Easing.OutBack }
            }

            implicitWidth: dockRow.implicitWidth + (dockWindow.cfgPadding * 2 * dockScale)
            implicitHeight: (dockWindow.cfgIconSize + 8) * dockScale
            radius: 14 * dockScale
            color: (dockWindow.dockConfigData && dockWindow.dockConfigData.showBackground === false) ? "transparent" : Qt.rgba(30/255, 30/255, 46/255, dockWindow.cfgTransparency)
            border.color: (dockWindow.dockConfigData && dockWindow.dockConfigData.showBackground === false) ? "transparent" : (dockWindow.cfgShowBorder ? Qt.rgba(49/255, 50/255, 68/255, 0.8) : "transparent")
            border.width: (dockWindow.dockConfigData && dockWindow.dockConfigData.showBackground === false) ? 0 : (dockWindow.cfgShowBorder ? 1 : 0)

            // Subtle glow outside the border
            Rectangle {
                visible: dockWindow.dockConfigData && dockWindow.dockConfigData.showBackground !== false && dockWindow.cfgShowBorder
                anchors.fill: parent
                anchors.margins: -1
                radius: parent.radius + 1
                color: "transparent"
                border.color: Qt.rgba(137/255, 180/255, 250/255, 0.12)
                border.width: 1
                z: -1
            }

            MouseArea {
                id: dockRowMouseArea
                anchors.fill: parent
                hoverEnabled: true
                z: -2
            }

            Row {
                id: dockRow
                anchors.centerIn: parent
                spacing: dockWindow.cfgItemSpacing * dockScale

                // ── Left modules ──
                Repeater {
                    model: dockWindow.leftModules
                    DockModuleSlot {
                        moduleMap: dockWindow.moduleMap
                        dockScale: dockWindow.dockScale
                        iconSize: dockWindow.cfgIconSize
                    }
                }

                DockSeparator {
                    visible: dockWindow.leftModules.length > 0
                    dockScale: dockWindow.dockScale
                    iconSize: dockWindow.cfgIconSize
                }

                Repeater {
                    id: dockRepeater
                    model: dockWindow.dockItems

                    // Repeater auto-satisfies the required modelData/index on DockItem.
                    DockItem {
                        dockScale: dockWindow.dockScale
                        panel: dockWindow
                        backend: dockBackend
                        repeater: dockRepeater
                        row: dockRow
                        content: dockContent
                        moduleMap: dockWindow.moduleMap
                        settingsPopup: settingsMenu
                    }
                }

                DockSeparator {
                    visible: dockWindow.rightModules.length > 0
                    dockScale: dockWindow.dockScale
                    iconSize: dockWindow.cfgIconSize
                }

                // ── Right modules ──
                Repeater {
                    model: dockWindow.rightModules
                    DockModuleSlot {
                        moduleMap: dockWindow.moduleMap
                        dockScale: dockWindow.dockScale
                        iconSize: dockWindow.cfgIconSize
                    }
                }
            }
        }
    }
}
