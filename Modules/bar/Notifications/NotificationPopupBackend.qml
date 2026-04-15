import QtQuick
import Quickshell
import "../../../Services" as S

Item {
    id: backend

    property var notifService: S.Notifications
    readonly property bool anchorTop: notifService.popupPosition === 1 || notifService.popupPosition === 2 || notifService.popupPosition === 3
    readonly property bool anchorBottom: notifService.popupPosition === 4 || notifService.popupPosition === 5 || notifService.popupPosition === 6
    readonly property bool anchorLeft: notifService.popupPosition === 2 || notifService.popupPosition === 6
    readonly property bool anchorRight: notifService.popupPosition === 1 || notifService.popupPosition === 5
    readonly property int displaySeconds: Math.round(notifService.displayDuration / 1000)

    function clearAll() {
        notifService.notifications = [];
        notifService.refreshActiveNotifications();
    }

    function setDisplaySeconds(value) {
        var val = parseInt(value);
        if (isNaN(val)) return;
        notifService.displayDuration = val * 1000;
    }

    function adjustDisplayDuration(deltaMs) {
        var next = notifService.displayDuration + deltaMs;
        if (deltaMs < 0) {
            if (deltaMs === -60000 && notifService.displayDuration <= 60000) next = 5000;
            if (deltaMs === -5000 && notifService.displayDuration <= 5000) next = notifService.displayDuration;
        }
        if (deltaMs > 0) {
            if (deltaMs === 60000 && notifService.displayDuration > 240000) next = notifService.displayDuration;
            if (deltaMs === 5000 && notifService.displayDuration > 300000) next = notifService.displayDuration;
        }
        notifService.displayDuration = Math.max(1000, Math.min(next, 600000));
    }

    function notificationSummary(modelData) {
        return notifService.privacyMode ? "New notification" : modelData.summary;
    }

    function notificationBody(modelData) {
        return notifService.privacyMode ? "Content hidden" : modelData.body;
    }

    function showsImage(appIcon) {
        return appIcon !== "" && (appIcon.startsWith("file://") || appIcon.startsWith("image://"));
    }
}
