pragma Singleton

import QtQuick
import Quickshell
import "./core" as Core

Singleton {
    id: root

    readonly property string configPath: Core.PathService.configPath("desktop_widgets.json")
    property var positions: ({})

    Component.onCompleted: store.load()

    function position(widgetId, screenKey, defaultX, defaultY) {
        var widget = positions[widgetId];
        var saved = widget ? widget[screenKey] : null;
        if (!saved || !isFinite(Number(saved.x)) || !isFinite(Number(saved.y))) {
            return Qt.point(defaultX, defaultY);
        }
        return Qt.point(Number(saved.x), Number(saved.y));
    }

    function setPosition(widgetId, screenKey, x, y) {
        var next = JSON.parse(JSON.stringify(positions || {}));
        if (!next[widgetId]) next[widgetId] = {};
        next[widgetId][screenKey] = {
            x: Math.max(0, Math.round(x)),
            y: Math.max(0, Math.round(y))
        };
        positions = next;
        store.save(next);
    }

    function resetPosition(widgetId, screenKey) {
        var next = JSON.parse(JSON.stringify(positions || {}));
        if (next[widgetId]) delete next[widgetId][screenKey];
        positions = next;
        store.save(next);
    }

    Core.JsonDataStore {
        id: store
        path: root.configPath
        defaultValue: ({})
        onLoadedValue: function(data) {
            root.positions = data && typeof data === "object" ? data : {};
        }
    }
}
