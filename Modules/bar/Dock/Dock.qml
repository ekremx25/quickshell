import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
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
                if (!dockWindow.dockConfigData.autoHide || !winProc.outputBuffer) { dockWindow.hasOverlappingWindow = false; return; }
                
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



        // ── State ──
        property var pinnedApps: []
        property var runningWindows: []
        property var dockItems: []
        property var leftModules: []  // Sol taraf modülleri
        property var rightModules: [] // Sağ taraf modülleri
        
        // 4K monitör kontrolü (1080p'den büyükse varsayılan 1.5 al ama user ayarı ile ez)
        property bool is4K: modelData.height > 1200
        property real dockScale: is4K ? 1.5 : 1.0
        
        onDockScaleChanged: {
            if (dockItems.length > 0) {
                console.log("Dock.qml: dockScale changed to " + dockScale + ", rebuilding items...");
                Qt.callLater(rebuildDockItems);
            }
        }
        
        property var dockConfigData: null // Ayarları okumak için obje

        property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/dock_config.json"
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
                    return "image://icon/" + dockWindow.dragIcon;
                }
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        // ── appId → icon (Rofi/Wofi tarzı: .desktop dosyalarından) ──
        property var desktopIcons: ({})
        property string desktopIconScript: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/scripts/desktop_icons.sh"

        Process {
            id: desktopIconProc
            command: ["bash", dockWindow.desktopIconScript]
            property string outputBuffer: ""
            stdout: SplitParser { onRead: (data) => desktopIconProc.outputBuffer += data }
            onExited: {
                if (desktopIconProc.outputBuffer.trim() === "") return;
                try {
                    var parsed = JSON.parse(desktopIconProc.outputBuffer);
                    dockWindow.desktopIcons = parsed;
                    console.log("Desktop icons loaded: " + Object.keys(parsed).length + " apps");
                } catch (e) {
                    console.log("Desktop icons parse error: " + e);
                }
                desktopIconProc.outputBuffer = "";
                dockWindow.rebuildDockItems();
            }
            Component.onCompleted: running = true
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
                    console.log("Dock: Launcher component created");
                    settingsRequested.connect(function() {
                        console.log("Dock: Settings requested by Launcher");
                        settingsMenu.visible = !settingsMenu.visible;
                        console.log("Dock: Settings menu visible set to " + settingsMenu.visible);
                    });
                }
            }
        }

        // ── appId → icon (Rofi/Wofi yaklaşımı) ──
        function getIcon(appId) {
            if (!appId) return "application-x-executable";
            var c = appId.toLowerCase();

            // 1. .desktop dosyasından gelen icon adını bul
            if (dockWindow.desktopIcons[c]) return dockWindow.desktopIcons[c];

            // 2. "org.xxx.AppName" → kısa isimle tekrar dene
            if (c.indexOf(".") !== -1) {
                var parts = c.split(".");
                var shortName = parts[parts.length - 1].toLowerCase();
                if (dockWindow.desktopIcons[shortName]) return dockWindow.desktopIcons[shortName];
            }

            // 3. Özel durumlar
            if (c.match(/resolve|davinci/)) return "/opt/resolve/graphics/DV_Resolve.png";

            // 4. Son fallback: appId'yi doğrudan icon adı olarak ver
            //    image://icon/ Qt'nin icon theme cache'ini kullanarak çözer
            return c;
        }

        // ── appId → name ──
        function getAppName(appId) {
            if (!appId) return "Uygulama";
            var c = appId.toLowerCase();
            if (c.match(/firefox/)) return "Firefox";
            if (c.match(/brave/)) return "Brave";
            if (c.match(/chrom/)) return "Chrome";
            if (c.match(/opera/)) return "Opera";
            if (c.match(/vivaldi/)) return "Vivaldi";
            if (c.match(/edge/)) return "Edge";
            if (c.match(/kitty/)) return "Kitty";
            if (c.match(/konsole/)) return "Konsole";
            if (c.match(/wezterm/)) return "WezTerm";
            if (c.match(/ghostty/)) return "Ghostty";
            if (c.match(/alacritty/)) return "Alacritty";
            if (c.match(/foot/)) return "Foot";
            if (c.match(/gnome-terminal/)) return "Terminal";
            if (c.match(/telegram/)) return "Telegram";
            if (c.match(/discord|vesktop/)) return "Discord";
            if (c.match(/signal/)) return "Signal";
            if (c.match(/whatsapp/)) return "WhatsApp";
            if (c.match(/slack/)) return "Slack";
            if (c.match(/zoom/)) return "Zoom";
            if (c.match(/teams/)) return "Teams";
            if (c.match(/skype/)) return "Skype";
            if (c.match(/dolphin/)) return "Dosyalar";
            if (c.match(/thunar/)) return "Thunar";
            if (c.match(/nemo/)) return "Nemo";
            if (c.match(/nautilus/)) return "Dosyalar";
            if (c.match(/spotify/)) return "Spotify";
            if (c.match(/vscode|code/)) return "VS Code";
            if (c.match(/cursor/)) return "Cursor";
            if (c.match(/zed/)) return "Zed";
            if (c.match(/intellij/)) return "IntelliJ";
            if (c.match(/pycharm/)) return "PyCharm";
            if (c.match(/android-studio/)) return "Android Studio";
            if (c.match(/obs/)) return "OBS Studio";
            if (c.match(/vlc/)) return "VLC";
            if (c.match(/mpv/)) return "MPV";
            if (c.match(/kdenlive/)) return "Kdenlive";
            if (c.match(/blender/)) return "Blender";
            if (c.match(/gimp/)) return "GIMP";
            if (c.match(/inkscape/)) return "Inkscape";
            if (c.match(/libreoffice/)) return "LibreOffice";
            if (c.match(/steam/)) return "Steam";
            if (c.match(/lutris/)) return "Lutris";
            if (c.match(/heroic/)) return "Heroic";
            if (c.match(/prismlauncher/)) return "Prism Launcher";
            if (c.match(/virtualbox/)) return "VirtualBox";
            if (c.match(/antigravity/)) return "Antigravity";
            return appId.charAt(0).toUpperCase() + appId.slice(1);
        }

        // ── App ID Normalizasyonu ──
        function normalizeAppId(appId) {
            if (!appId) return "";
            var lower = appId.toLowerCase();
            if (lower === "org.telegram.desktop") return "Telegram";
            if (lower === "org.kde.dolphin") return "dolphin";
            if (lower === "firefox-esr") return "firefox";
            if (lower === "microsoft-edge") return "microsoft-edge-stable";
            if (lower === "google-chrome") return "google-chrome-stable";
               if (lower === "brave") return "brave";
            return appId;
        }

        // ── Birleşik listeyi oluştur ──
        Timer {
            id: rebuildTimer
            interval: 5
            onTriggered: dockWindow.rebuildDockItemsImmediate()
        }

        function rebuildDockItems() {
            rebuildTimer.restart();
        }

        function rebuildDockItemsImmediate() {
            if (dockWindow.isDragging) return; 

            var items = [];
            var pinnedIds = {};

            for (var i = 0; i < pinnedApps.length; i++) {
                var p = pinnedApps[i];
                pinnedIds[p.appId] = true;
                var isRunning = false;
                var windowId = -1;
                for (var j = 0; j < runningWindows.length; j++) {
                    var runningId = normalizeAppId(runningWindows[j].app_id);
                    if (runningId === p.appId) {
                        isRunning = true;
                        windowId = runningWindows[j].id;
                        break;
                    }
                }
                var rawIcon = p.icon && p.icon !== "" ? p.icon : getIcon(p.appId);
                var resolvedIcon = rawIcon;
                
                // Expand ~ to home directory
                if (resolvedIcon.indexOf("~") === 0) {
                    resolvedIcon = StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + resolvedIcon.substring(1);
                }

                if (dockWindow.desktopIcons[resolvedIcon.toLowerCase()]) {
                     resolvedIcon = dockWindow.desktopIcons[resolvedIcon.toLowerCase()];
                }

                items.push({
                    name: getAppName(p.appId), 
                    icon: resolvedIcon,
                    cmd: p.cmd,
                    appId: p.appId, isPinned: true, isRunning: isRunning, windowId: windowId,
                    isModule: false 
                });
            }

            var seenIds = {};
            for (var k = 0; k < runningWindows.length; k++) {
                var win = runningWindows[k];
                var rawId = win.app_id || "";
                var normId = normalizeAppId(rawId);
                
                if (normId === "" || pinnedIds[normId] || seenIds[normId]) continue;
                
                seenIds[normId] = true;
                items.push({
                    name: getAppName(rawId), icon: getIcon(rawId), cmd: rawId,
                    appId: normId, isPinned: false, isRunning: true, windowId: win.id,
                    isModule: false
                });
            }


            dockItems = items;
        }

        // ── Config yoksa otomatik oluştur, varsa oku ──
        property string initDockScript: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/scripts/init_dock.sh"

        Process {
            id: initDockProc
            command: ["bash", dockWindow.initDockScript]
            onExited: {
                console.log("init_dock.sh completed, reading generated config...");
                configReadProc.running = true;
            }
        }

        // ── Config okuma ──
        Process {
            id: configReadProc
            command: ["cat", dockWindow.configPath]
            property string outputBuffer: ""
            property string lastContent: ""

            stdout: SplitParser { onRead: (data) => configReadProc.outputBuffer += data }
            onExited: {
                if (dockWindow.isDragging) {
                    configReadProc.outputBuffer = "";
                    return;
                }

                var content = configReadProc.outputBuffer.trim();
                configReadProc.outputBuffer = "";

                // Config dosyası yoksa → init_dock.sh ile oluştur
                if (content === "" && lastContent === "") {
                    console.log("dock_config.json not found, running init_dock.sh...");
                    initDockProc.running = true;
                    return;
                }
                
                if (content === "" || content === lastContent) return;
                
                try {
                    var cfg = JSON.parse(content);
                    lastContent = content;
                    
                    dockWindow.dockConfigData = cfg
                    dockWindow.pinnedApps = cfg.pinned || [];
                    dockWindow.leftModules = cfg.leftModules || [];
                    dockWindow.rightModules = cfg.rightModules || [];
                    
                    if (cfg.dockScale !== undefined) {
                        dockWindow.dockScale = cfg.dockScale;
                    } else {
                        dockWindow.dockScale = dockWindow.is4K ? 1.5 : 1.0;
                    }
                    
                    // Force binding re-evaluation for items depending on visual scaling
                    var currentScale = dockWindow.dockScale;
                    dockWindow.dockScale = 0;
                    dockWindow.dockScale = currentScale;
                    
                    // Trigger a re-evaluation of bindings relying on dockConfigData properties by assigning it again or explicitly modifying properties
                    var showBg = cfg.showBackground !== undefined ? cfg.showBackground : true;
                    var autoHide = cfg.autoHide !== undefined ? cfg.autoHide : false;
                    
                    if (dockWindow.dockConfigData.showBackground !== showBg) { dockWindow.dockConfigData.showBackground = showBg; }
                    
                    console.log("Dock config updated via hot-reload");
                    dockWindow.rebuildDockItems();
                } catch (e) {
                    console.log("Dock config parse error: " + e);
                }
            }
        }

        Timer {
            interval: 300
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!configReadProc.running) configReadProc.running = true;
            }
        }

        // ── Çalışan pencere takibi ──
        Process {
            id: winProc
            command: S.CompositorService.isHyprland ? ["hyprctl", "clients", "-j"] : ["niri", "msg", "-j", "windows"]
            property string outputBuffer: ""
            stdout: SplitParser { onRead: (data) => winProc.outputBuffer += data }
            onExited: {
                if (winProc.outputBuffer.trim() === "") return;
                try {
                    var parsed = JSON.parse(winProc.outputBuffer);
                    if (S.CompositorService.isHyprland) {
                        // Hyprland format: { "class": "...", "address": "0x..." }
                        // Normalize to dock's expected format: { "app_id": "...", "id": "..." }
                        var normalized = [];
                        for (var i = 0; i < parsed.length; i++) {
                            normalized.push({
                                app_id: parsed[i].class || "",
                                id: parsed[i].address || ""
                            });
                        }
                        dockWindow.runningWindows = normalized;
                    } else {
                        dockWindow.runningWindows = parsed;
                    }
                } catch (e) {
                    console.log("Dock win hatası: " + e);
                }
                winProc.outputBuffer = "";
                dockWindow.rebuildDockItems();
            }
        }

        // ── Config yazma ──
        Process {
            id: configWriteProc
            command: []
            running: false
        }

        // ── Debug Logging ──
        Process { id: logProc; command: []; running: false }
        function logToFile(msg) {
            logProc.running = false;
            var safeMsg = msg.replace(/"/g, '\\"');
            logProc.command = ["sh", "-c", "echo \"" + safeMsg + "\" >> /tmp/qs_dock.log"];
            logProc.running = true;
        }

        function savePinnedApps() {
            // Start from existing config to preserve ALL settings
            var obj = {};
            if (dockWindow.dockConfigData) {
                // Clone all existing config properties
                var keys = Object.keys(dockWindow.dockConfigData);
                for (var i = 0; i < keys.length; i++) {
                    obj[keys[i]] = dockWindow.dockConfigData[keys[i]];
                }
            }
            // Only overwrite pinned apps and modules
            obj.pinned = pinnedApps;
            obj.leftModules = dockWindow.leftModules;
            obj.rightModules = dockWindow.rightModules;

            var jsonStr = JSON.stringify(obj, null, 2);
            configWriteProc.running = false;
            configWriteProc.command = ["sh", "-c", "printf '%s' '" + jsonStr.replace(/'/g, "'\\''") + "' > " + configPath];
            configWriteProc.running = true;
        }

        function pinApp(appId) {
            for (var i = 0; i < pinnedApps.length; i++) {
                if (pinnedApps[i].appId === appId) return;
            }
            var newPinned = pinnedApps.slice();
            newPinned.push({
                name: getAppName(appId), icon: appId.toLowerCase(),
                cmd: appId, appId: appId
            });
            pinnedApps = newPinned;

            logToFile("pinApp: " + appId);
            savePinnedApps();
            rebuildDockItems();
        }

        function pinAppAt(appId, targetIndex) {
            for (var i = 0; i < pinnedApps.length; i++) {
                if (pinnedApps[i].appId === appId) return;
            }
            var newPinned = pinnedApps.slice();
            var newItem = {
                name: getAppName(appId), icon: appId.toLowerCase(),
                cmd: appId, appId: appId
            };
            if (targetIndex >= 0 && targetIndex <= newPinned.length) {
                newPinned.splice(targetIndex, 0, newItem);
            } else {
                newPinned.push(newItem);
            }
            pinnedApps = newPinned;
            savePinnedApps();
            rebuildDockItems();
        }

        function reorderPinned(fromIdx, toIdx) {
            if (fromIdx < 0 || fromIdx >= pinnedApps.length) return;
            if (toIdx < 0) toIdx = 0;
            if (toIdx >= pinnedApps.length) toIdx = pinnedApps.length - 1;
            if (fromIdx === toIdx) return;

            var newPinned = pinnedApps.slice();
            var item = newPinned.splice(fromIdx, 1)[0];
            newPinned.splice(toIdx, 0, item);
            pinnedApps = newPinned;
            logToFile("reorderPinned: from " + fromIdx + " to " + toIdx);
            savePinnedApps();
            rebuildDockItems();
        }

        function unpinApp(appId) {
            var newPinned = [];
            for (var i = 0; i < pinnedApps.length; i++) {
                if (pinnedApps[i].appId !== appId) newPinned.push(pinnedApps[i]);
            }
            pinnedApps = newPinned;
            savePinnedApps();
            rebuildDockItems();
        }

        // ── Sürükle-bırak sonuçlandırma ──
        function handleDrop() {
            var fromIndex = dragFromIndex;
            var toIndex = dragOverIndex;
            logToFile("handleDrop called. From: " + fromIndex + " To: " + toIndex);

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
                reorderPinned(fromPinnedIdx, toPinnedIdx);
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
                pinAppAt(fromItem.appId, insertIdx);
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

        // ── Uygulama başlatıcı ──
        Process { id: launchProc; command: []; running: false }
        function launchApp(cmd) {
            launchProc.running = false;
            // Detach process so it survives when launchProc is reused/killed
            var detachedCmd = "nohup " + cmd + " > /dev/null 2>&1 &";
            launchProc.command = ["sh", "-c", detachedCmd];
            launchProc.running = true;
        }

        // Pencereye odaklan (compositor-aware)
        Process { id: focusProc; command: []; running: false }
        function focusWindow(windowId) {
            focusProc.running = false;
            if (S.CompositorService.isHyprland) {
                focusProc.command = ["hyprctl", "dispatch", "focuswindow", "address:" + windowId];
            } else {
                focusProc.command = ["niri", "msg", "action", "focus-window", "--id", "" + windowId];
            }
            focusProc.running = true;
        }

        // ── Periyodik güncelleme ──
        Timer {
            id: updateTimer
            interval: 1500; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                if (!dockWindow.isDragging && !winProc.running) winProc.running = true;
            }
        }

        Component.onCompleted: {
            // configReadProc handled by Timer
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
                                visible: {
                                    if (index === 0) return false;
                                    var items = dockWindow.dockItems;
                                    if (index >= items.length) return false;
                                    var prev = items[index - 1];
                                    var curr = items[index];
                                    // Separator if prev is pinned app and curr is unpinned app?
                                    // Or between apps and modules?
                                    // Let's keep original logic for now, simpler.
                                    var p = (prev && curr && prev.isPinned && !curr.isPinned && !prev.isModule && !curr.isModule);
                                    return !!p;
                                }
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
                                        return "image://icon/" + modelData.icon;
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
                                            console.log("Pressed. X: " + pressX);
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
                                            logToFile("Drag started! Index: " + index);
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

                                            logToFile("Released. Outside: " + isOutside);
                                            
                                            if (isOutside) {
                                                if (wasPinned) {
                                                    console.log("Dock'tan kaldırılıyor: " + appIdToDelete);
                                                    dockWindow.unpinApp(appIdToDelete);
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
                                            dockWindow.logToFile(logMsg);

                                            if (modelData.isRunning && modelData.windowId && modelData.windowId !== -1) {
                                                // Açık pencereye odaklan
                                                dockWindow.focusWindow(modelData.windowId);
                                            } else {
                                                dockWindow.launchApp(modelData.cmd);
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

                                    Rectangle {
                                        width: 140 * dockScale
                                        height: 30 * dockScale
                                        radius: 8 * dockScale
                                        color: pinUnpinMouse.containsMouse
                                            ? Qt.rgba(137/255, 180/255, 250/255, 0.18)
                                            : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.isPinned ? "  Dock'tan Kaldır" : "  Dock'a Sabitle"
                                            color: modelData.isPinned ? Theme.red : Theme.primary
                                            font.pixelSize: 12 * dockScale
                                            font.bold: true
                                            font.family: "JetBrainsMono Nerd Font"
                                        }

                                        MouseArea {
                                            id: pinUnpinMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (modelData.isPinned) {
                                                    dockWindow.unpinApp(modelData.appId);
                                                } else {
                                                    dockWindow.pinApp(modelData.appId);
                                                }
                                                dockWindow.contextMenuVisible = false;
                                            }
                                        }
                                    }
                                    
                                    // Separator
                                    Rectangle { width: 120 * dockScale; height: 1; color: Qt.rgba(1,1,1,0.1); anchors.horizontalCenter: parent.horizontalCenter }
                                    
                                    Rectangle {
                                        width: 140 * dockScale
                                        height: 30 * dockScale
                                        radius: 8 * dockScale
                                        color: closeAppMouse.containsMouse ? Qt.rgba(137/255, 180/255, 250/255, 0.18) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "  Uygulamayı Kapat"
                                            color: Theme.text
                                            font.pixelSize: 12 * dockScale
                                        }
                                        MouseArea {
                                            id: closeAppMouse
                                            anchors.fill: parent; hoverEnabled: true
                                            onClicked: {
                                                if (modelData.isRunning && modelData.windowId) {
                                                    if (S.CompositorService.isHyprland) {
                                                        launchProc.running = false;
                                                        launchProc.command = ["hyprctl", "dispatch", "closewindow", "address:" + modelData.windowId];
                                                        launchProc.running = true;
                                                    } else {
                                                        launchProc.running = false;
                                                        launchProc.command = ["niri", "msg", "action", "close-window", "--id", "" + modelData.windowId];
                                                        launchProc.running = true;
                                                    }
                                                }
                                                console.log("Close app requested: " + modelData.appId);
                                                dockWindow.contextMenuVisible = false;
                                            }
                                        }
                                    }

                                    // Separator
                                    Rectangle { width: 120 * dockScale; height: 1; color: Qt.rgba(1,1,1,0.1); anchors.horizontalCenter: parent.horizontalCenter }
                                    
                                    Rectangle {
                                        width: 140 * dockScale
                                        height: 30 * dockScale
                                        radius: 8 * dockScale
                                        color: settingsMouseArea.containsMouse ? Qt.rgba(137/255, 180/255, 250/255, 0.18) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "  Dock Ayarları"
                                            color: Theme.text
                                            font.pixelSize: 12 * dockScale
                                        }
                                        MouseArea {
                                            id: settingsMouseArea
                                            anchors.fill: parent; hoverEnabled: true
                                            onClicked: {
                                                settingsMenu.currentPage = "dock";
                                                settingsMenu.visible = true;
                                                dockWindow.contextMenuVisible = false;
                                            }
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
