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
                    // Check if any active window intersects dock region on this monitor
                    // To do this simply, we check if there are maximized windows on this monitor
                    var activeWindowsCount = dockWindow.runningWindows.length;
                    
                    // Simple heuristic: if any window exists, hide dock unless mouse is over
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
        property alias leftModules: dockBackend.leftModules  // Sol taraf modülleri
        property alias rightModules: dockBackend.rightModules // Sağ taraf modülleri
        
        // 4K monitör kontrolü (1080p'den büyükse varsayılan 1.5 al ama user ayarı ile ez)
        property bool is4K: modelData.height > 1200
        property real dockScale: (dockWindow.dockConfigData && dockWindow.dockConfigData.dockScale !== undefined)
            ? dockWindow.dockConfigData.dockScale
            : (dockWindow.is4K ? 1.5 : 1.0)
        
        property alias dockConfigData: dockBackend.dockConfigData // Ayarları okumak için obje
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

        // ── Ghost Icon ──
        Rectangle {
            visible: dockWindow.isDragging
            width: 36 * dockScale
            height: 36 * dockScale
            radius: 14 * dockScale
            color: "transparent" // Ghost icon arka planı şeffaf olsun, ikonun kendi şekli görünsün
            z: 9999

            x: dockWindow.dragGlobalX - (width / 2)
            y: dockWindow.dragGlobalY - (height / 2)

            Image {
                anchors.fill: parent
                source: {
                    if (!dockWindow.dragIcon) return "";
                    if (dockWindow.dragIcon.startsWith("/")) return "file://" + dockWindow.dragIcon;
                    return "image://icon/" + dockBackend.resolveThemedIconName(dockWindow.dragIcon);
                }
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        // ── appId → icon (Rofi/Wofi tarzı: .desktop dosyalarından) ──
        property alias desktopIcons: dockBackend.desktopIcons
        property alias desktopCommands: dockBackend.desktopCommands
        property alias desktopEntries: dockBackend.desktopEntries
        property alias lastDockConfigContent: dockBackend.lastDockConfigContent

        component ContextMenuAction: Rectangle {
            required property string label
            required property color labelColor
            required property var onActivate

            width: 140 * dockScale
            height: 30 * dockScale
            radius: 8 * dockScale
            color: actionMouse.containsMouse ? Qt.rgba(137/255, 180/255, 250/255, 0.18) : "transparent"

            Text {
                anchors.centerIn: parent
                text: label
                color: labelColor
                font.pixelSize: 12 * dockScale
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
            }

            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (onActivate) onActivate()
            }
        }

        component ContextMenuSeparator: Rectangle {
            width: 120 * dockScale
            height: 1
            color: Qt.rgba(1, 1, 1, 0.1)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        function shouldShowPinnedSeparator(itemIndex) {
            if (itemIndex === 0 || itemIndex >= dockItems.length) return false;
            var prev = dockItems[itemIndex - 1];
            var curr = dockItems[itemIndex];
            return !!(prev && curr && prev.isPinned && !curr.isPinned && !prev.isModule && !curr.isModule);
        }


        // ── Modül Eşleştirmesi ──
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

        // Launcher Component — sinyal bağlantısı
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

        // ── Sürükle-bırak sonuçlandırma ──
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
                // Pinli uygulamayı yeniden sırala
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
                // Çalışan uygulamayı pinle
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

        // ── Mouse pozisyonundan hangi item üzerinde olduğunu hesapla ──
        function getItemIndexAtX(globalX) {
            // dockRow içindeki her item 36px * scale
            var rowX = dockRow.mapFromItem(dockWindow.contentItem, globalX, 0).x;
            var itemWidth = 36 * dockScale;
            var spacing = 2 * dockScale;
            var totalItems = dockItems.length;

            for (var i = 0; i < totalItems; i++) {
                var itemStart = i * (itemWidth + spacing);
                var itemEnd = itemStart + itemWidth;
                if (rowX >= itemStart && rowX <= itemEnd) return i;
            }

            // Sınır dışıysa en yakın item
            if (rowX < 0) return 0;
            return totalItems - 1;
        }


        // ── Ana mouse alanı: tüm sürükleme burada yönetilir ──
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

            // Glow
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

                // ── Sol Modüller ──
                Repeater {
                    model: dockWindow.leftModules
                    Item {
                        width: leftModLoader.item ? leftModLoader.item.implicitWidth : dockWindow.cfgIconSize * dockScale
                        height: (dockWindow.cfgIconSize + 8) * dockScale
                        Loader {
                            id: leftModLoader
                            active: true
                            sourceComponent: dockWindow.moduleMap[modelData] || null
                            anchors.centerIn: parent
                        }
                    }
                }

                // Sol ayırıcı (sol modül varsa)
                Rectangle {
                    visible: dockWindow.leftModules.length > 0
                    width: 1 * dockScale
                    height: dockWindow.cfgIconSize * 0.6 * dockScale
                    color: Qt.rgba(147/255, 153/255, 178/255, 0.35)
                    anchors.verticalCenter: parent.verticalCenter
                }


                Repeater {
                    id: dockRepeater
                    model: dockWindow.dockItems

                    Item {
                        id: dockItemContainer
                        width: modelData.isModule ? (moduleLoader.item ? moduleLoader.item.implicitWidth : dockWindow.cfgIconSize * dockScale) : dockWindow.cfgIconSize * dockScale
                        height: (dockWindow.cfgIconSize + 8) * dockScale

                        Loader {
                            id: moduleLoader
                            active: modelData.isModule
                            sourceComponent: modelData.isModule ? (dockWindow.moduleMap[modelData.moduleName] || null) : null
                            anchors.centerIn: parent
                            // Scale down if needed? Bar modules might assume 34px height. Dock item container is 46px height.
                            // Bar modules in Bar.qml have implicitHeight: 34.
                            // We can center them.
                        }

                        // App Item (only if not module)
                        Item {
                            anchors.fill: parent
                            visible: !modelData.isModule

                            // Ayırıcı (Only for apps, or maybe logical to show between app and module too?)
                            // Original logic: if (index === 0) return false; ... prev.isPinned && !curr.isPinned
                            Rectangle {
                                visible: dockWindow.shouldShowPinnedSeparator(index)
                                width: 1 * dockScale
                                height: dockWindow.cfgIconSize * 0.6 * dockScale
                                color: Qt.rgba(147/255, 153/255, 178/255, 0.35)
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: -3
                            }

                            Rectangle {
                                id: dockItem
                                anchors.centerIn: parent
                                width: dockWindow.cfgIconSize * dockScale
                                height: dockWindow.cfgIconSize * dockScale
                                radius: (dockWindow.cfgIconSize * 0.25) * dockScale
                                color: itemMouse.containsMouse
                                    ? Qt.rgba(137/255, 180/255, 250/255, 0.18)
                                    : "transparent"

                                // Sürüklenirken tamamen gizle (yer tutucu olarak kalsın ama görünmesin)
                                opacity: dockWindow.isDragging && dockWindow.dragFromIndex === index ? 0.0 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                Behavior on color { ColorAnimation { duration: 180 } }

                                property real hoverScale: itemMouse.containsMouse && !dockWindow.isDragging ? 1.22 : 1.0
                                Behavior on hoverScale {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                }

                                transform: Scale {
                                    origin.x: dockItem.width / 2
                                    origin.y: dockItem.height
                                    xScale: dockItem.hoverScale
                                    yScale: dockItem.hoverScale
                                }

                                Image {
                                    anchors.centerIn: parent
                                    width: (dockWindow.cfgIconSize - 4) * dockScale
                                    height: (dockWindow.cfgIconSize - 4) * dockScale
                                    source: {
                                        if (!modelData.icon) return "image://icon/application-x-executable";
                                        if (modelData.icon.startsWith("/")) return "file://" + modelData.icon;
                                        return "image://icon/" + dockBackend.resolveThemedIconName(modelData.icon);
                                    }
                                    sourceSize: Qt.size(64, 64)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    antialiasing: true
                                    opacity: dockWindow.isDragging && dockWindow.dragFromIndex === index ? 0 : 1
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                // Tooltip
                                Rectangle {
                                    id: tooltip
                                    visible: itemMouse.containsMouse && !dockWindow.contextMenuVisible && !dockWindow.isDragging
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.top
                                    anchors.bottomMargin: 10 * dockScale
                                    width: tooltipText.implicitWidth + (18 * dockScale)
                                    height: tooltipText.implicitHeight + (10 * dockScale)
                                    radius: 9 * dockScale
                                    color: Qt.rgba(30/255, 30/255, 46/255, 0.96)
                                    border.color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                                    border.width: 1

                                    Text {
                                        id: tooltipText
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        color: Theme.text
                                        font.pixelSize: 11 * dockScale
                                        font.bold: true
                                    }

                                    opacity: itemMouse.containsMouse ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: dockWindow.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    preventStealing: true

                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool dragStarted: false

                                    onPressed: (mouse) => {
                                        if (mouse.button === Qt.LeftButton) {
                                            pressX = mouse.x;
                                            pressY = mouse.y;
                                            dragStarted = false;
                                        }
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return;

                                        if (dockWindow.isDragging) {
                                            var pos = mapToItem(dockWindow.contentItem, mouse.x, mouse.y);
                                            dockWindow.dragGlobalX = pos.x;
                                            dockWindow.dragGlobalY = pos.y;
                                        }

                                        if (!dragStarted && (Math.abs(mouse.x - pressX) > 4 || Math.abs(mouse.y - pressY) > 4)) {
                                            dockBackend.logToFile("Drag started! Index: " + index);
                                            dragStarted = true;
                                            dockWindow.isDragging = true;
                                            dockWindow.dragFromIndex = index;
                                            dockWindow.contextMenuVisible = false;
                                            dockWindow.dragIcon = modelData.icon;
                                            
                                            var startPos = mapToItem(dockWindow.contentItem, mouse.x, mouse.y);
                                            dockWindow.dragGlobalX = startPos.x;
                                            dockWindow.dragGlobalY = startPos.y;
                                        }

                                        if (dragStarted) {
                                            var globalPos = mapToItem(dockRow, mouse.x, mouse.y);
                                            // Repeater'ın Row içindeki konumunu hesapla
                                            var repeaterPos = dockRepeater.mapToItem ? globalPos.x : globalPos.x;
                                            var itemWidth = 32 * dockScale;
                                            var spacing = 2 * dockScale;
                                            // dockRepeater'ın ilk item'ının Row içindeki x konumunu bul
                                            var firstItem = dockRepeater.itemAt(0);
                                            var offsetX = firstItem ? firstItem.mapToItem(dockRow, 0, 0).x : 0;
                                            var adjustedX = globalPos.x - offsetX;
                                            var targetIdx = Math.floor(adjustedX / (itemWidth + spacing));
                                            
                                            if (targetIdx < 0) targetIdx = 0;
                                            if (targetIdx >= dockWindow.dockItems.length) targetIdx = dockWindow.dockItems.length - 1;
                                            
                                            dockWindow.dragOverIndex = targetIdx;
                                        }
                                    }

                                    onReleased: (mouse) => {
                                        if (dragStarted) {
                                            dockWindow.isDragging = false;

                                            var globalPos = mapToItem(dockContent, mouse.x, mouse.y);
                                            
                                            // Wayland window grabs often clamp coordinates to the surface.
                                            // If the user drags to the very edge of the dock, we consider it outside.
                                            // The surface ends at -cfgPadding on top.
                                            var isOutside = (globalPos.y < -15 || globalPos.y > dockContent.height + 15 || globalPos.x < -20 || globalPos.x > dockContent.width + 20); 
                                            var wasPinned = modelData.isPinned;

                                            var appIdToDelete = modelData.appId;

                                            dockBackend.logToFile("Released. Outside: " + isOutside);
                                            
                                            if (isOutside) {
                                                if (wasPinned) {
                                                    dockBackend.unpinApp(appIdToDelete);
                                                }
                                            } else {
                                                dockWindow.handleDrop();
                                            }

                                            // Reset drag state
                                            dockWindow.dragFromIndex = -1;
                                            dockWindow.dragOverIndex = -1;
                                            dockWindow.dragIcon = "";
                                            dragStarted = false;
                                        }
                                    }

                                    onClicked: (mouse) => {
                                        if (dragStarted) return;
                                        if (mouse.button === Qt.RightButton) {
                                            dockWindow.contextMenuIndex = index;
                                            dockWindow.contextMenuVisible = true;
                                        } else {
                                            dockWindow.contextMenuVisible = false;
                                            
                                            var logMsg = "Clicked: " + modelData.appId + 
                                                        " | Running: " + modelData.isRunning + 
                                                        " | WinID: " + modelData.windowId + 
                                                        " | Cmd: " + modelData.cmd;
                                            dockBackend.logToFile(logMsg);

                                            if (modelData.isRunning && modelData.windowId && modelData.windowId !== -1) {
                                                // Açık pencereye odaklan
                                                dockBackend.focusWindow(modelData.windowId);
                                            } else {
                                                dockBackend.launchApp(modelData.cmd);
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Çalışıyor göstergesi ──
                            Rectangle {
                                visible: modelData.isRunning
                                // circle: küçük daire; line: ince çizgi
                                width:  dockWindow.cfgIndicator === "line" ? (dockWindow.cfgIconSize * 0.6 * dockScale) : (5 * dockScale)
                                height: dockWindow.cfgIndicator === "line" ? (2 * dockScale) : (5 * dockScale)
                                radius: dockWindow.cfgIndicator === "line" ? (1 * dockScale) : (2.5 * dockScale)
                                color: Theme.primary
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 0

                                Rectangle {
                                    visible: dockWindow.cfgIndicator !== "line"
                                    anchors.centerIn: parent
                                    width: 9 * dockScale
                                    height: 9 * dockScale
                                    radius: 4.5 * dockScale
                                    color: Qt.rgba(137/255, 180/255, 250/255, 0.25)
                                    z: -1
                                }
                            }

                            // ── Sağ tık menüsü ──
                            Rectangle {
                                id: contextMenu
                                visible: dockWindow.contextMenuVisible && dockWindow.contextMenuIndex === index
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.top
                                anchors.bottomMargin: 14
                                width: menuContent.implicitWidth + (16 * dockScale)
                                height: menuContent.implicitHeight + (12 * dockScale)
                                radius: 12 * dockScale
                                color: Qt.rgba(30/255, 30/255, 46/255, 0.96)
                                border.color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                                border.width: 1
                                z: 100

                                Column {
                                    id: menuContent
                                    anchors.centerIn: parent
                                    spacing: 2

                                    ContextMenuAction {
                                        label: modelData.isPinned ? "  Dock'tan Kaldır" : "  Dock'a Sabitle"
                                        labelColor: modelData.isPinned ? Theme.red : Theme.primary
                                        onActivate: function() {
                                            if (modelData.isPinned) {
                                                dockBackend.unpinApp(modelData.appId);
                                            } else {
                                                dockBackend.pinApp(modelData.appId);
                                            }
                                            dockWindow.contextMenuVisible = false;
                                        }
                                    }

                                    ContextMenuSeparator {}

                                    ContextMenuAction {
                                        label: "  Uygulamayı Kapat"
                                        labelColor: Theme.text
                                        onActivate: function() {
                                            if (modelData.isRunning && modelData.windowId) {
                                                dockBackend.closeWindow(modelData.windowId);
                                            }
                                            dockWindow.contextMenuVisible = false;
                                        }
                                    }

                                    ContextMenuSeparator {}

                                    ContextMenuAction {
                                        label: "  Dock Ayarları"
                                        labelColor: Theme.text
                                        onActivate: function() {
                                            settingsMenu.currentPage = "dock";
                                            settingsMenu.visible = true;
                                            dockWindow.contextMenuVisible = false;
                                        }
                                    }
                                }
                            }
                        } // End of App Item wrapper

                        property int itemIndex: index

                        // ── Drop göstergesi ──
                        // Move this OUTSIDE the App Item wrapper so it shows for modules too
                        Rectangle {
                            visible: dockWindow.isDragging && dockWindow.dragOverIndex === index && dockWindow.dragFromIndex !== index
                            width: 2 * dockScale
                            height: 32 * dockScale
                            radius: 1 * dockScale
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                            
                            // Sürükleme yönüne göre sağa veya sola yapış
                            anchors.left: (dockWindow.dragOverIndex > dockWindow.dragFromIndex) ? undefined : parent.left
                            anchors.right: (dockWindow.dragOverIndex > dockWindow.dragFromIndex) ? parent.right : undefined
                            anchors.leftMargin: (dockWindow.dragOverIndex > dockWindow.dragFromIndex) ? 0 : -4
                            anchors.rightMargin: (dockWindow.dragOverIndex > dockWindow.dragFromIndex) ? -4 : 0
                            
                            z: 50

                            Rectangle {
                                anchors.centerIn: parent
                                width: 7
                                height: 44
                                radius: 3.5
                                color: Qt.rgba(137/255, 180/255, 250/255, 0.2)
                                z: -1
                            }
                        }
                    }
                }

                // Sağ ayırıcı (sağ modül varsa)
                Rectangle {
                    visible: dockWindow.rightModules.length > 0
                    width: 1 * dockScale
                    height: dockWindow.cfgIconSize * 0.6 * dockScale
                    color: Qt.rgba(147/255, 153/255, 178/255, 0.35)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── Sağ Modüller ──
                Repeater {
                    model: dockWindow.rightModules
                    Item {
                        width: rightModLoader.item ? rightModLoader.item.implicitWidth : dockWindow.cfgIconSize * dockScale
                        height: (dockWindow.cfgIconSize + 8) * dockScale
                        Loader {
                            id: rightModLoader
                            active: true
                            sourceComponent: dockWindow.moduleMap[modelData] || null
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }
    }
}
