import QtQuick
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../Widgets"
import "../System" as Sys

PanelWindow {
    id: settingsPopup
    visible: false
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    signal configSaved(var newConfig)


    function closeSettings() {
        settingsPopup.visible = false;
    }

    property var barConfig: ({ left: [], center: [], right: [] })
    property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/bar_config.json"
    property string dockConfigPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/dock_config.json"
    
    // Dock modüllerini saklamak için
    property var dockModulesList: []

    // Aktif sayfa
    property string currentPage: "bar"

    // Sürükleme durumu
    property string dragSourceGroup: ""
    property int dragSourceIndex: -1
    property string dragModuleName: ""

    // Modül bilgileri
    readonly property var moduleInfo: ({
        "Launcher": { icon: "\ue7e6", label: "Launcher", color: "#1e66f5" },
        "Temp": { icon: "󰔏", label: "Temperature", color: "#f9e2af" },
        "GPU": { icon: "󰍛", label: "GPU", color: "#a6e3a1" },
        "Disk": { icon: "󰋊", label: "Disk", color: "#89b4fa" },
        "Calendar": { icon: "", label: "Calendar", color: "#f5c2e7" },
        "Notepad": { icon: "󰠮", label: "Notepad", color: "#f9e2af" },
        "Workspaces": { icon: "", label: "Workspaces", color: "#cba6f7" },
        "Notifications": { icon: "󰂚", label: "Notifications", color: "#fab387" },
        "Weather": { icon: "󰖕", label: "Weather", color: "#f9e2af" },
        "Volume": { icon: "󰕾", label: "Volume", color: "#89b4fa" },
        "VolumeX": { icon: "󰍬", label: "Microphone", color: "#94e2d5" },
        "Tray": { icon: "󰇚", label: "Tray", color: "#a6adc8" },
        "Clipboard": { icon: "󰅍", label: "Clipboard", color: "#fab387" },
        "Power": { icon: "⏻", label: "Power", color: "#f38ba8" },

        "Battery": { icon: "󰁹", label: "Battery", color: "#a6e3a1" },
        "PowerProfile": { icon: "󰾅", label: "Power Profile", color: "#cba6f7" },
        "PowerGroup": { icon: "", label: "Power Group", color: "#a6e3a1" },
        "SysInfoGroup": { icon: "", label: "System Group", color: "#f9e2af" },
        "Clock": { icon: "", label: "Clock", color: "#f5c2e7" },
        "SysInfo": { icon: "", label: "System Info", color: "#89b4fa" }
    })

    // Bilinen tüm modül adları
    readonly property var allModuleNames: [
        "Launcher", "Temp", "GPU", "Disk", "Calendar", "Notepad",
        "Workspaces", "Notifications", "Weather", "Volume", "VolumeX",
        "Tray", "Clipboard", "Power", "Battery", "PowerProfile",
        "PowerGroup", "SysInfoGroup", "Clock", "SysInfo"
    ]

    // Sidebar menü kategorileri
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
                { key: "layout",     icon: "󰕰", label: "Layout Presets" },
                { key: "materialyou",icon: "󰏘", label: "Material You" }
            ]
        },
        {
            title: "FEATURES",
            items: [
                { key: "workspaces", icon: "󰖲", label: "Workspaces" },
                { key: "notifications", icon: "󰂚", label: "Notifications" },
                { key: "weather",    icon: "󰖕", label: "Weather" }
            ]
        },
        {
            title: "HARDWARE",
            items: [
                { key: "monitors",   icon: "󰍹", label: "Monitors" },
                { key: "screens",    icon: "󰹑", label: "Screen Prefs" },
                { key: "sound",      icon: "󰕾", label: "Sound" },
                { key: "network",    icon: "󰤨", label: "Network" }
            ]
        }
    ]



    // Config okuma
    Process {
        id: readProc
        command: ["cat", settingsPopup.configPath]
        property string output: ""
        stdout: SplitParser {
            onRead: data => { readProc.output += data; }
        }
        onExited: {
            try {
                var cfg = JSON.parse(readProc.output);
                if (!cfg.left) cfg.left = [];
                if (!cfg.center) cfg.center = [];
                if (!cfg.right) cfg.right = [];
                if (!cfg.inactive) cfg.inactive = [];

                // Dock'ta olanları inactive listesinden temizle
                var cleanInactive = [];
                for (var k = 0; k < cfg.inactive.length; k++) {
                    if (settingsPopup.dockModulesList.indexOf(cfg.inactive[k]) === -1) {
                        cleanInactive.push(cfg.inactive[k]);
                    }
                }
                cfg.inactive = cleanInactive;

                // Aktif modülleri topla (Bar + Dock)
                var activeModules = cfg.left.concat(cfg.center).concat(cfg.right).concat(cfg.inactive);
                
                // Dock modüllerini de aktif say (böylece pasif listesinde çıkmazlar)
                for (var j = 0; j < settingsPopup.dockModulesList.length; j++) {
                     activeModules.push(settingsPopup.dockModulesList[j]);
                }

                // Eksik modülleri inactive'e ekle
                for (var i = 0; i < settingsPopup.allModuleNames.length; i++) {
                    var mName = settingsPopup.allModuleNames[i];
                    if (activeModules.indexOf(mName) === -1) {
                        cfg.inactive.push(mName);
                    }
                }

                settingsPopup.barConfig = cfg;
                leftModel.clear(); centerModel.clear(); rightModel.clear(); inactiveModel.clear();
                for (var i = 0; i < cfg.left.length; i++) leftModel.append({name: cfg.left[i]});
                for (var i = 0; i < cfg.center.length; i++) centerModel.append({name: cfg.center[i]});
                for (var i = 0; i < cfg.right.length; i++) rightModel.append({name: cfg.right[i]});
                for (var i = 0; i < cfg.inactive.length; i++) inactiveModel.append({name: cfg.inactive[i]});
            } catch(e) { console.log("Config okuma hatası: " + e); }
            readProc.output = "";
        }
    }

    // Dock Config okuma
    Process {
        id: readDockProc
        command: ["cat", settingsPopup.dockConfigPath]
        property string output: ""
        stdout: SplitParser {
            onRead: data => { readDockProc.output += data; }
        }
        onExited: {
            try {
                var cfg = JSON.parse(readDockProc.output);
                dockModel.clear();
                var tempDockList = [];
                if (cfg.modules) {
                    for (var i = 0; i < cfg.modules.length; i++) {
                        dockModel.append({name: cfg.modules[i]});
                        tempDockList.push(cfg.modules[i]);
                    }
                }
                
                settingsPopup.dockModulesList = tempDockList;
                console.log("Settings.qml: Loaded dock modules: " + JSON.stringify(settingsPopup.dockModulesList));

            } catch(e) { console.log("Dock Config okuma hatası: " + e); }
            readDockProc.output = "";
            
            // Dock okunduktan sonra Bar config'i oku (zincirleme)
            readProc.output = "";
            readProc.running = false;
            readProc.running = true;
        }
    }

    // Config yazma
    Process {
        id: writeProc
        property string jsonData: ""
        command: ["bash", "-c", "cat > " + settingsPopup.configPath + " << 'ENDOFJSON'\n" + jsonData + "\nENDOFJSON"]
    }

    // Dock Config yazma
    Process {
        id: writeDockProc
        property string jsonData: ""
        command: ["bash", "-c", "cat > " + settingsPopup.dockConfigPath + " << 'ENDOFJSON'\n" + jsonData + "\nENDOFJSON"]
    }

    function loadConfig() {
        readDockProc.output = "";
        readDockProc.running = false;
        readDockProc.running = true;
        
        // readProc artık readDockProc bitince çağrılıyor (zincirleme)
        // readProc.output = "";
        // readProc.running = false;
        // readProc.running = true;
    }

    function saveConfig() {
        // Clone existing config to preserve other keys (e.g. workspaces)
        var cfg = JSON.parse(JSON.stringify(settingsPopup.barConfig));
        
        cfg.left = [];
        cfg.center = [];
        cfg.right = [];
        cfg.inactive = [];

        for (var i = 0; i < leftModel.count; i++) cfg.left.push(leftModel.get(i).name);
        for (var i = 0; i < centerModel.count; i++) cfg.center.push(centerModel.get(i).name);
        for (var i = 0; i < rightModel.count; i++) cfg.right.push(rightModel.get(i).name);
        for (var i = 0; i < inactiveModel.count; i++) cfg.inactive.push(inactiveModel.get(i).name);
        
        console.log("Settings.qml: Saving config to " + settingsPopup.configPath);
        console.log("Settings.qml: Content: " + JSON.stringify(cfg));

        writeProc.jsonData = JSON.stringify(cfg, null, 2);
        writeProc.running = false;
        writeProc.running = true;
        
        settingsPopup.barConfig = cfg;
        settingsPopup.barConfig = cfg;
        settingsPopup.configSaved(cfg);

        // Save Dock Config
        // We need to read the existing dock config first to preserve other keys, but for now we can mistakenly overwrite if we are not careful.
        // Better strategy: We can't easily read-then-write in one sync function without callbacks or blocking.
        // For now, let's just read what we have in memory if we had a proper object.
        // Since we only have the model, we should probably read the file again or assume we have the full config somewhere?
        // Simplest: Just use `cat` to read, then write back with modified modules.
        // But `saveConfig` is called void.
        // Let's use a chain: Read existing -> Modify 'modules' -> Write back.
        // Or simpler: We know `dock_config.json` structure.
        
        // Let's trigger a read-modify-write specifically for dock config.
        saveDockConfigChain.running = true;
    }

    Process {
        id: saveDockConfigChain
        command: ["cat", settingsPopup.dockConfigPath]
        property string output: ""
        stdout: SplitParser { onRead: data => saveDockConfigChain.output += data }
        onExited: {
            try {
                var outputStr = saveDockConfigChain.output.trim();
                var cfg = {
                    showBackground: true,
                    dockScale: 1.0,
                    autoHide: false,
                    pinned: [],
                    modules: []
                };
                if (outputStr !== "") {
                    try {
                        var parsed = JSON.parse(outputStr);
                        if (parsed) {
                            cfg = parsed;
                        }
                    } catch(jsonErr) {
                        console.log("saveDockConfigChain JSON error: " + jsonErr);
                    }
                }
                
                cfg.modules = [];
                for (var i = 0; i < dockModel.count; i++) cfg.modules.push(dockModel.get(i).name);
                
                var newJson = JSON.stringify(cfg, null, 2);
                writeDockProc.jsonData = newJson;
                writeDockProc.running = false;
                writeDockProc.running = true;
            } catch(e) { console.log("Dock Config save logic error: " + e); }
            saveDockConfigChain.output = "";
        }
    }



    function getModelByName(groupName) {
        if (groupName === "left") return leftModel;
        if (groupName === "center") return centerModel;
        if (groupName === "right") return rightModel;
        if (groupName === "inactive") return inactiveModel;
        if (groupName === "dock") return dockModel;
        return null;
    }

    function handleDrop(targetGroup, targetIndex) {
        if (dragSourceGroup === "" || dragModuleName === "") return;
        var srcModel = getModelByName(dragSourceGroup);
        var dstModel = getModelByName(targetGroup);
        if (!srcModel || !dstModel) return;

        if (dragSourceGroup === targetGroup) {
            if (dragSourceIndex !== targetIndex && targetIndex >= 0 && targetIndex < srcModel.count) {
                srcModel.move(dragSourceIndex, targetIndex, 1);
            }
        } else {
            var name = dragModuleName;
            srcModel.remove(dragSourceIndex);
            if (targetIndex >= 0 && targetIndex <= dstModel.count) {
                dstModel.insert(targetIndex, {name: name});
            } else {
                dstModel.append({name: name});
            }
        }
        dragSourceGroup = "";
        dragSourceIndex = -1;
        dragModuleName = "";
    }

    ListModel { id: leftModel }
    ListModel { id: centerModel }
    ListModel { id: rightModel }
    ListModel { id: inactiveModel }
    ListModel { id: dockModel }

    onVisibleChanged: {
        if (visible) loadConfig();
    }

    // ── Background dim + click-to-close ──
    Rectangle {
        id: bgDim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: settingsPopup.closeSettings()
        }
    }

    // ── Floating Settings Window ──
    Rectangle {
        id: settingsContent
        width: 1000
        height: 700
        
        // Ekranın ortasında başla
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        color: Theme.background
        border.color: Theme.surface
        border.width: 1
        radius: Theme.radius
        clip: true

        property real minW: 700
        property real minH: 450
        property bool resizing: false

        // Resize sırasında layout animasyonlarını kapat
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
                // Use workspace color (surface variant) for sidebar background to adapt to Light/Dark mode
                color: Qt.rgba(Theme.workspacesColor.r, Theme.workspacesColor.g, Theme.workspacesColor.b, 0.4)
                radius: Theme.radius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    // Başlık (drag handle) — sürüklenebilir
                    Item {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 12
                        height: 30

                        // Drag handler - başlık alanından pencereyi sürükle
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
                                text: "⚙"
                                font.pixelSize: 18
                                color: Theme.primary
                            }
                            Text {
                                text: "Settings"
                                color: Theme.text
                                font.pixelSize: 16
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 24; height: 24; radius: 12
                                color: closeMA.containsMouse ? Theme.red : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: "✕"; color: Theme.text; font.pixelSize: 11 }
                                MouseArea {
                                    id: closeMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsPopup.closeSettings()
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.06) }
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

                            // Menü kategorileri
                            Repeater {
                                model: settingsPopup.menuCategories

                                ColumnLayout {
                                    id: categoryColumn
                                    Layout.fillWidth: true
                                    spacing: 4
                                    property bool isExpanded: true

                                    // Kategori Başlığı (Tıklanabilir)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        color: headerMA.containsMouse ? Qt.rgba(255,255,255,0.05) : "transparent"
                                        radius: 6

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Text {
                                                text: categoryColumn.isExpanded ? "󰅔" : "󰅂" // Keyboard arrow down/right
                                                color: headerMA.containsMouse ? Theme.text : Theme.overlay
                                                font.pixelSize: 14
                                                font.family: "JetBrainsMono Nerd Font"
                                            }

                                            Text {
                                                text: modelData.title
                                                color: headerMA.containsMouse ? Theme.text : Theme.overlay
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

                                    // Kategori öğeleri
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
                                                    if (settingsPopup.currentPage === modelData.key) return Qt.rgba(137/255, 180/255, 250/255, 0.15);
                                                    if (menuMA.containsMouse) return Qt.rgba(255,255,255,0.05);
                                                    return "transparent";
                                                }
                                                Behavior on color { ColorAnimation { duration: settingsContent.resizing ? 0 : 120 } }

                                                // Sol accent çizgisi
                                                Rectangle {
                                                    visible: settingsPopup.currentPage === modelData.key
                                                    width: 3; height: 18; radius: 2
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: Theme.primary
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
                                                        color: settingsPopup.currentPage === modelData.key ? Theme.primary : Theme.subtext
                                                    }

                                                    Text {
                                                        text: modelData.label
                                                        color: settingsPopup.currentPage === modelData.key ? Theme.text : Theme.subtext
                                                        font.pixelSize: 13
                                                        font.bold: settingsPopup.currentPage === modelData.key
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                MouseArea {
                                                    id: menuMA
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsPopup.currentPage = modelData.key
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Item { height: 16 } // Alt boşluk
                        }
                    }
                }
            }

            // Ayırıcı
            Rectangle { width: 1; Layout.fillHeight: true; color: Qt.rgba(255,255,255,0.06) }

            // ═══ İÇERİK ═══
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ── BAR AYARLARI ──
                Item {
                    anchors.fill: parent
                    anchors.margins: 16
                    visible: settingsPopup.currentPage === "bar"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        // Başlık
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󰒍"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                            Text { text: "Bar Settings"; font.bold: true; font.pixelSize: 18; color: Theme.text }
                        }

                        Item { height: 4 }



                        Text {
                            text: "Drag and drop modules to reorder"
                            color: Theme.overlay2
                            font.pixelSize: 11
                        }

                        // 3 Aktif Sütun
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            DropGroup {
                                groupName: "left"
                                title: "◀ Left"
                                groupModel: leftModel
                                groupColor: "#a6e3a1"
                            }

                            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.surface }

                            DropGroup {
                                groupName: "center"
                                title: "● Center"
                                groupModel: centerModel
                                groupColor: "#cba6f7"
                            }

                            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.surface }

                            DropGroup {
                                groupName: "right"
                                title: "▶ Right"
                                groupModel: rightModel
                                groupColor: "#89b4fa"
                            }

                            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.surface }

                            // Kullanılmayan modüller
                            DropGroup {
                                groupName: "inactive"
                                title: "⊘ Inactive"
                                groupModel: inactiveModel
                                groupColor: "#6c7086"
                            }

                            Rectangle { width: 1; Layout.fillHeight: true; color: Theme.surface }

                            // Dock Modülleri
                            DropGroup {
                                groupName: "dock"
                                title: "⚓ Dock"
                                groupModel: dockModel
                                groupColor: "#fab387"
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surface }

                        // Kaydet butonu
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Drag modules to move"; color: Theme.overlay; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 140; height: 38; radius: 10
                                color: saveMA.containsMouse ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: "💾  Save"; color: "#1e1e2e"; font.pixelSize: 14; font.bold: true }
                                MouseArea {
                                    id: saveMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { saveConfig(); settingsPopup.closeSettings(); }
                                }
                            }
                        }
                    }
                }

                // ── WORKSPACES SAYFASI ──
                WorkspacesPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "workspaces"
                    settingsPopup: settingsPopup
                }

                // ── NOTIFICATIONS SAYFASI ──
                NotificationsPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "notifications"
                    settingsPopup: settingsPopup
                }

                // ── DOCK SAYFASI ──
                DockPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "dock"
                    settingsPopup: settingsPopup
                }

                // ── SİSTEM SAYFALARI ──
                Sys.SystemInfoPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "sysinfo"
                }

                Sys.DiskPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "disks"
                }

                Sys.WeatherPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "weather"
                }

                Sys.MonitorsPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "monitors"
                }

                Sys.SoundPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "sound"
                }

                Sys.NetworkPage {
                    id: networkPage
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "network"
                    z: visible ? 100 : 0
                }

                // ── LAYOUT PRESETS ──
                LayoutPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "layout"
                    z: visible ? 100 : 0
                    onPresetApplied: {
                        loadConfig();
                    }
                }



                // ── SCREEN PREFERENCES ──
                ScreensPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "screens"
                    z: visible ? 100 : 0
                }



                // ── MATERIAL YOU ──
                MaterialYouPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "materialyou"
                    z: visible ? 100 : 0
                }

                // ── ABOUT ──
                AboutPage {
                    anchors.fill: parent
                    visible: settingsPopup.currentPage === "about"
                    z: visible ? 100 : 0
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

    // ═══ SÜRÜKLE-BIRAK GRUP BİLEŞENİ ═══
    component DropGroup : ColumnLayout {
        property string groupName
        property string title
        property ListModel groupModel
        property color groupColor

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        Text {
            text: title
            color: groupColor
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: groupDropArea.containsDrag ? Qt.rgba(groupColor.r, groupColor.g, groupColor.b, 0.1) : "transparent"
            border.color: groupDropArea.containsDrag ? Qt.rgba(groupColor.r, groupColor.g, groupColor.b, 0.3) : "transparent"
            border.width: 2

            Behavior on color { ColorAnimation { duration: 200 } }

            DropArea {
                id: groupDropArea
                anchors.fill: parent
                onDropped: { settingsPopup.handleDrop(groupName, groupModel.count); }
            }

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 4
                model: groupModel
                spacing: 4
                clip: true

                delegate: Item {
                    id: delegateRoot
                    width: listView.width
                    height: 48

                    property var info: settingsPopup.moduleInfo[model.name] || { icon: "?", label: model.name, color: "#cdd6f4" }

                    DropArea {
                        anchors.fill: parent
                        onDropped: { settingsPopup.handleDrop(groupName, index); }
                    }

                    Rectangle {
                        id: dragRect
                        width: delegateRoot.width
                        height: delegateRoot.height
                        radius: 10
                        color: dragMA.containsMouse
                            ? Qt.rgba(49/255, 50/255, 68/255, 0.9)
                            : Qt.rgba(49/255, 50/255, 68/255, 0.4)
                        border.color: dragMA.drag.active ? groupColor : "transparent"
                        border.width: dragMA.drag.active ? 2 : 0

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Drag.active: dragMA.drag.active
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2

                        states: State {
                            when: dragMA.drag.active
                            ParentChange { target: dragRect; parent: settingsContent }
                            AnchorChanges {
                                target: dragRect
                                anchors.left: undefined
                                anchors.right: undefined
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text { text: "⠿"; color: Theme.overlay; font.pixelSize: 16 }
                            Text { text: info.icon; color: info.color; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                            Text { text: info.label; color: Theme.text; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        }

                        MouseArea {
                            id: dragMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            drag.target: dragRect

                            onPressed: {
                                settingsPopup.dragSourceGroup = groupName;
                                settingsPopup.dragSourceIndex = index;
                                settingsPopup.dragModuleName = model.name;
                            }

                            onReleased: {
                                dragRect.Drag.drop();
                                dragRect.x = 0;
                                dragRect.y = 0;
                                if (dragRect.parent !== delegateRoot) {
                                    dragRect.parent = delegateRoot;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
