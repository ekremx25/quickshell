import QtQuick
import Quickshell
import "./Services" as Services
import "./Services/core" as Core
import "./Modules/bar" as BarUI

ShellRoot {
    id: probe
    property int step: -1
    property int ticks: 0
    property var openedPopups: []
    property var components: ["weather", "worldclock", "markets", "dock", "osd", "toast", "workspaces", "notifications"]
    property var choices: [["none"], ["primary"], ["secondary"], ["tertiary"], ["all"], ["none"]]
    BarUI.Bar { id: bar }
    Core.JsonDataStore {
        id: writer
        path: Services.ScreenManager.configPath
    }
    function find(item, predicate, seen) {
        if (!item) return null;
        seen = seen || [];
        if (seen.indexOf(item) !== -1) return null;
        seen.push(item);
        if (predicate(item)) return item;
        for (var pool of [item.children || [], item.data || [], item.item ? [item.item] : []]) {
            if (typeof pool !== "object" || typeof pool.length !== "number") continue;
            for (var i = 0; i < pool.length; i++) {
                var found = find(pool[i], predicate, seen);
                if (found) return found;
            }
        }
        return null;
    }
    function writeNext() {
        step++;
        var cfg = JSON.parse(JSON.stringify(Services.ScreenManager.screenPreferences));
        cfg._routingProbe = step;
        for (var component of components) cfg[component] = choices[step];
        writer.save(cfg);
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            try {
                if (++probe.ticks > 400) throw new Error("file reload timeout at step " + probe.step);
                if (Quickshell.screens.length !== 3 || !Services.ScreenManager.screenPreferences.dock || bar.instances.length !== 3) return;
                if (probe.step === -1) {
                    Services.ScreenManager.runtimeRoleMap = {
                        primary: Quickshell.screens[0].name,
                        secondary: Quickshell.screens[1].name,
                        tertiary: Quickshell.screens[2].name
                    };
                    probe.writeNext();
                    return;
                }
                if (Services.ScreenManager.screenPreferences._routingProbe !== probe.step) return;
                var expected = (probe.step === 0 || probe.step === 5) ? [] : probe.step === 4 ? Quickshell.screens
                    : [Quickshell.screens[probe.step - 1]];
                for (var component of probe.components) {
                    var actual = Services.ScreenManager.getFilteredScreens(component);
                    if (JSON.stringify(actual.map(s => s.name)) !== JSON.stringify(expected.map(s => s.name)))
                        throw new Error(component + " persisted selection " + probe.choices[probe.step] + " routed to " + actual.map(s => s.name));
                }
                for (var previous of probe.openedPopups) {
                    if (previous && previous.visible && !expected.some(s => s.name === previous.screen.name))
                        throw new Error("open popup survived disabling its screen");
                }
                for (var instance of bar.instances) {
                    var shown = expected.some(s => s.name === instance.modelData.name);
                    if (instance.showWorkspaces !== shown) throw new Error("workspace role mismatch " + instance.modelData.name);
                    var notification = probe.find(instance, n => n.hasActive !== undefined && n.notifService !== undefined);
                    if (!!notification !== shown) throw new Error("notification visibility mismatch " + instance.modelData.name);
                    if (notification) {
                        var popup = probe.find(notification, n => n.screen !== undefined && n.notifService !== undefined);
                        if (!popup || popup.screen.name !== instance.modelData.name)
                            throw new Error("notification popup screen mismatch " + instance.modelData.name);
                        var duration = probe.find(notification, n => n !== popup && n.screen !== undefined && n.notifService !== undefined);
                        if (!duration || duration.screen.name !== instance.modelData.name)
                            throw new Error("duration popup screen mismatch");
                        popup.visible = true;
                        duration.visible = true;
                        probe.openedPopups.push(popup, duration);
                    }
                }
                if (probe.step === 5) {
                    console.log("SETTINGS_UI_PASS routing");
                    Qt.quit();
                } else probe.writeNext();
            } catch (error) {
                console.error("SETTINGS_UI_FAIL routing: " + error);
                Qt.exit(1);
            }
        }
    }
}
