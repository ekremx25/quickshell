import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.platform
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

Item {
    id: service
    visible: false
    width: 0
    height: 0

    readonly property string configPath: Core.PathService.configPath("countdown.json")
    property int tickCounter: 0
    property var pendingModel: null

    function loadEvents(model) {
        if (!model) return;
        pendingModel = model;
        eventStore.load();
    }

    function saveEvents(model) {
        if (!model) return;
        var items = [];
        for (var i = 0; i < model.count; i++) items.push(model.get(i));
        eventStore.save(items);
    }

    function addEvent(model, title, targetDate) {
        if (!model || !targetDate) return;
        var value = (title || "").trim();
        if (value === "") value = "Event";
        model.append({
            title: value,
            target: targetDate.toISOString(),
            notified: false
        });
        saveEvents(model);
    }

    function removeEvent(model, index) {
        if (!model) return;
        model.remove(index);
        saveEvents(model);
    }

    function processTick(model) {
        if (!model) return;
        var now = new Date();
        for (var i = 0; i < model.count; i++) {
            var eventItem = model.get(i);
            var diff = new Date(eventItem.target) - now;
            if (diff <= 0 && !eventItem.notified) {
                notifyProc.msg = "\"" + (eventItem.title || "Event") + "\" time's up!";
                notifyProc.running = false;
                notifyProc.running = true;
                model.setProperty(i, "notified", true);
                saveEvents(model);
            }
        }
        tickCounter++;
    }

    Process {
        id: notifyProc
        property string msg: ""
        command: ["notify-send", "-u", "critical", "⏰ Countdown", notifyProc.msg]
    }

    Core.JsonDataStore {
        id: eventStore
        path: service.configPath
        defaultValue: []
        onLoadedValue: function(data) {
            if (!service.pendingModel || !Array.isArray(data)) return;
            service.pendingModel.clear();
            for (var i = 0; i < data.length; i++) service.pendingModel.append(data[i]);
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("CountdownService", "Config parse error: " + details);
        }
    }
}
