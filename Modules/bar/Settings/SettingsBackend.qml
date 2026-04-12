import QtQuick
import Qt.labs.platform
import "."
import "SettingsPalette.js" as SettingsPalette
import "../BarDefaults.js" as BarDefaults
import "../../../Services/core" as Core
import "../../../Services/core/Log.js" as Log

Item {
    id: backend

    readonly property var initialBarConfig: BarDefaults.createBarConfig()
    readonly property string configDir: StandardPaths.writableLocation(StandardPaths.ConfigLocation).toString().replace("file://", "") + "/quickshell"

    property var barConfig: BarDefaults.clone(initialBarConfig)
    property var dockConfig: ({})
    property string configPath: configDir + "/bar_config.json"
    property string dockConfigPath: configDir + "/dock_config.json"
    property string customPresetPath: configDir + "/presets/custom.json"
    property string defaultsPath: configDir + "/Modules/bar/BarDefaults.js"
    property var dockLeftModulesList: []
    property var dockRightModulesList: []

    property var leftModel: null
    property var centerModel: null
    property var rightModel: null
    property var inactiveModel: null
    property var dockLeftModel: null
    property var dockRightModel: null

    readonly property var moduleInfo: ({
        "Launcher": { icon: "\ue7e6", label: "Launcher", color: "#1e66f5" },
        "Calendar": { icon: "", label: "Calendar", color: "#f5c2e7" },
        "Notepad": { icon: "󰠮", label: "Notepad", color: "#f9e2af" },
        "Workspaces": { icon: "", label: "Workspaces", color: "#cba6f7" },
        "Notifications": { icon: "󰂚", label: "Notifications", color: "#fab387" },
        "Weather": { icon: "󰖕", label: "Weather", color: "#f9e2af" },
        "Volume": { icon: "󰕾", label: "Volume", color: "#89b4fa" },
        "Equalizer": { icon: "󱞙", label: "Equalizer", color: "#89dceb" },
        "Tray": { icon: "󰇚", label: "Tray", color: "#a6adc8" },
        "Clipboard": { icon: "󰅍", label: "Clipboard", color: "#fab387" },
        "Power": { icon: "⏻", label: "Power", color: "#f38ba8" },
        "PowerGroup": { icon: "", label: "Power Group", color: "#a6e3a1" },
        "SysInfoGroup": { icon: "", label: "System Group", color: "#f9e2af" },
        "RamModule": { icon: "󰘚", label: "Memory", color: "#a6e3a1" },
        "Media": { icon: "♫", label: "Media", color: "#f5c2e7" }
    })

    readonly property var barPlacementNames: [
        "Launcher", "Calendar", "Notepad",
        "Workspaces", "Notifications", "Weather",
        "Volume", "Equalizer", "Tray", "Clipboard", "Power",
        "PowerGroup", "SysInfoGroup", "RamModule"
    ]

    readonly property var dockPlacementNames: [
        "Launcher", "Weather", "Volume", "Tray",
        "Notepad", "Power", "Clipboard", "Media"
    ]

    readonly property var allModuleNames: [
        "Launcher", "Calendar", "Notepad",
        "Workspaces", "Notifications", "Weather",
        "Volume", "Equalizer", "Tray", "Clipboard",
        "Power", "PowerGroup", "SysInfoGroup", "RamModule", "Media"
    ]

    JsonFileStore {
        id: barConfigStore
        path: backend.configPath
        onLoaded: function(text) {
            var raw = (text || "").trim();
            if (raw === "") {
                var seeded = backend.normalizeBarConfig(BarDefaults.clone(backend.initialBarConfig));
                backend.applyBarConfig(seeded);
                barConfigStore.write(JSON.stringify(seeded, null, 2));
                customPresetStore.write(JSON.stringify(seeded, null, 2));
                defaultsStore.write(backend.renderBarDefaults(seeded));
                return;
            }

            backend.applyBarConfig(backend.parseJsonObject(text, BarDefaults.clone(backend.initialBarConfig)));
        }
    }

    JsonFileStore {
        id: dockConfigStore
        path: backend.dockConfigPath
        onLoaded: function(text) {
            backend.applyDockModuleLists(backend.parseJsonObject(text, {}));
            barConfigStore.read();
        }
    }

    Core.FileChangeWatcher {
        id: dockConfigWatcher
        path: backend.dockConfigPath
        interval: 800
        active: true
        onChanged: dockConfigStore.read()
    }

    JsonFileStore {
        id: customPresetStore
        path: backend.customPresetPath
    }

    Core.TextDataStore {
        id: defaultsStore
        path: backend.defaultsPath
    }

    function parseJsonObject(text, fallback) {
        var raw = (text || "").trim();
        if (raw === "") return fallback;
        try {
            return JSON.parse(raw);
        } catch (e) {
            Log.warn("SettingsBackend", "Settings parse error: " + e);
            return fallback;
        }
    }

    function cloneValue(value) {
        return JSON.parse(JSON.stringify(value));
    }

    function getModelForGroup(groupName) {
        if (groupName === "left") return leftModel;
        if (groupName === "center") return centerModel;
        if (groupName === "right") return rightModel;
        if (groupName === "inactive") return inactiveModel;
        if (groupName === "dockLeft") return dockLeftModel;
        if (groupName === "dockRight") return dockRightModel;
        return null;
    }

    function canAssignToGroup(name, groupName) {
        if (!name || !groupName) return false;
        if (groupName === "inactive") return allModuleNames.indexOf(name) !== -1;
        if (groupName === "dockLeft" || groupName === "dockRight") {
            return dockPlacementNames.indexOf(name) !== -1;
        }
        return barPlacementNames.indexOf(name) !== -1;
    }

    function indexOfName(model, name) {
        if (!model) return -1;
        for (var i = 0; i < model.count; ++i) {
            if (model.get(i).name === name) return i;
        }
        return -1;
    }

    function moveModule(sourceGroup, sourceIndex, targetGroup, targetIndex, name) {
        var sourceModel = getModelForGroup(sourceGroup);
        var targetModel = getModelForGroup(targetGroup);
        if (!sourceModel || !targetModel || sourceIndex < 0 || sourceIndex >= sourceModel.count) return false;
        if (!canAssignToGroup(name, targetGroup)) return false;

        if (sourceGroup === targetGroup) {
            var boundedIndex = Math.max(0, Math.min(targetIndex, sourceModel.count - 1));
            if (boundedIndex !== sourceIndex) {
                sourceModel.move(sourceIndex, boundedIndex, 1);
            }
            return true;
        }

        sourceModel.remove(sourceIndex);

        var duplicateIndex = indexOfName(targetModel, name);
        if (duplicateIndex !== -1) {
            targetModel.remove(duplicateIndex);
            if (duplicateIndex < targetIndex) targetIndex -= 1;
        }

        var boundedTargetIndex = Math.max(0, Math.min(targetIndex, targetModel.count));
        if (boundedTargetIndex < targetModel.count) {
            targetModel.insert(boundedTargetIndex, { name: name });
        } else {
            targetModel.append({ name: name });
        }
        return true;
    }

    function collectUniqueNames(list, supportedNames, seen) {
        var output = [];
        var safeSeen = seen || ({});
        for (var i = 0; i < list.length; ++i) {
            var name = list[i];
            if (supportedNames.indexOf(name) === -1) continue;
            if (safeSeen[name]) continue;
            safeSeen[name] = true;
            output.push(name);
        }
        return output;
    }

    function renderBarDefaults(cfg) {
        var normalized = normalizeBarConfig(cfg);
        var workspaces = normalized.workspaces || BarDefaults.createWorkspacesConfig();
        var workspaceText = JSON.stringify(workspaces, null, 4).replace(/\n/g, "\n    ");

        return ".pragma library\n\n"
            + "// Fallback only. Runtime bar changes are saved to the quickshell config directory.\n\n"
            + "function createWorkspacesConfig() {\n"
            + "    return " + workspaceText + ";\n"
            + "}\n\n"
            + "function createBarConfig() {\n"
            + "    return {\n"
            + "        left: " + JSON.stringify(normalized.left) + ",\n"
            + "        center: " + JSON.stringify(normalized.center) + ",\n"
            + "        right: " + JSON.stringify(normalized.right) + ",\n"
            + "        inactive: " + JSON.stringify(normalized.inactive) + ",\n"
            + "        workspaces: createWorkspacesConfig(),\n"
            + "        theme: " + JSON.stringify(normalized.theme || "") + ",\n"
            + "        barPosition: " + JSON.stringify(normalized.barPosition || "top") + "\n"
            + "    };\n"
            + "}\n\n"
            + "function clone(value) {\n"
            + "    return JSON.parse(JSON.stringify(value));\n"
            + "}\n";
    }

    function syncListModel(model, names) {
        if (!model) return;
        model.clear();
        for (var i = 0; i < names.length; ++i) {
            model.append({ name: names[i] });
        }
    }

    function getModelNames(model) {
        var names = [];
        if (!model) return names;
        for (var i = 0; i < model.count; ++i) {
            names.push(model.get(i).name);
        }
        return names;
    }

    function applyDockModuleLists(cfg) {
        var normalized = normalizeDockConfig(cfg);
        syncListModel(dockLeftModel, normalized.leftModules);
        syncListModel(dockRightModel, normalized.rightModules);
        dockLeftModulesList = normalized.leftModules.slice();
        dockRightModulesList = normalized.rightModules.slice();
        dockConfig = normalized;
    }

    function normalizeDockConfig(cfg) {
        var normalized = cloneValue(cfg || {});
        if (!Array.isArray(normalized.leftModules)) normalized.leftModules = [];
        if (!Array.isArray(normalized.rightModules)) normalized.rightModules = [];

        var seen = {};
        normalized.leftModules = collectUniqueNames(normalized.leftModules, dockPlacementNames, seen);
        normalized.rightModules = collectUniqueNames(normalized.rightModules, dockPlacementNames, seen);
        delete normalized.modules;
        return normalized;
    }

    function normalizeBarConfig(cfg) {
        var normalized = BarDefaults.clone(cfg || initialBarConfig);
        if (!Array.isArray(normalized.left)) normalized.left = [];
        if (!Array.isArray(normalized.center)) normalized.center = [];
        if (!Array.isArray(normalized.right)) normalized.right = [];
        if (!Array.isArray(normalized.inactive)) normalized.inactive = [];
        if (!normalized.workspaces) normalized.workspaces = BarDefaults.createWorkspacesConfig();
        if (!normalized.barPosition) normalized.barPosition = initialBarConfig.barPosition || "top";

        var dockSeen = {};
        collectUniqueNames(dockLeftModulesList.concat(dockRightModulesList), allModuleNames, dockSeen);

        var seen = {};
        normalized.left = collectUniqueNames(normalized.left, barPlacementNames, seen);
        normalized.center = collectUniqueNames(normalized.center, barPlacementNames, seen);
        normalized.right = collectUniqueNames(normalized.right, barPlacementNames, seen);

        var inactiveNames = [];
        for (var j = 0; j < normalized.inactive.length; ++j) {
            var inactiveName = normalized.inactive[j];
            if (allModuleNames.indexOf(inactiveName) === -1) continue;
            if (seen[inactiveName] || dockSeen[inactiveName]) continue;
            seen[inactiveName] = true;
            inactiveNames.push(inactiveName);
        }
        normalized.inactive = inactiveNames;

        for (var i = 0; i < allModuleNames.length; ++i) {
            var moduleName = allModuleNames[i];
            if (!seen[moduleName] && !dockSeen[moduleName]) normalized.inactive.push(moduleName);
        }
        return normalized;
    }

    function applyBarConfig(cfg) {
        var normalized = normalizeBarConfig(cfg);
        barConfig = normalized;
        syncListModel(leftModel, normalized.left);
        syncListModel(centerModel, normalized.center);
        syncListModel(rightModel, normalized.right);
        syncListModel(inactiveModel, normalized.inactive);
    }

    function buildBarConfigFromModels() {
        var cfg = cloneValue(barConfig);
        cfg.left = getModelNames(leftModel);
        cfg.center = getModelNames(centerModel);
        cfg.right = getModelNames(rightModel);
        cfg.inactive = getModelNames(inactiveModel);
        return normalizeBarConfig(cfg);
    }

    function buildDockConfigFromModels() {
        var cfg = cloneValue(dockConfig || {});
        cfg.leftModules = getModelNames(dockLeftModel);
        cfg.rightModules = getModelNames(dockRightModel);
        return normalizeDockConfig(cfg);
    }

    function loadConfig() {
        dockConfigStore.read();
    }

    function saveConfig(onSaved) {
        var cfg = buildBarConfigFromModels();
        Log.debug("SettingsBackend", "Saving config to " + configPath);
        barConfig = cfg;
        barConfigStore.write(JSON.stringify(cfg, null, 2));
        customPresetStore.write(JSON.stringify(cfg, null, 2));
        defaultsStore.write(backend.renderBarDefaults(cfg));

        var dockCfg = buildDockConfigFromModels();
        dockConfig = dockCfg;
        dockConfigStore.write(JSON.stringify(dockCfg, null, 2));

        if (onSaved) onSaved(cfg);
    }
}
