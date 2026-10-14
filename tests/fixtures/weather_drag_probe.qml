import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "./Services" as S
import "./Services/core" as Core
import "./Modules/bar/Weather" as Weather

ShellRoot {
    id: probe
    property int phase: 0
    property int ticks: 0
    property bool boundaryDone: false
    property point expected: Qt.point(0, 0)
    Weather.WeatherDesktop { id: weather }
    TestEvent { id: pointer }
    TestResult { id: render }
    function find(item, predicate, seen) {
        if (!item) return null;
        seen = seen || [];
        if (seen.indexOf(item) !== -1) return null;
        seen.push(item);
        if (predicate(item)) return item;
        for (var pool of [item.children || [], item.data || [], item.instances || [], item.contentItem ? [item.contentItem] : []]) {
            if (typeof pool !== "object" || typeof pool.length !== "number") continue;
            for (var i = 0; i < pool.length; i++) {
                var found = find(pool[i], predicate, seen);
                if (found) return found;
            }
        }
        return null;
    }
    function fail(error) { console.error("SETTINGS_UI_FAIL weather_drag: " + error); Qt.exit(1); }
    Core.JsonDataStore {
        id: saved
        path: S.DesktopWidgetPositions.configPath
        onLoadedValue: function(value) {
            if (probe.phase !== 2) return;
            var position = value.weather && value.weather.primary;
            if (!position || position.x !== probe.expected.x || position.y !== probe.expected.y) return;
            S.ScreenManager.setScreenPreference("weather", ["none"]);
            probe.phase = 3;
        }
    }
    Timer {
        id: steps
        interval: 25
        repeat: true
        running: true
        onTriggered: {
            try {
                if (++probe.ticks > 350) throw new Error("timeout phase " + probe.phase);
                if (!S.ScreenManager.screenPreferences.weather || Quickshell.screens.length !== 3) return;
                if (probe.phase === 0) {
                    weather.popupData = {
                        feelsLike: "5", humidity: "85", wind: "6", sunrise: "06:24", sunset: "17:37", desc: "Overcast",
                        forecast: [1, 2, 3, 4, 5].map(day => ({day: "Day " + day, icon: "☁", min: 7, max: 17}))
                    };
                    S.ScreenManager.runtimeRoleMap = {primary: Quickshell.screens[0].name};
                    S.ScreenManager.setScreenPreference("weather", ["primary"]);
                    probe.phase = 1;
                    return;
                }
                var panel = weather.testPanels.length ? weather.testPanels[0] : null;
                if (probe.phase === 2) { saved.load(); return; }
                if (probe.phase === 3) {
                    if (panel) return;
                    S.ScreenManager.setScreenPreference("weather", ["primary"]);
                    probe.phase = 4;
                    return;
                }
                if (!panel || panel.width <= 0) return;
                var drag = probe.find(panel, n => n.drag !== undefined && n.drag.target);
                if (!drag) throw new Error("weather has no drag handle");
                var frame = drag.drag.target;
                if (frame.height > 760) throw new Error("weather card retains excess bottom space");
                if (probe.phase === 4) {
                    if (Math.abs(frame.x - probe.expected.x) > 1 || Math.abs(frame.y - probe.expected.y) > 1)
                        throw new Error("position not restored after reopening");
                    if (!probe.boundaryDone) {
                        steps.stop();
                        try {
                            pointer.mousePress(drag, 100, 25, Qt.LeftButton, Qt.NoModifier, 0);
                            pointer.mouseMove(panel.contentItem, frame.x + 70, frame.y + 5, 0, Qt.LeftButton, Qt.NoModifier);
                            pointer.mouseMove(panel.contentItem, 0, 0, 0, Qt.LeftButton, Qt.NoModifier);
                            pointer.mouseRelease(panel.contentItem, 0, 0, Qt.LeftButton, Qt.NoModifier, 0);
                            if (frame.x !== 0 || frame.y !== 0) throw new Error("drag did not clamp to screen corner");
                            probe.expected = Qt.point(0, 0);
                            probe.boundaryDone = true;
                            probe.phase = 2;
                        } finally { steps.start(); }
                        return;
                    }
                    console.log("SETTINGS_UI_PASS weather_drag"); Qt.quit(); return;
                }
                steps.stop();
                try {
                    if (!render.waitForPolish(frame.Window.window, 1000)) throw new Error("weather polish failed");
                    frame.Window.window.update();
                    if (!render.waitForRendering(frame, 1000))
                        throw new Error("weather not rendered: panel=" + panel.visible + " frame=" + frame.visible + " geometry=" + frame.x + "," + frame.y + "," + frame.width + "," + frame.height + " window=" + frame.Window.window.visible);
                    var lastDay = probe.find(frame, n => n.text === "Day 5");
                    if (!lastDay || lastDay.parent.parent.mapToItem(frame, 0, lastDay.parent.parent.height).y > frame.height - 24)
                        throw new Error("compact card clips the five-day forecast");
                    var x = frame.x, y = frame.y;
                    if (panel.mask.item !== frame) throw new Error("desktop input mask missing");
                    if (!pointer.mousePress(drag, 100, 25, Qt.LeftButton, Qt.NoModifier, 0)) throw new Error("press failed");
                    pointer.mouseMove(panel.contentItem, x + 80, y + 35, 0, Qt.LeftButton, Qt.NoModifier);
                    pointer.mouseMove(panel.contentItem, x - 80, y + 65, 0, Qt.LeftButton, Qt.NoModifier);
                    pointer.mouseRelease(panel.contentItem, x - 80, y + 65, Qt.LeftButton, Qt.NoModifier, 0);
                    if (frame.x >= x || frame.y <= y) throw new Error("drag did not move weather in both axes");
                    if (frame.x < 0 || frame.y < 0 || frame.x + frame.width > panel.width || frame.y + frame.height > panel.height)
                        throw new Error("widget escaped screen bounds");
                    probe.expected = Qt.point(Math.round(frame.x), Math.round(frame.y));
                    probe.phase = 2;
                } finally { steps.start(); }
            } catch (error) { probe.fail(error); }
        }
    }
}
