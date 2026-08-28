import QtQuick
import Qt.labs.platform
import "."
import "SettingsPalette.js" as SettingsPalette
import "../BarDefaults.js" as BarDefaults
import "../ModuleRegistry.js" as ModuleRegistry
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

    readonly property var moduleInfo: ModuleRegistry.moduleInfo()
    readonly property var barPlacementNames: ModuleRegistry.namesForPlacement("bar")
    readonly property var dockPlacementNames: ModuleRegistry.namesForPlacement("dock")
    readonly property var allModuleNames: ModuleRegistry.allNames()
    readonly property var registryHealth: ModuleRegistry.validateDefinitions()

    Core.JsonDataStore {
        id: barConfigStore
        path: backend.configPath
        defaultValue: BarDefaults.clone(backend.initialBarConfig)
        onLoadedValue: function(value, rawText) {
            var cfg = backend.normalizeBarConfig(value);
            backend.applyBarConfig(cfg);
            if (rawText.trim() === "") {
                // First run: write the normalized config to disk.
                barConfigStore.save(cfg);
                customPresetStore.save(cfg);
                defaultsStore.write(backend.renderBarDefaults(cfg));
            }
        }
    }

    Core.JsonDataStore {
        id: dockConfigStore
        path: backend.dockConfigPath
        defaultValue: ({})
        onLoadedValue: function(value) {
            backend.applyDockModuleLists(value);
            barConfigStore.load();
        }
    }

    Core.FileChangeWatcher {
        id: dockConfigWatcher
        path: backend.dockConfigPath
        interval: 800
        active: true
        onChanged: dockConfigStore.load()
    }

    Core.JsonDataStore {
        id: customPresetStore
        path: backend.customPresetPath
    }

    Core.TextDataStore {
        id: defaultsStore
        path: backend.defaultsPath
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
        return ModuleRegistry.canAssignToGroup(name, groupName);
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

    function renderBarDefaults(cfg) {
        var normalized = normalizeBarConfig(cfg);
        var workspaces = normalized.workspaces || BarDefaults.createWorkspacesConfig();
        var workspaceText = JSON.stringify(workspaces, null, 4).replace(/\n/g, "\n    ");

        return ".pragma library\n\n"
            + "// Fallback only. Runtime bar changes are saved to the quickshell config directory.\n\n"
            + "function createWorkspacesConfig() {\n"
            + "    return " + workspaceText + ";\n"
            + "}\n\n"
            + "function _boolean(value, fallback) {\n"
            + "    return typeof value === \"boolean\" ? value : fallback;\n"
            + "}\n\n"
            + "function _integer(value, fallback, minimum, maximum) {\n"
            + "    var parsed = Number(value);\n"
            + "    if (!isFinite(parsed)) return fallback;\n"
            + "    return Math.max(minimum, Math.min(maximum, Math.round(parsed)));\n"
            + "}\n\n"
            + "function _choice(value, allowed, fallback) {\n"
            + "    return allowed.indexOf(value) >= 0 ? value : fallback;\n"
            + "}\n\n"
            + "function normalizeWorkspacesConfig(config) {\n"
            + "    var defaults = createWorkspacesConfig();\n"
            + "    var source = config && typeof config === \"object\" ? config : {};\n\n"
            + "    return {\n"
            + "        format: _choice(source.format, [\"chinese\", \"roman\", \"arabic\"], defaults.format),\n"
            + "        style: _choice(source.style, [\"square\", \"circle\", \"outline\", \"underline\", \"overline\", \"pipe\", \"dot\"], defaults.style),\n"
            + "        transparent: _boolean(source.transparent, defaults.transparent),\n"
            + "        displayMode: _choice(source.displayMode, [\"role\", \"occupied\", \"global\"], defaults.displayMode),\n"
            + "        workspaceCount: _integer(source.workspaceCount, defaults.workspaceCount, 1, 20),\n"
            + "        showEmpty: _boolean(source.showEmpty, defaults.showEmpty),\n"
            + "        showSpecial: _boolean(source.showSpecial, defaults.showSpecial),\n"
            + "        showApps: _boolean(source.showApps, defaults.showApps),\n"
            + "        groupApps: _boolean(source.groupApps, defaults.groupApps),\n"
            + "        scrollEnabled: _boolean(source.scrollEnabled, defaults.scrollEnabled),\n"
            + "        wrapAround: _boolean(source.wrapAround, defaults.wrapAround),\n"
            + "        reverseScroll: _boolean(source.reverseScroll, defaults.reverseScroll),\n"
            + "        iconSize: _integer(source.iconSize, defaults.iconSize, 10, 36),\n"
            + "        maxIcons: _integer(source.maxIcons, defaults.maxIcons, 1, 12)\n"
            + "    };\n"
            + "}\n\n"
            + "function createBarConfig() {\n"
            + "    return {\n"
            + "        left: " + JSON.stringify(normalized.left) + ",\n"
            + "        center: " + JSON.stringify(normalized.center) + ",\n"
            + "        right: " + JSON.stringify(normalized.right) + ",\n"
            + "        inactive: " + JSON.stringify(normalized.inactive) + ",\n"
            + "        workspaces: createWorkspacesConfig(),\n"
            + "        theme: " + JSON.stringify(normalized.theme || "") + ",\n"
            + "        barPosition: " + JSON.stringify(normalized.barPosition || "top") + ",\n"
            + "        moduleSchemaVersion: " + ModuleRegistry.schemaVersion() + "\n"
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

    function currentDockModuleNames() {
        if (dockLeftModel && dockRightModel) {
            return getModelNames(dockLeftModel).concat(getModelNames(dockRightModel));
        }
        return dockLeftModulesList.concat(dockRightModulesList);
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
        var layout = ModuleRegistry.normalizeDockLayout(normalized);
        normalized.leftModules = layout.leftModules;
        normalized.rightModules = layout.rightModules;
        normalized.moduleSchemaVersion = ModuleRegistry.schemaVersion();
        delete normalized.modules;
        return normalized;
    }

    function normalizeBarConfig(cfg) {
        var normalized = BarDefaults.clone(cfg || initialBarConfig);
        if (!Array.isArray(normalized.left)) normalized.left = [];
        if (!Array.isArray(normalized.center)) normalized.center = [];
        if (!Array.isArray(normalized.right)) normalized.right = [];
        if (!Array.isArray(normalized.inactive)) normalized.inactive = [];
        normalized.workspaces = BarDefaults.normalizeWorkspacesConfig(normalized.workspaces);
        if (!normalized.barPosition) normalized.barPosition = initialBarConfig.barPosition || "top";

        // Read the live models so moving a module from dock to bar is reflected
        // immediately, before either config file has been persisted.
        var reserved = currentDockModuleNames();
        var layout = ModuleRegistry.normalizeBarLayout(normalized, reserved);
        normalized.left = layout.left;
        normalized.center = layout.center;
        normalized.right = layout.right;
        normalized.inactive = layout.inactive;
        normalized.moduleSchemaVersion = ModuleRegistry.schemaVersion();
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
        dockConfigStore.load();
    }

    function saveConfig(onSaved) {
        var cfg = buildBarConfigFromModels();
        Log.debug("SettingsBackend", "Saving config to " + configPath);
        barConfig = cfg;
        barConfigStore.save(cfg);
        customPresetStore.save(cfg);
        defaultsStore.write(backend.renderBarDefaults(cfg));

        var dockCfg = buildDockConfigFromModels();
        dockConfig = dockCfg;
        dockConfigStore.save(dockCfg);

        if (onSaved) onSaved(cfg);
    }
}
