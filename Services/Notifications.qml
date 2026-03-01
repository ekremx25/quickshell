pragma Singleton
import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io

Singleton {
    id: root

    // Bildirim Listesi
    property var notifications: []
    property var activeNotifications: []
    
    // PENCERE KONTROLÜ
    property bool historyVisible: false
    function toggleHistory() { historyVisible = !historyVisible }

    // Display Duration (ms)
    property int displayDuration: 5000

    // DO NOT DISTURB
    property bool dnd: false
    
    // NEW ADVANCED SETTINGS
    property int popupPosition: 1 // 1: Top Right, 2: Top Left, 3: Top Center, 4: Bottom Center, 5: Bottom Right, 6: Bottom Left
    property bool overlayEnabled: false
    property bool compactMode: false
    property bool popupShadowEnabled: true
    property bool privacyMode: false
    property int animationSpeed: 1 // 0: None, 1: Short, 2: Medium, 3: Long, 4: Custom

    // --- HTML TEMİZLEYİCİ ---
    function stripHtml(html) {
        if (!html) return ""
            return html.replace(/<[^>]*>/g, "")
    }

    // Bildirim Sunucusu
    property NotificationServer server: NotificationServer {
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        actionIconsSupported: true
        onNotification: notif => root.addNotification(notif)
    }

    function addNotification(notif) {
        // Gereksizleri at (Spotify vb.)
        if (notif.appName === "Spotify") return;

        // 1. İÇERİK HAZIRLIĞI (Firefox Düzeltmesi)
        var rawSummary = stripHtml(notif.summary || "")
        var rawBody = stripHtml(notif.body || "")
        var rawAppName = notif.appName || "Sistem"

        if (rawBody.trim() === "" && rawSummary !== "") {
            rawBody = rawSummary;
            rawSummary = rawAppName;
        }
        if (rawSummary === "") rawSummary = "Yeni Bildirim";
        if (rawBody === "") rawBody = "İçerik yok.";

        // 2. ÇİFT MESAJ ENGELLEME (ID veya içerik+zaman bazlı)
        var now = new Date();
        for (var d = 0; d < root.notifications.length && d < 5; d++) {
            var existing = root.notifications[d];
            // Aynı ID varsa güncelleme olabilir, tekrar ekleme
            if (existing.id === notif.id) return;
            // Aynı içerik 2 saniye içinde geldiyse engelle
            if (existing.summary === rawSummary && existing.body === rawBody) {
                var age = now - existing.timestamp;
                if (age < 2000) return;
            }
        }

        // İkon Çözücü (image://icon/ — rofi/wofi tarzı)
        var finalIcon = "";

        var appLower = rawAppName.toLowerCase().replace(/\s+/g, "-");
        var knownAppIcons = {
            "telegram-desktop": "telegram",
            "telegram": "telegram",
            "whatsapp": "whatsapp",
            "whatsapp-desktop": "whatsapp",
            "whatsapp-for-linux": "whatsapp",
            "zapzap": "whatsapp",
            "firefox": "firefox",
            "firefox-esr": "firefox-esr",
            "firefox-developer-edition": "firefox-developer-edition",
            "brave-browser": "brave",
            "brave": "brave",
            "google-chrome": "google-chrome",
            "google-chrome-stable": "google-chrome",
            "chromium": "chromium",
            "chromium-browser": "chromium-browser"
        };

        if (knownAppIcons[appLower]) {
            finalIcon = "image://icon/" + knownAppIcons[appLower];
            console.log("Service: Known app icon override. App: '" + rawAppName + "' -> " + finalIcon);
        } else {
            // 2. Genel ikon çözümlemesi
            let rawIcon = notif.image || notif.appIcon || notif.icon || "";
            if (rawIcon !== "") {
                if (rawIcon.startsWith("/") || rawIcon.startsWith("file://") || rawIcon.startsWith("http://") || rawIcon.startsWith("https://")) {
                    finalIcon = rawIcon.startsWith("/") ? "file://" + rawIcon : rawIcon;
                } else {
                    var normalized = rawIcon.toLowerCase().replace(/\s+/g, "-");
                    finalIcon = "image://icon/" + normalized;
                    console.log("Service: Icon normalized. Raw: '" + rawIcon + "' -> Normalized: '" + normalized + "'");
                }
            }
        }

        // Yeni Bildirim Objesi
        var newNotif = {
            id: notif.id,
            summary: rawSummary,
            body: rawBody,
            appName: rawAppName,
            appIcon: finalIcon,
            urgency: notif.urgency,
            timestamp: new Date(),
            closed: false
        };

        // Listeyi Güncelle (En başa ekle, max 100 tut)
        var newList = [newNotif];
        for(var i=0; i<root.notifications.length; i++) {
            if(i < 99) newList.push(root.notifications[i]);
        }
        root.notifications = newList;
        root.refreshActiveNotifications();
        console.log("Service: Notification added. Title:", newNotif.summary, "Active Count:", root.activeNotifications.length);
    }

    function removeNotification(index) {
        var list = root.notifications;
        // Listeden sil
        list.splice(index, 1);
        // Tetiklemek için tekrar ata
        root.notifications = list;
        root.refreshActiveNotifications();
    }

    function refreshActiveNotifications() {
        // Sadece kapatılmamış olanları filtrele
        root.activeNotifications = root.notifications.filter(n => !n.closed);
    }

    // 1 dakika sonra bildirimleri otomatik temizle
    Timer {
        id: cleanupTimer
        interval: 5000 // Her 5 saniyede kontrol et
        repeat: true
        running: true
        onTriggered: {
            var now = new Date();
            var changed = false;
            var newList = [];
            for (var i = 0; i < root.notifications.length; i++) {
                var age = now - root.notifications[i].timestamp;
                if (age < 60000) { // 60 saniye = 1 dakika
                    newList.push(root.notifications[i]);
                } else {
                    changed = true;
                }
            }
            if (changed) {
                root.notifications = newList;
                root.refreshActiveNotifications();
            }
        }
    }

    function closeNotification(id) {
        // ID'ye göre bul ve kapatıldı işaretle
        for(var i=0; i<root.notifications.length; i++) {
            if (root.notifications[i].id === id) {
                root.notifications[i].closed = true;
            }
        }
        root.refreshActiveNotifications();
    }

    // --- PENCERE ODAKLAMA ---
    property string _pendingAppName: ""

    // Pencere listesi al
    Process {
        id: windowListProc
        command: ["niri", "msg", "-j", "windows"]
        running: false

        property string fullOutput: ""

        stdout: SplitParser {
            onRead: data => {
                windowListProc.fullOutput += data;
            }
        }

        onExited: {
            try {
                var windows = JSON.parse(windowListProc.fullOutput);
                var appLower = root._pendingAppName.toLowerCase();
                var found = null;

                // appName'i kelimelere ayır (ör: "Telegram Desktop" -> ["telegram", "desktop"])
                var words = appLower.split(/[\s._-]+/).filter(w => w.length > 1);

                for (var i = 0; i < windows.length; i++) {
                    var w = windows[i];
                    var appId = (w.app_id || "").toLowerCase();

                    // Her kelime app_id içinde var mı kontrol et
                    for (var j = 0; j < words.length; j++) {
                        if (appId.indexOf(words[j]) !== -1) {
                            found = w;
                            break;
                        }
                    }
                    if (found) break;

                    // Tam eşleşme de dene
                    if (appId.indexOf(appLower) !== -1 || appLower.indexOf(appId) !== -1) {
                        found = w;
                        break;
                    }
                }

                if (found) {
                    console.log("Pencereye odaklanılıyor: " + found.app_id + " (id: " + found.id + ")");
                    focusProc.command = ["niri", "msg", "action", "focus-window", "--id", String(found.id)];
                    focusProc.running = true;
                } else {
                    console.log("Pencere bulunamadı: " + root._pendingAppName);
                }
            } catch(e) {
                console.log("Window parse error:", e);
            }
            windowListProc.fullOutput = "";
        }
    }

    // Pencereyi odakla
    Process {
        id: focusProc
        command: []
        running: false
    }

    function focusApp(appName) {
        if (!appName || appName === "") return;
        root._pendingAppName = appName;
        windowListProc.fullOutput = "";
        windowListProc.running = true;
    }

    // ── PERSISTENCE (AYARLARI KAYDETME) ──
    property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/notification_config.json"
    
    // Config Okuma
    Process {
        id: configReadProc
        command: ["cat", root.configPath]
        property string outputBuffer: ""
        stdout: SplitParser { onRead: (data) => configReadProc.outputBuffer += data }
        onExited: {
            if (configReadProc.outputBuffer.trim() === "") return;
            try {
                var cfg = JSON.parse(configReadProc.outputBuffer);
                if (cfg.displayDuration) {
                    // Update without triggering write immediately if possible, 
                    // but since we bind onChanged, we might need a flag or just let it write once.
                    root.displayDuration = cfg.displayDuration;
                    console.log("Notification config loaded. Duration:", root.displayDuration);
                }
                if (cfg.dnd !== undefined) {
                    root.dnd = cfg.dnd;
                }
                if (cfg.popupPosition !== undefined) root.popupPosition = cfg.popupPosition;
                if (cfg.overlayEnabled !== undefined) root.overlayEnabled = cfg.overlayEnabled;
                if (cfg.compactMode !== undefined) root.compactMode = cfg.compactMode;
                if (cfg.popupShadowEnabled !== undefined) root.popupShadowEnabled = cfg.popupShadowEnabled;
                if (cfg.privacyMode !== undefined) root.privacyMode = cfg.privacyMode;
                if (cfg.animationSpeed !== undefined) root.animationSpeed = cfg.animationSpeed;
            } catch (e) {
                console.log("Notification config load error:", e);
            }
            configReadProc.outputBuffer = "";
        }
    }

    // Config Yazma
    Process {
        id: configWriteProc
        command: []
        running: false
    }

    function saveConfig() {
        var obj = {
            displayDuration: root.displayDuration,
            dnd: root.dnd,
            popupPosition: root.popupPosition,
            overlayEnabled: root.overlayEnabled,
            compactMode: root.compactMode,
            popupShadowEnabled: root.popupShadowEnabled,
            privacyMode: root.privacyMode,
            animationSpeed: root.animationSpeed
        };
        var jsonStr = JSON.stringify(obj, null, 2);
        
        // Escape check: simpler approach for basic JSON
        // Using printf to write to file
        configWriteProc.running = false;
        configWriteProc.command = ["sh", "-c", "printf '%s' '" + jsonStr + "' > " + root.configPath];
        configWriteProc.running = true;
        console.log("Notification config saved.");
    }

    // Load on start
    Component.onCompleted: {
        configReadProc.running = true;
    }

    // Save on change
    onDisplayDurationChanged: saveConfigTimer.restart()
    onDndChanged: saveConfigTimer.restart()
    onPopupPositionChanged: saveConfigTimer.restart()
    onOverlayEnabledChanged: saveConfigTimer.restart()
    onCompactModeChanged: saveConfigTimer.restart()
    onPopupShadowEnabledChanged: saveConfigTimer.restart()
    onPrivacyModeChanged: saveConfigTimer.restart()
    onAnimationSpeedChanged: saveConfigTimer.restart()

    // Debounce save
    Timer {
        id: saveConfigTimer
        interval: 1000
        repeat: false
        onTriggered: root.saveConfig()
    }
}
