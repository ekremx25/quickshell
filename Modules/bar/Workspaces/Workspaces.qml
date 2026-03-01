import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../Widgets"
import "../../../Services"

Rectangle {
    id: workspaceRoot
    required property string monitorName
    property var tagIconCache: ({})
    property var config: ({ format: "arabic", style: "fill", transparent: false, activeColor: "" })
    property string style: config.style || "fill"
    property bool isTransparent: config.transparent === true
    property color activeColor: Theme.workspacesColor

    // DMS özelliklerini bar_config.json'dan oku
    property bool showApps: config.showApps !== false
    property bool groupApps: config.groupApps !== false
    property bool scrollEnabled: config.scrollEnabled !== false
    property int iconSize: config.iconSize || 20
    
    // Mouse scroll biriktirici
    property real mouseAccumulator: 0
    property bool scrollInProgress: false
    
    Timer {
        id: scrollCooldown
        interval: 100
        onTriggered: workspaceRoot.scrollInProgress = false
    }

    // Ana arka plan şeffaf, sadece içindeki kutucuklar görünecek
    color: "transparent"
    border.width: 0

    implicitHeight: 34
    implicitWidth: wsRow.implicitWidth

    // --- FORMAT ÇEVİRİCİ ---
    function getWorkspaceLabel(numStr) {
        var fmt = config.format || "chinese";
        
        if (fmt === "roman") {
            var romans = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"];
            var n = parseInt(numStr);
            if (!isNaN(n) && n >= 1 && n <= 10) return romans[n];
            return numStr;
        } 
        
        if (fmt === "chinese") {
            var map = {
                "1": "一", "2": "二", "3": "三", "4": "四", "5": "五",
                "6": "六", "7": "七", "8": "八", "9": "九", "10": "十"
            };
            return map[numStr] || numStr;
        }

        // Arabic (Default fallback)
        return numStr;
    }

    // --- DEV İKON KÜTÜPHANESİ ---
    function getIcon(appId, title) {
        if (!appId) appId = "";
        if (!title) title = "";
        var c = appId.toLowerCase();
        var t = title.toLowerCase();

        // 1. TITLE (Başlık) Eşleştirmeleri
        if (t.includes("amazon")) return " ";
        if (t.includes("reddit")) return " ";
        if (t.includes("gmail")) return "󰊫 ";
        if (t.includes("whatsapp")) return " ";
        if (t.includes("zapzap")) return " ";
        if (t.includes("messenger")) return " ";
        if (t.includes("facebook")) return " ";
        if (t.match(/chatgpt|deepseek|qwen/)) return "󰚩 ";
        if (t.includes("picture-in-picture")) return " ";
        if (t.includes("youtube")) return " ";
        if (t.includes("cmus")) return " ";
        if (t.includes("virtualbox")) return "💽 ";
        if (t.includes("github")) return " ";
        if (t.match(/nvim ~|vim|nvim/)) return " ";
        if (t.includes("figma")) return " ";
        if (t.includes("jira")) return " ";
        if (t.includes("x"))return "\ueb72";
          if (t.includes("google"))return "\ue7f0";
          if (t.includes("flow"))return "\ue69f";
        // Gözden kaçan başlıklar için garanti kontrol
        if (t.includes("dolphin")) return "󰝰 ";
        if (t.includes("kwrite")) return " ";

        // 2. CLASS (Uygulama Kimliği) Eşleştirmeleri
        if (c.match(/firefox|org\.mozilla\.firefox|librewolf|floorp|mercury-browser|cachy-browser/)) return " ";
        if (c.match(/zen/)) return "󰰷 ";
        if (c.match(/waterfox|waterfox-bin/)) return " ";
        if (c.match(/microsoft-edge/)) return " ";
        if (c.match(/chromium|thorium|chrome/)) return " ";
        if (c.match(/brave-browser/)) return "🦁 ";
        if (c.match(/tor browser/)) return " ";
        if (c.match(/firefox-developer-edition/)) return "🦊 ";

        if (c.match(/kitty|konsole/)) return " ";
        if (c.match(/kitty-dropterm/)) return " ";
        if (c.match(/com\.mitchellh\.ghostty/)) return "  ";
        if (c.match(/org\.wezfurlong\.wezterm/)) return "  ";

        if (c.match(/thunderbird|thunderbird-esr|eu\.betterbird\.betterbird/)) return " ";

        if (c.match(/telegram-desktop|org\.telegram\.desktop|io\.github\.tdesktop_x64\.tdesktop/)) return " ";
        if (c.match(/discord|webcord|vesktop/)) return " ";
        if (c.match(/subl/)) return "󰅳 ";
        if (c.match(/slack/)) return " ";

        if (c.match(/mpv/)) return " ";
        if (c.match(/celluloid|zoom/)) return " ";
        if (c.match(/cider/)) return "󰎆 ";
        if (c.match(/vlc/)) return "󰕼 ";
        if (c.match(/spotify/)) return " ";

        if (c.match(/virt-manager|\.virt-manager-wrapped/)) return " ";
        if (c.match(/virtualbox manager/)) return "💽 ";
        if (c.match(/remmina/)) return "🖥️ ";

        if (c.match(/vscode|code-url-handler|code-oss|codium|codium-url-handler|vscodium/)) return "󰨞 ";
        if (c.match(/dev\.zed\.zed/)) return "󰵁 ";
        if (c.match(/codeblocks/)) return "󰅩 ";
        if (c.match(/mousepad/)) return " ";

        if (c.match(/libreoffice-writer/)) return " ";
        if (c.match(/libreoffice-startcenter/)) return "󰏆 ";
        if (c.match(/libreoffice-calc/)) return " ";
        if (c.match(/jetbrains-idea/)) return " ";

        if (c.match(/obs|com\.obsproject\.studio/)) return " ";
        if (c.match(/polkit-gnome-authentication-agent-1/)) return "󰒃 ";
        if (c.match(/nwg-look/)) return " ";
        if (c.match(/pavucontrol|org\.pulseaudio\.pavucontrol/)) return "󱡫 ";
        if (c.match(/steam/)) return " ";

        // Dolphin ve Kwrite burada tam isabet yakalanacak
        if (c.match(/thunar|nemo|dolphin/)) return "󰝰 ";
        if (c.match(/kwrite/)) return " ";

        if (c.match(/gparted/)) return " ";
        if (c.match(/gimp/)) return " ";
        if (c.match(/emulator/)) return "📱 ";
        if (c.match(/android-studio/)) return " ";
        if (c.match(/org\.pipewire\.helvum/)) return "󰓃 ";
        if (c.match(/localsend/)) return " ";
        if (c.match(/prusaslicer|ultimaker-cura|orcaslicer/)) return "󰹛 ";

        return " "; // Hiçbiri eşleşmezse
    }

    // --- NİRİ ÇALIŞMA ALANI VERİLERİ ---
    property var activeWorkspaces: []
    property var monWsIds: []
    property var monWsMap: {}
    property string lastStateHash: ""

    Process { id: focusProc; command: [] }

    function switchToWorkspace(targetName) {
        if (CompositorService.isHyprland) {
            focusProc.command = ["hyprctl", "dispatch", "workspace", String(targetName)];
            focusProc.running = true;
        } else if (CompositorService.isNiri) {
            focusProc.command = ["niri", "msg", "action", "focus-workspace", String(targetName)];
            focusProc.running = true;
        } else if (CompositorService.isMango) {
            focusProc.command = ["mmsg", "-s", "-o", monitorName, "-t", String(targetName)];
            focusProc.running = true;
        }
    }

    function scrollWorkspaces(direction) {
        if (!workspaceRoot.scrollEnabled) return;
        var wss = workspaceRoot.activeWorkspaces.filter(w => !isNaN(parseInt(w.name)));
        if (wss.length < 2) return;
        
        var currentIndex = wss.findIndex(w => w.is_active);
        var validIndex = currentIndex === -1 ? 0 : currentIndex;
        // Direction pozitifse sağa (sonraki), negatifse sola (önceki)
        var nextIndex = direction > 0 ? Math.min(validIndex + 1, wss.length - 1) : Math.max(validIndex - 1, 0);
        
        if (nextIndex !== validIndex) {
            switchToWorkspace(wss[nextIndex].name);
        }
    }

    Process {
        id: wsProc
        command: CompositorService.isHyprland ? ["hyprctl", "workspaces", "-j"] : (CompositorService.isMango ? ["mmsg", "-g", "-t"] : ["niri", "msg", "-j", "workspaces"])
        property string outputBuffer: ""
        stdout: SplitParser { onRead: (data) => wsProc.outputBuffer += data + "\n" }
        onExited: {
            if (wsProc.outputBuffer.trim() === "") return;
            try {
                if (CompositorService.isMango) {
                    // mmsg -g -t çıktı formatı (dwl IPC):
                    // DP-2 tag 1 1 2 1   ← monitor tag_num state clients focused
                    // DP-2 clients 5
                    // DP-2 tags 7 2 0
                    var lines = wsProc.outputBuffer.trim().split("\n");
                    var mWsIds = [];
                    var mWsMap = {};
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim();
                        if (line === "") continue;
                        var parts = line.split(/\s+/);
                        if (parts.length < 2) continue;

                        var lineMon = parts[0];
                        // Bu monitöre ait olmayan satırları atla
                        if (lineMon !== monitorName) continue;

                        // "DP-2 tag 1 1 2 1" formatı
                        if (parts[1] === "tag" && parts.length >= 6) {
                            var tagNum = parseInt(parts[2]);
                            var state = parseInt(parts[3]);
                            // State: 0=none, 1=active, 2=urgent
                            if (!isNaN(tagNum)) {
                                mWsIds.push(tagNum);
                                mWsMap[tagNum] = {
                                    id: tagNum,
                                    idx: tagNum,
                                    name: String(tagNum),
                                    is_active: state === 1,
                                    clients: parseInt(parts[4]) || 0,
                                    focused: parseInt(parts[5]) || 0
                                };
                            }
                        }
                        // "clients" ve "tags" satırlarını atlıyoruz, per-tag yeterli
                    }
                    mWsIds.sort((a, b) => a - b);
                    workspaceRoot.monWsIds = mWsIds;
                    workspaceRoot.monWsMap = mWsMap;

                    // ToplevelManager üzerinden bu monitördeki tüm pencereleri bul
                    var monitorWindows = [];
                    var toplevels = ToplevelManager.toplevels;
                    var tlValues = toplevels.values || [];
                    for (var ti = 0; ti < tlValues.length; ti++) {
                        var tl = tlValues[ti];
                        var onThisScreen = false;
                        if (tl.screens) {
                            for (var si = 0; si < tl.screens.length; si++) {
                                if (tl.screens[si].name === monitorName) {
                                    onThisScreen = true;
                                    break;
                                }
                            }
                        }
                        if (onThisScreen) {
                            monitorWindows.push({
                                app_id: tl.appId || "",
                                title: tl.title || "",
                                is_active: tl.activated || false
                            });
                        }
                    }

                    // Sonuç listesini oluştur
                    var result = [];
                    var existingNames = [];
                    for (var j = 0; j < mWsIds.length; j++) {
                        var id = mWsIds[j];
                        var ws = mWsMap[id];
                        ws.windows = [];
                        ws.groupedWindows = [];
                        ws.winCount = ws.clients || 0;

                        if (ws.is_active && monitorWindows.length > 0) {
                            // Aktif tag: ws.clients sayısı kadar pencere göster (mmsg'den gelen doğru sayı)
                            var tagClientCount = ws.clients || 0;
                            // Aktif (odaklanmış) pencereyi öne al
                            var sorted = monitorWindows.slice().sort(function(a, b) { return (b.is_active ? 1 : 0) - (a.is_active ? 1 : 0); });
                            // mmsg'nin bildirdiği client sayısı kadar pencere al
                            var visibleWindows = tagClientCount > 0 ? sorted.slice(0, tagClientCount) : sorted;
                            // Aktif tag: ToplevelManager'dan pencereleri al ve önbelleğe kaydet
                            var grps = {};
                            for (var wi = 0; wi < visibleWindows.length; wi++) {
                                var w = visibleWindows[wi];
                                var appKey = w.app_id || w.title || "unknown";
                                var icon = getIcon(w.app_id, w.title);
                                ws.windows.push(w);
                                if (!grps[appKey]) {
                                    grps[appKey] = { icon: icon, active: w.is_active, count: 1 };
                                } else {
                                    grps[appKey].count++;
                                    if (w.is_active) grps[appKey].active = true;
                                }
                            }
                            var groupedArr = [];
                            for (var g in grps) {
                                if (!workspaceRoot.groupApps || ws.is_active) {
                                    for (var gi = 0; gi < grps[g].count; gi++) {
                                        groupedArr.push({ icon: grps[g].icon, active: grps[g].active });
                                    }
                                } else {
                                    groupedArr.push(grps[g]);
                                }
                            }
                            ws.groupedWindows = groupedArr;
                            // Önbelleğe kaydet
                            var cache = workspaceRoot.tagIconCache;
                            cache[id] = { windows: ws.windows, groupedWindows: ws.groupedWindows };
                            workspaceRoot.tagIconCache = cache;
                        } else if (ws.winCount > 0 && workspaceRoot.tagIconCache[id]) {
                            // İnaktif tag: önbellekten yükle
                            var cached = workspaceRoot.tagIconCache[id];
                            ws.windows = cached.windows;
                            ws.groupedWindows = cached.groupedWindows;
                        }

                        result.push(ws);
                        existingNames.push(String(ws.name));
                    }
                    // Boş da olsa ilk 9 tag'ı her zaman göster
                    for (var k = 1; k <= 9; k++) {
                        var strK = String(k);
                        if (existingNames.indexOf(strK) === -1) {
                            result.push({ id: strK, idx: k, name: strK, is_active: false, winCount: 0, clients: 0, windows: [], groupedWindows: [] });
                        }
                    }
                    result.sort(function(a, b) {
                        var numA = parseInt(a.name);
                        var numB = parseInt(b.name);
                        if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
                        return 0;
                    });
                    var currentState = JSON.stringify(result);
                    if (workspaceRoot.lastStateHash !== currentState) {
                        workspaceRoot.lastStateHash = currentState;
                        workspaceRoot.activeWorkspaces = result;
                    }
                } else {
                var allWs = JSON.parse(wsProc.outputBuffer);
                var mWsIds = [];
                var mWsMap = {};
                for (var i = 0; i < allWs.length; i++) {
                    var ws = allWs[i];
                    if (CompositorService.isHyprland) {
                        // Hyprland Logic
                        if (ws.monitor === monitorName) {
                            mWsIds.push(ws.id);
                            mWsMap[ws.id] = {
                                id: ws.id,
                                idx: ws.id,
                                name: ws.name ? ws.name : String(ws.id),
                                is_active: ws.id === activeHyprlandWorkspaceId
                            };
                        }
                    } else {
                        // Niri Logic
                        if (ws.output === monitorName) {
                            mWsIds.push(ws.id);
                            mWsMap[ws.id] = {
                                id: ws.id,
                                idx: ws.idx !== undefined ? ws.idx : (i + 1),
                                name: ws.name ? ws.name : String(ws.idx !== undefined ? ws.idx : (i + 1)),
                                is_active: ws.is_focused ?? false
                            };
                        }
                    }
                }
                mWsIds.sort((a, b) => mWsMap[a].idx - mWsMap[b].idx);
                workspaceRoot.monWsIds = mWsIds;
                workspaceRoot.monWsMap = mWsMap;
                } // end of else (Hyprland/Niri)
            } catch (e) {}
            wsProc.outputBuffer = "";
        }
    }

    property int activeHyprlandWorkspaceId: -1

    Process {
        id: activeWsProc
        command: ["hyprctl", "activeworkspace", "-j"]
        property string outputBuffer: ""
        stdout: SplitParser { onRead: (data) => activeWsProc.outputBuffer += data }
        onExited: {
            if (activeWsProc.outputBuffer.trim() === "") return;
            try {
                var o = JSON.parse(activeWsProc.outputBuffer);
                workspaceRoot.activeHyprlandWorkspaceId = o.id;
            } catch (e) {}
            activeWsProc.outputBuffer = "";
        }
    }

    Process {
        id: winProc
        command: CompositorService.isHyprland ? ["hyprctl", "clients", "-j"] : (CompositorService.isMango ? ["echo", ""] : ["niri", "msg", "-j", "windows"])
        property string outputBuffer: ""
        stdout: SplitParser { onRead: (data) => winProc.outputBuffer += data }
        onExited: {
            // Mango: wsProc.onExited içinde zaten işleniyor, burada sadece çık
            if (CompositorService.isMango) {
                winProc.outputBuffer = "";
                return;
            }
            if (winProc.outputBuffer.trim() === "") return;
            try {
                var allWindows = JSON.parse(winProc.outputBuffer);
                var wsMap = workspaceRoot.monWsMap ?? {};
                var mWsIds = workspaceRoot.monWsIds ?? [];

                for (var wsId in wsMap) {
                    wsMap[wsId].windows = [];
                    wsMap[wsId].winCount = 0;
                }

                for (var i = 0; i < allWindows.length; i++) {
                    var win = allWindows[i];
                    if (CompositorService.isHyprland) {
                        // Hyprland logic
                        if (win.workspace && mWsIds.includes(win.workspace.id)) {
                            var wId = win.workspace.id;
                            if (wsMap[wId]) {
                                var isFocused = win.focusHistoryID === 0; // Simple approximation for active hyprland client
                                wsMap[wId].windows.push({app_id: win.class, title: win.title, is_active: isFocused});
                                wsMap[wId].winCount++;
                            }
                        }
                    } else {
                        // Niri Logic
                        if (mWsIds.includes(win.workspace_id)) {
                            var wId = win.workspace_id;
                            if (wsMap[wId]) {
                                wsMap[wId].windows.push({app_id: win.app_id, title: win.title, is_active: win.is_focused});
                                wsMap[wId].winCount++;
                                if (win.is_focused) wsMap[wId].is_active = true;
                            }
                        }
                    }
                }

                // Uygulamaları gruplama işlemi
                for (var key in wsMap) {
                    var grps = {};
                    var wins = wsMap[key].windows;
                    for (var j = 0; j < wins.length; j++) {
                        var w = wins[j];
                        var appKey = w.app_id || w.title || "unknown";
                        var icon = getIcon(w.app_id, w.title);
                        if (!grps[appKey]) {
                            grps[appKey] = { icon: icon, active: w.is_active, count: 1 };
                        } else {
                            grps[appKey].count++;
                            if (w.is_active) grps[appKey].active = true;
                        }
                    }
                    var groupedArr = [];
                    for (var g in grps) {
                        // Eğer gruplama kapalıysa ve workspace aktifse, grup yerine ayrı ayrı göster
                        if (!workspaceRoot.groupApps || wsMap[key].is_active) {
                            for (var k=0; k<grps[g].count; k++) {
                                groupedArr.push({
                                    icon: grps[g].icon,
                                    active: grps[g].active
                                });
                            }
                        } else {
                            groupedArr.push(grps[g]);
                        }
                    }
                    wsMap[key].groupedWindows = groupedArr;
                }

                var result = [];
                var existingNames = [];
                for (var j = 0; j < mWsIds.length; j++) {
                    var id = mWsIds[j];
                    result.push(wsMap[id]);
                    existingNames.push(String(wsMap[id].name));
                }

                // Boş da olsa ilk 5 çalışma alanını her zaman göster
                for (var k = 1; k <= 5; k++) {
                    var strK = String(k);
                    if (existingNames.indexOf(strK) === -1) {
                        result.push({ id: strK, idx: k, name: strK, is_active: false, winCount: 0, windows: [], groupedWindows: [] });
                    }
                }

                result.sort(function(a, b) {
                    var numA = parseInt(a.name);
                    var numB = parseInt(b.name);
                    if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
                    return 0;
                });

                var currentState = JSON.stringify(result);
                if (workspaceRoot.lastStateHash !== currentState) {
                    workspaceRoot.lastStateHash = currentState;
                    workspaceRoot.activeWorkspaces = result;
                }
            } catch (e) {}
            winProc.outputBuffer = "";
        }
    }

    Timer {
        interval: 500; running: true; repeat: true;
        onTriggered: { 
            if (CompositorService.isHyprland) { activeWsProc.running = true; }
            wsProc.running = true; 
            winProc.running = true; 
        }
    }

    // Scroll Alanı
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        
        onWheel: wheel => {
            if (!workspaceRoot.scrollEnabled || scrollInProgress) return;

            var delta = wheel.angleDelta.y;
            workspaceRoot.mouseAccumulator += delta;
            if (Math.abs(workspaceRoot.mouseAccumulator) < 120) return;
            var direction = workspaceRoot.mouseAccumulator < 0 ? 1 : -1;
            workspaceRoot.scrollWorkspaces(direction);
            
            workspaceRoot.scrollInProgress = true;
            scrollCooldown.restart();
            workspaceRoot.mouseAccumulator = 0;
        }
    }

    // --- GÖRSEL DÜZEN (Şık Hap Tasarımı) ---
    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: workspaceRoot.activeWorkspaces
            delegate: Rectangle {
                id: wsBox
                property var wsData: modelData
                property bool isActive: wsData.is_active
                property int winCount: wsData.winCount

                // İçeriğe göre dinamik genişleyen boyut
                implicitWidth: wsContent.implicitWidth + 24
                height: 34
                radius: style === "square" ? 6 : 17

                // STİL MANTIĞI
                color: {
                   if (style === "fill") {
                       if (isActive) return activeColor;
                       return isTransparent ? "transparent" : Theme.surface;
                   }
                   if (style === "square" || style === "circle") {
                       return isActive ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.4) : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.2); 
                   }
                   return "transparent";
                }

                border.width: (style === "outline" || style === "square" || style === "circle") ? 2 : 0
                border.color: {
                    if (style === "outline" || style === "square" || style === "circle") return isActive ? activeColor : (isTransparent ? "transparent" : Theme.surface);
                    return "transparent";
                }

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                Row {
                    id: wsContent
                    anchors.centerIn: parent
                    spacing: 8

                    // NUMARA (Formatlı)
                    Text {
                        text: getWorkspaceLabel(wsData.name)
                        color: isActive ? Theme.workspaceActiveTextColor : Theme.text
                        font.bold: true
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // ARAYA EKLENEN İNCE ÇİZGİ (Ayırıcı)
                    Rectangle {
                        width: 1
                        height: 14
                        color: (isActive ? Theme.workspaceActiveTextColor : Theme.text) // Dinamik renk
                        opacity: 0.25
                        anchors.verticalCenter: parent.verticalCenter
                        visible: winCount > 0 && workspaceRoot.showApps
                    }

                    // UYGULAMA İKONLARI
                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: winCount > 0 && workspaceRoot.showApps

                        Repeater {
                            model: wsData.groupedWindows
                            
                            Item {
                                width: iconText.implicitWidth
                                height: workspaceRoot.iconSize + 4
                                
                                Text {
                                    id: iconText
                                    text: modelData.icon
                                    color: (isActive || modelData.active) ? (isActive ? Theme.workspaceActiveTextColor : Theme.primary) : Theme.text
                                    opacity: modelData.active ? 1.0 : (isActive ? 0.9 : 0.6)
                                    font.pixelSize: workspaceRoot.iconSize
                                    font.family: "JetBrainsMono Nerd Font"
                                    anchors.centerIn: parent
                                }
                                
                                // Gruplama balonu (ör: 2 tane aynı app varsa)
                                Rectangle {
                                    visible: (modelData.count !== undefined && modelData.count > 1) && !isActive
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: Theme.surface
                                    border.color: Theme.text
                                    border.width: 1
                                    anchors.right: parent.right
                                    anchors.rightMargin: -6
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -2
                                    z: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.count !== undefined ? String(modelData.count) : ""
                                        font.pixelSize: 8
                                        color: Theme.text
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                // ALT ÇİZGİ (Underline Stili)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.6
                    height: 3
                    radius: 1.5
                    color: activeColor
                    visible: style === "underline" && isActive
                }

                // NOKTA (Dot Stili)
                Rectangle {
                    anchors.top: parent.bottom
                    anchors.topMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 4
                    height: 4
                    radius: 2
                    color: activeColor
                    visible: style === "dot" && isActive
                }

                // ÜST ÇİZGİ (Overline Stili)
                Rectangle {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.6
                    height: 3
                    radius: 1.5
                    color: activeColor
                    visible: style === "overline" && isActive
                }

                // YAN ÇİZGİ (Pipe Stili)
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    width: 3
                    height: parent.height * 0.6
                    radius: 1.5
                    color: activeColor
                    visible: style === "pipe" && isActive
                }

                // Tıklama Alanı
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: workspaceRoot.switchToWorkspace(wsData.name)
                }
            }
        }
    }
}
