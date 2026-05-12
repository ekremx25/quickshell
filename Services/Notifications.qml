pragma Singleton
import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Services.Notifications
import "./"
import "./core" as Core
import "./core/Log.js" as Log

Singleton {
    id: root

    readonly property int maxStoredNotifications: 100
    readonly property int duplicateWindowMs: 2000
    readonly property int cleanupCheckIntervalMs: 5000
    readonly property var knownAppIcons: ({
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
    })

    property var notifications: []
    property var activeNotifications: []
    signal newNotificationReceived(var notif)
    
    property bool historyVisible: false
    function toggleHistory() { historyVisible = !historyVisible }
    property int displayDuration: 5000
    property bool dnd: false
    property int popupPosition: 1 // 1: Top Right, 2: Top Left, 3: Top Center, 4: Bottom Center, 5: Bottom Right, 6: Bottom Left
    property bool overlayEnabled: false
    property bool compactMode: false
    property bool popupShadowEnabled: true
    property bool privacyMode: false
    property int animationSpeed: 1 // 0: None, 1: Short, 2: Medium, 3: Long, 4: Custom
    property int historyRetentionMs: 300000
    property var filteredApps: ["Spotify"]
    property bool notificationServerEnabled: true
    property bool notificationServerReady: false

    function stripHtml(html) {
        if (!html) return ""
        return html.replace(/<[^>]*>/g, "")
    }

    function normalizeNotificationContent(notif) {
        var appName = notif.appName || "System"
        var summary = stripHtml(notif.summary || "")
        var body = stripHtml(notif.body || "")

        if (body.trim() === "" && summary !== "") {
            body = summary
            summary = appName
        }
        if (summary === "") summary = "New Notification"
        if (body === "") body = "No content."

        return {
            appName: appName,
            summary: summary,
            body: body
        }
    }

    function resolveIconSource(rawIconValue) {
        var raw = String(rawIconValue || "").trim()
        if (raw === "") return ""
        if (raw.startsWith("image://icon//")) return "file://" + raw.substring("image://icon/".length)
        if (raw.startsWith("file://") || raw.startsWith("http://") || raw.startsWith("https://") || raw.startsWith("image://")) return raw
        if (raw.startsWith("~/")) {
            return "file://" + StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + raw.substring(1)
        }
        if (raw.startsWith("/") || raw.indexOf("/") !== -1) return "file://" + raw
        return "image://icon/" + raw.toLowerCase().replace(/\s+/g, "-")
    }

    function resolveNotificationIcon(appName, notif) {
        var appLower = String(appName || "").toLowerCase().replace(/\s+/g, "-")
        if (root.knownAppIcons[appLower]) return "image://icon/" + root.knownAppIcons[appLower]
        return resolveIconSource(notif.image || notif.appIcon || notif.icon || "")
    }

    function applyNotifications(list) {
        root.notifications = list
        root.activeNotifications = list.filter(function(n) { return !n.closed })
    }

    function pruneNotifications(now) {
        var changed = false
        var pruned = []
        for (var i = 0; i < root.notifications.length; i++) {
            var item = root.notifications[i]
            if ((now - item.timestamp) < root.historyRetentionMs) {
                pruned.push(item)
            } else {
                changed = true
            }
        }
        if (changed) root.applyNotifications(pruned)
    }

    property Loader serverLoader: Loader {
        active: root.notificationServerEnabled && root.notificationServerReady
        sourceComponent: notificationServerComponent
    }

    property Component notificationServerComponent: Component {
        NotificationServer {
            bodySupported: true
            bodyMarkupSupported: true
            actionsSupported: true
            actionIconsSupported: true
            onNotification: notif => root.addNotification(notif)
        }
    }

    function addNotification(notif) {
        if (root.filteredApps.some(function(app) { return app.toLowerCase() === (notif.appName || "").toLowerCase() })) return

        var now = new Date()
        var normalized = normalizeNotificationContent(notif)
        
        var existingIndex = -1;
        // Check if updating an existing notification by ID
        for (var i = 0; i < root.notifications.length; i++) {
            if (root.notifications[i].id === notif.id && notif.id !== undefined) {
                existingIndex = i;
                break;
            }
        }
        
        // Ignore exact duplicates within the duplicate window
        if (existingIndex === -1) {
            for (var j = 0; j < root.notifications.length && j < 5; j++) {
                var existing = root.notifications[j]
                if (existing.summary === normalized.summary && existing.body === normalized.body) {
                    var age = now - existing.timestamp
                    if (age < root.duplicateWindowMs) return
                }
            }
        }

        var newNotif = {
            id: notif.id !== undefined ? notif.id : Date.now(),
            summary: normalized.summary,
            body: normalized.body,
            appName: normalized.appName,
            appIcon: resolveNotificationIcon(normalized.appName, notif),
            urgency: notif.urgency,
            timestamp: now,
            closed: false
        }

        var next = [newNotif]
        for (var k = 0; k < root.notifications.length && next.length < root.maxStoredNotifications; k++) {
            if (k !== existingIndex) {
                next.push(root.notifications[k])
            }
        }
        
        root.applyNotifications(next)
        root.newNotificationReceived(newNotif)
    }

    function removeNotification(index) {
        var next = root.notifications.slice()
        next.splice(index, 1)
        root.applyNotifications(next)
    }

    function refreshActiveNotifications() {
        root.applyNotifications(root.notifications.slice())
    }

    Timer {
        id: cleanupTimer
        interval: root.cleanupCheckIntervalMs
        repeat: true
        running: true
        onTriggered: root.pruneNotifications(new Date())
    }

    function closeNotification(id) {
        var next = root.notifications.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                next[i].closed = true
            }
        }
        root.applyNotifications(next)
    }

    function focusApp(appName) {
        if (!appName || appName === "") return;
        CompositorService.focusAppByName(appName);
    }

    // ── PERSISTENCE (SAVE SETTINGS) ──
    property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/notification_config.json"
    
    function saveConfig() {
        var obj = {
            displayDuration: root.displayDuration,
            dnd: root.dnd,
            popupPosition: root.popupPosition,
            overlayEnabled: root.overlayEnabled,
            compactMode: root.compactMode,
            popupShadowEnabled: root.popupShadowEnabled,
            privacyMode: root.privacyMode,
            animationSpeed: root.animationSpeed,
            historyRetentionMs: root.historyRetentionMs,
            filteredApps: root.filteredApps,
            notificationServerEnabled: root.notificationServerEnabled
        };
        configStore.save(obj);
    }

    function syncNotificationServer() {
        notificationServerStartTimer.stop()
        if (!root.notificationServerEnabled) {
            root.notificationServerReady = false
            return
        }
        if (root.notificationServerReady) return
        notificationServerStartTimer.restart()
    }

    // Load on start
    Component.onCompleted: {
        configStore.load();
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
    onHistoryRetentionMsChanged: saveConfigTimer.restart()
    onFilteredAppsChanged: saveConfigTimer.restart()
    onNotificationServerEnabledChanged: {
        root.syncNotificationServer()
        saveConfigTimer.restart()
    }

    // Debounce save
    Timer {
        id: saveConfigTimer
        interval: 1000
        repeat: false
        onTriggered: root.saveConfig()
    }

    Timer {
        id: notificationServerStartTimer
        interval: 1200
        repeat: false
        onTriggered: root.notificationServerReady = true
    }

    Core.JsonDataStore {
        id: configStore
        path: root.configPath
        defaultValue: ({
            displayDuration: 5000,
            dnd: false,
            popupPosition: 1,
            overlayEnabled: false,
            compactMode: false,
            popupShadowEnabled: true,
            privacyMode: false,
            animationSpeed: 1,
            historyRetentionMs: 300000,
            filteredApps: ["Spotify"],
            notificationServerEnabled: true
        })
        onLoadedValue: function(cfg) {
            root.displayDuration = cfg.displayDuration || 5000;
            root.dnd = cfg.dnd !== undefined ? cfg.dnd : false;
            root.popupPosition = cfg.popupPosition !== undefined ? cfg.popupPosition : 1;
            root.overlayEnabled = cfg.overlayEnabled !== undefined ? cfg.overlayEnabled : false;
            root.compactMode = cfg.compactMode !== undefined ? cfg.compactMode : false;
            root.popupShadowEnabled = cfg.popupShadowEnabled !== undefined ? cfg.popupShadowEnabled : true;
            root.privacyMode = cfg.privacyMode !== undefined ? cfg.privacyMode : false;
            root.animationSpeed = cfg.animationSpeed !== undefined ? cfg.animationSpeed : 1;
            root.historyRetentionMs = cfg.historyRetentionMs !== undefined ? cfg.historyRetentionMs : 300000;
            root.filteredApps = Array.isArray(cfg.filteredApps) ? cfg.filteredApps : ["Spotify"];
            root.notificationServerEnabled = cfg.notificationServerEnabled !== undefined ? cfg.notificationServerEnabled : true;
            root.syncNotificationServer();
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("Notifications", "Config parse error: " + details);
        }
    }
}
