import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "./Modules/bar/Settings" as UI
import "./Modules/bar" as BarUI
import "./Services" as Services
import "./Services/core" as Core

ShellRoot {
    id: probe
    property string testPage: "__PAGE__"
    property int phase: 0
    property int ticks: 0
    property string expectedModule: ""
    property var page: null
    property int screenStep: 0
    property bool rolesConfigured: false
    property string chosenScreen: ""
    UI.Settings { id: standaloneWindow; visible: probe.testPage !== "workspaces"; currentPage: probe.testPage }
    property var window: probe.testPage === "workspaces"
        ? (fullBar.item && fullBar.item.instances.length ? find(fullBar.item.instances[0], function(node) {
            return typeof node.saveConfig === "function" && node.currentPage !== undefined;
        }) : null)
        : standaloneWindow
    BarUI.BarBackend { id: barConsumer }
    Loader {
        id: fullBar
        active: probe.testPage === "workspaces"
        sourceComponent: Component { BarUI.Bar {} }
    }
    TestEvent { id: pointer }
    TestResult { id: rendering }

    function find(item, predicate, visited) {
        if (!item) return null;
        var seen = visited || [];
        if (seen.indexOf(item) !== -1) return null;
        seen.push(item);
        if (predicate(item)) return item;
        for (var children of [item.children || [], item.data || [], item.contentItem ? [item.contentItem] : []]) {
            if (typeof children !== "object" || typeof children.length !== "number") continue;
            for (var i = 0; i < children.length; i++) {
                var result = find(children[i], predicate, seen);
                if (result) return result;
            }
        }
        return null;
    }
    function fail(message) { console.error("SETTINGS_UI_FAIL " + testPage + ": " + message); Qt.exit(1); }
    function clickLabel(item, label, switchControl) {
        steps.stop();
        try {
            if (!rendering.waitForPolish(window.contentItem.Window.window, 1000)
                    || !rendering.waitForRendering(item, 1000))
                throw new Error("Control layout not rendered: " + label);
            var text = find(item, function(node) { return node.text !== undefined && String(node.text).trim() === label; });
            if (!text) text = find(item, function(node) { return node.text !== undefined && String(node.text).indexOf(label) !== -1; });
            if (!text) throw new Error("Missing control: " + label);
            if (switchControl) {
                var container = text.parent;
                var control = null;
                while (container && !control) {
                    control = find(container, function(node) { return node.checked !== undefined && typeof node.toggle === "function"; });
                    container = container.parent;
                }
                if (!control) throw new Error("Missing switch: " + label);
                text = control;
            }
            if (probe.testPage === "workspaces") {
                var ancestor = text.parent;
                while (ancestor && ancestor.contentY === undefined) ancestor = ancestor.parent;
                if (ancestor) {
                    var position = text.mapToItem(ancestor.contentItem, 0, 0);
                    ancestor.contentY = Math.max(0, Math.min(ancestor.contentHeight - ancestor.height,
                                                          position.y - ancestor.height / 2));
                    if (!rendering.waitForPolish(window.contentItem.Window.window, 1000)
                            || !rendering.waitForRendering(item, 1000)) throw new Error("Scroll not rendered");
                }
            }
            if (!pointer.mouseClick(text, text.width / 2, text.height / 2, Qt.LeftButton, Qt.NoModifier, 0))
                throw new Error("Pointer event not delivered: " + label);
        } finally { steps.start(); }
    }
    Core.JsonDataStore {
        id: persisted
        path: Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/" + ((probe.testPage === "bar" || probe.testPage === "workspaces") ? "bar_config.json" : probe.testPage === "dock" ? "dock_config.json" : "screen_config.json")
        onLoadedValue: function(value) {
            if (probe.phase !== 2) return;
            var expectedScreens = probe.screenStep === 0 ? ["none"]
                                : probe.screenStep <= 3 ? Services.ScreenManager.getAvailableScreenNames().slice(0, probe.screenStep)
                                : ["all"];
            var ok = probe.testPage === "bar" ? value.center && value.center.indexOf(probe.expectedModule) !== -1
                   : probe.testPage === "dock" ? value.dockPosition === "top"
                   : probe.testPage === "workspaces" ? value.workspaces && value.workspaces.style === "outline" && value.workspaces.showApps === false
                   : JSON.stringify(value.dock) === JSON.stringify(expectedScreens);
            if (ok) {
                if (probe.testPage === "screens" && probe.screenStep < 4) {
                    probe.screenStep++;
                    probe.phase = 3;
                } else {
                    window.visible = false;
                    probe.phase = 4;
                    Qt.callLater(function() { window.visible = true; });
                }
            }
        }
    }
    Timer {
        id: steps
        interval: 20; repeat: true; running: true
        onTriggered: {
            try {
                probe.ticks++;
                if (!window) return;
                if (probe.testPage === "workspaces" && probe.phase === 0 && !window.visible) {
                    window.currentPage = "workspaces";
                    window.visible = true;
                    return;
                }
                if (probe.ticks > 200) { probe.fail("page/data/save timeout phase=" + probe.phase); return; }
                if (probe.phase === 2) { persisted.load(); return; }
                if (probe.phase === 3) {
                    var row = probe.find(window.contentItem, function(node) { return node.compId === "dock"; });
                    if (!row) return;
                    if (probe.screenStep <= 3) {
                        probe.chosenScreen = Services.ScreenManager.getAvailableScreenNames()[probe.screenStep - 1];
                        probe.clickLabel(row, Services.ScreenManager.screenLabel(probe.chosenScreen));
                        if (Services.ScreenManager.getFilteredScreens("dock").length !== probe.screenStep) { probe.fail("individual screen choice failed"); return; }
                    } else {
                        probe.clickLabel(row, "All");
                        if (Services.ScreenManager.getFilteredScreens("dock").length !== Quickshell.screens.length) { probe.fail("all-screen choice failed"); return; }
                    }
                    probe.phase = 2;
                    return;
                }
                if (probe.phase === 4) {
                    if (!window.visible) return;
                    var restored = null;
                    if (probe.testPage === "bar") {
                        restored = probe.find(window.contentItem, function(node) { return typeof node.beginDrag === "function"; });
                        if (!restored || !restored.centerModel || !restored.centerModel.count) return;
                        if (restored.centerModel.get(0).name !== probe.expectedModule) { probe.fail("bar state lost on reopen"); return; }
                    } else if (probe.testPage === "dock") {
                        restored = probe.find(window.contentItem, function(node) { return node.cfg_dockScale !== undefined; });
                        if (!restored || !restored.isLoaded) return;
                        if (restored.cfg_dockPosition !== "top") { probe.fail("dock state lost on reopen"); return; }
                    } else if (probe.testPage === "workspaces") {
                        restored = probe.find(window.contentItem, function(node) { return typeof node.applyWorkspaceSettings === "function"; });
                        if (!restored || restored.selectedStyle !== "outline" || barConsumer.workspacesConfig.style !== "outline") return;
                        if (!fullBar.item || fullBar.item.instances.length !== 3) return;
                        for (var instance of fullBar.item.instances) {
                            var widget = probe.find(instance, function(node) { return typeof node.scrollWorkspaces === "function"; });
                            if (!widget || widget.style !== "outline" || widget.config.style !== "outline" || widget.showApps !== false) return;
                            var barSurface = widget.parent.parent.parent;
                            if (barSurface.color.a !== 0 || barSurface.border.width !== 0) {
                                probe.fail("bar background must remain transparent without a border"); return;
                            }
                        }
                    } else {
                        restored = probe.find(window.contentItem, function(node) { return node.compId === "dock"; });
                        if (!restored) return;
                        if (restored.currentPref[0] !== "all") { probe.fail("screen state lost on reopen"); return; }
                    }
                    console.log("SETTINGS_UI_PASS " + probe.testPage);
                    Qt.quit();
                    return;
                }
                if (probe.testPage === "workspaces") {
                    probe.page = probe.find(window.contentItem, function(node) { return typeof node.applyWorkspaceSettings === "function"; });
                    if (!probe.page || !barConsumer.configLoaded) return;
                    if (probe.page.settingsPopup !== window) { probe.fail("missing settings window dependency"); return; }
                    probe.clickLabel(probe.page, "Outline");
                    if (probe.page.selectedStyle !== "outline") { probe.fail("style click failed"); return; }
                    if (probe.page.showApps) probe.clickLabel(probe.page, "Show Workspace Apps", true);
                    if (probe.page.showApps) { probe.fail("show-apps switch did not change"); return; }
                    probe.clickLabel(probe.page, "Apply");
                    probe.phase = 2;
                } else if (probe.testPage === "bar") {
                    probe.page = probe.find(window.contentItem, function(node) { return typeof node.beginDrag === "function"; });
                    if (!probe.page || !window.barConfig.left || !window.barConfig.left.length) return;
                    if (!probe.page.leftModel || !probe.page.centerModel || !probe.page.backend) { probe.fail("missing backend or list models"); return; }
                    for (var name of ["leftModel", "centerModel", "rightModel", "inactiveModel", "dockLeftModel", "dockRightModel"]) {
                        if (!probe.page[name] || probe.page[name] !== probe.page.backend[name]) { probe.fail("model dependency mismatch: " + name); return; }
                    }
                    for (var moduleName of probe.page.backend.allModuleNames) {
                        var groups = ["left", "center", "right", "inactive", "dockLeft", "dockRight"];
                        var originalGroup = "", originalIndex = -1;
                        for (var group of groups) {
                            var index = probe.page.backend.indexOfName(probe.page.backend.getModelForGroup(group), moduleName);
                            if (index >= 0) { originalGroup = group; originalIndex = index; break; }
                        }
                        if (originalIndex < 0) { probe.fail("module missing: " + moduleName); return; }
                        probe.page.beginDrag(originalGroup, originalIndex, moduleName);
                        probe.page.handleDrop("dockLeft", 0);
                        if (probe.page.backend.indexOfName(probe.page.dockLeftModel, moduleName) !== 0) { probe.fail("cannot move to dock: " + moduleName); return; }
                        if (probe.page.backend.buildDockConfigFromModels().leftModules.indexOf(moduleName) !== 0) { probe.fail("dock serialization removed " + moduleName); return; }
                        probe.page.beginDrag("dockLeft", 0, moduleName);
                        probe.page.handleDrop("center", 0);
                        if (probe.page.backend.indexOfName(probe.page.centerModel, moduleName) !== 0) { probe.fail("cannot move to bar: " + moduleName); return; }
                        if (probe.page.backend.buildBarConfigFromModels().center.indexOf(moduleName) !== 0) { probe.fail("bar serialization removed " + moduleName); return; }
                        probe.page.beginDrag("center", 0, moduleName);
                        probe.page.handleDrop(originalGroup, originalIndex);
                    }
                    if (!probe.page.leftModel.count) return;
                    probe.expectedModule = probe.page.leftModel.get(0).name;
                    probe.page.beginDrag("left", 0, probe.expectedModule);
                    probe.page.handleDrop("center", 0);
                    if (!probe.page.centerModel.count || probe.page.centerModel.get(0).name !== probe.expectedModule) { probe.fail("module move failed"); return; }
                    probe.phase = 2;
                    probe.clickLabel(probe.page, "Save");
                } else if (probe.testPage === "dock") {
                    probe.page = probe.find(window.contentItem, function(node) { return node.cfg_dockScale !== undefined; });
                    if (!probe.page) return;
                    if (probe.page.settingsPopup !== window) { probe.fail("missing settings window dependency"); return; }
                    if (!probe.page.isLoaded || !window.dockConfig.dockScale) return;
                    if (Math.abs(probe.page.cfg_dockScale - window.dockConfig.dockScale) > 0.00001) { probe.fail("saved scale not loaded"); return; }
                    probe.clickLabel(probe.page, "Top");
                    if (probe.page.cfg_dockPosition !== "top") { probe.fail("position click failed"); return; }
                    probe.phase = 2;
                } else {
                    probe.page = probe.find(window.contentItem, function(node) { return node.componentIds !== undefined; });
                    if (!probe.page || !Services.ScreenManager.screenPreferences.dock) return;
                    if (probe.page.componentIds.indexOf("appdrawer") !== -1) { probe.fail("unsupported App Drawer preference exposed"); return; }
                    if (!probe.rolesConfigured) {
                        Services.ScreenManager.runtimeRoleMap = {
                            primary: Quickshell.screens[0].name,
                            secondary: Quickshell.screens[1].name,
                            tertiary: Quickshell.screens[2].name
                        };
                        probe.rolesConfigured = true;
                        return;
                    }
                    var row = probe.find(probe.page, function(node) { return node.compId === "dock"; });
                    if (!row) return;
                    probe.clickLabel(row, "Disable");
                    if (Services.ScreenManager.getFilteredScreens("dock").length !== 0) { probe.fail("screen preference click did not disable dock"); return; }
                    probe.phase = 2;
                }
            } catch (error) { probe.fail(String(error) + " phase=" + probe.phase + " stack=" + String(error.stack).replace(/\n/g, " | ")); }
        }
    }
}
