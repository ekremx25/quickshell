.pragma library

// ModuleRegistry is the single source of truth for module identity, metadata
// and placement policy. Visual construction deliberately lives in
// ModuleCatalog.qml so metadata consumers never instantiate heavy QML objects.

var SCHEMA_VERSION = 3;
var _allowedPlacements = ["bar", "dock"];
var _allowedCategories = ["core", "productivity", "system", "connectivity", "media"];

var _modules = [
    {
        id: "launcher",
        name: "Launcher",
        component: "Launcher",
        icon: "\ue7e6",
        label: "Launcher",
        description: "Application launcher and shell settings entry point.",
        category: "core",
        color: "#1e66f5",
        placements: ["bar", "dock"],
        settingsPage: "bar",
        services: ["LauncherService"],
        contexts: ["launcherLogo", "settingsMenu"]
    },
    {
        id: "calendar",
        name: "Calendar",
        component: "Calendar",
        icon: "",
        label: "Calendar",
        description: "Calendar, notes and event countdown.",
        category: "productivity",
        color: "#f5c2e7",
        placements: ["bar", "dock"],
        settingsPage: "",
        services: ["CalendarBackend", "CalendarNotesService", "CountdownService"],
        contexts: []
    },
    {
        id: "notepad",
        name: "Notepad",
        component: "Notepad",
        icon: "󰠮",
        label: "Notepad",
        description: "Autosaving quick notes.",
        category: "productivity",
        color: "#f9e2af",
        placements: ["bar", "dock"],
        settingsPage: "",
        services: ["NotepadService"],
        contexts: []
    },
    {
        id: "workspaces",
        name: "Workspaces",
        component: "Workspaces",
        icon: "",
        label: "Workspaces",
        description: "Compositor-aware workspace switcher.",
        category: "core",
        color: "#cba6f7",
        placements: ["bar", "dock"],
        settingsPage: "workspaces",
        services: ["WorkspaceService", "CompositorService", "ScreenManager"],
        contexts: ["screenData", "workspacesConfig"]
    },
    {
        id: "notifications",
        name: "Notifications",
        component: "Notifications",
        icon: "󰂚",
        label: "Notifications",
        description: "Notification history and do-not-disturb controls.",
        category: "system",
        color: "#fab387",
        placements: ["bar"],
        settingsPage: "notifications",
        services: ["Notifications"],
        contexts: []
    },
    {
        id: "weather",
        name: "Weather",
        component: "Weather",
        icon: "󰖕",
        label: "Weather",
        description: "Current weather conditions and forecast.",
        category: "connectivity",
        color: "#f9e2af",
        placements: ["bar", "dock"],
        settingsPage: "weather",
        services: ["WeatherDataScope"],
        contexts: []
    },
    {
        id: "volume",
        name: "Volume",
        component: "Volume",
        icon: "󰕾",
        label: "Volume",
        description: "Audio output and volume controls.",
        category: "media",
        color: "#89b4fa",
        placements: ["bar", "dock"],
        settingsPage: "sound",
        services: ["Pipewire", "Volume"],
        contexts: []
    },
    {
        id: "equalizer",
        name: "Equalizer",
        component: "Equalizer",
        icon: "󱞙",
        label: "Equalizer",
        description: "PipeWire parametric equalizer controls.",
        category: "media",
        color: "#89dceb",
        placements: ["bar"],
        settingsPage: "sound",
        services: ["EqualizerBackend", "Pipewire", "Mpris"],
        contexts: []
    },
    {
        id: "tray",
        name: "Tray",
        component: "Tray",
        icon: "󰇚",
        label: "Tray",
        description: "StatusNotifierItem system tray.",
        category: "system",
        color: "#a6adc8",
        placements: ["bar", "dock"],
        settingsPage: "bar",
        services: ["SystemTray"],
        contexts: []
    },
    {
        id: "clipboard",
        name: "Clipboard",
        component: "Clipboard",
        icon: "󰅍",
        label: "Clipboard",
        description: "Searchable clipboard history.",
        category: "productivity",
        color: "#fab387",
        placements: ["bar", "dock"],
        settingsPage: "bar",
        services: ["ClipboardBackend"],
        contexts: []
    },
    {
        id: "power",
        name: "Power",
        component: "Power",
        icon: "⏻",
        label: "Power",
        description: "Session and system power actions.",
        category: "system",
        color: "#f38ba8",
        placements: ["bar", "dock"],
        settingsPage: "bar",
        services: [],
        contexts: []
    },
    {
        id: "night-light",
        name: "NightLight",
        component: "NightLight",
        icon: "󰽥",
        label: "Night Light",
        description: "Blue-light temperature control.",
        category: "system",
        color: "#f9a03c",
        placements: ["bar"],
        settingsPage: "nightlight",
        services: ["NightLight"],
        contexts: []
    },
    {
        id: "power-group",
        name: "PowerGroup",
        component: "PowerGroup",
        icon: "",
        label: "Power Group",
        description: "Battery and power-profile summary.",
        category: "system",
        color: "#a6e3a1",
        placements: ["bar"],
        settingsPage: "bar",
        services: ["BatteryService", "PowerProfileService"],
        contexts: []
    },
    {
        id: "system-info-group",
        name: "SysInfoGroup",
        component: "SysInfoGroup",
        icon: "",
        label: "System Group",
        description: "Combined CPU, GPU, temperature and disk status.",
        category: "system",
        color: "#f9e2af",
        placements: ["bar"],
        settingsPage: "sysinfo",
        services: ["TempBackend", "GpuBackend", "DiskService"],
        contexts: []
    },
    {
        id: "memory",
        name: "RamModule",
        component: "RamModule",
        icon: "󰘚",
        label: "Memory",
        description: "Live memory usage indicator.",
        category: "system",
        color: "#a6e3a1",
        placements: ["bar"],
        settingsPage: "sysinfo",
        services: ["RamBackend"],
        contexts: []
    },
    {
        id: "media",
        name: "Media",
        component: "MediaWidget",
        icon: "♫",
        label: "Media",
        description: "MPRIS media playback controls.",
        category: "media",
        color: "#f5c2e7",
        placements: ["dock"],
        settingsPage: "dock",
        services: ["Mpris"],
        contexts: ["dockScale"]
    },
    {
        id: "currency-converter",
        name: "CurrencyConverter",
        component: "CurrencyConverter",
        icon: "󰩩",
        label: "Currency Converter",
        description: "Quick currency conversion with selectable source and target currencies.",
        category: "connectivity",
        color: "#a6e3a1",
        placements: ["bar", "dock"],
        allowCrossPlacementDuplicate: true,
        settingsPage: "markets",
        services: ["Markets"],
        contexts: []
    }
];

// Aliases are migrations, not presentation labels. Never remove an alias while
// an older config may still contain it.
var _aliases = ({
    "RAM": "RamModule",
    "ram": "RamModule",
    "Memory": "RamModule",
    "SystemInfoGroup": "SysInfoGroup"
});

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function schemaVersion() {
    return SCHEMA_VERSION;
}

function canonicalName(value) {
    var token = String(value || "").trim();
    if (token.length === 0) return "";
    if (_aliases[token]) return _aliases[token];

    var lower = token.toLowerCase();
    for (var i = 0; i < _modules.length; ++i) {
        if (_modules[i].name === token || _modules[i].id === lower) return _modules[i].name;
    }
    return token;
}

function _definitionRef(value) {
    var canonical = canonicalName(value);
    for (var i = 0; i < _modules.length; ++i) {
        if (_modules[i].name === canonical) return _modules[i];
    }
    return null;
}

function definitions() {
    return clone(_modules);
}

function definition(value) {
    var entry = _definitionRef(value);
    return entry ? clone(entry) : null;
}

function allNames() {
    var names = [];
    for (var i = 0; i < _modules.length; ++i) names.push(_modules[i].name);
    return names;
}

function allIds() {
    var ids = [];
    for (var i = 0; i < _modules.length; ++i) ids.push(_modules[i].id);
    return ids;
}

function namesForPlacement(placement) {
    var names = [];
    for (var i = 0; i < _modules.length; ++i) {
        if (_modules[i].placements.indexOf(placement) !== -1) names.push(_modules[i].name);
    }
    return names;
}

function supportsPlacement(value, placement) {
    var entry = _definitionRef(value);
    return !!entry && entry.placements.indexOf(placement) !== -1;
}

function placementForGroup(groupName) {
    if (groupName === "dockLeft" || groupName === "dockRight") return "dock";
    if (groupName === "left" || groupName === "center" || groupName === "right") return "bar";
    if (groupName === "inactive") return "inactive";
    return "";
}

function canAssignToGroup(value, groupName) {
    var placement = placementForGroup(groupName);
    if (placement === "inactive") return _definitionRef(value) !== null;
    return placement.length > 0 && supportsPlacement(value, placement);
}

function moduleInfo() {
    var info = ({});
    for (var i = 0; i < _modules.length; ++i) {
        var entry = _modules[i];
        info[entry.name] = clone(entry);
    }
    return info;
}

function normalizeNames(list, placement, seen) {
    var output = [];
    var safeSeen = seen || ({});
    if (!Array.isArray(list)) return output;

    for (var i = 0; i < list.length; ++i) {
        var name = canonicalName(list[i]);
        if (safeSeen[name]) continue;
        if (placement === "inactive") {
            if (_definitionRef(name) === null) continue;
        } else if (!supportsPlacement(name, placement)) {
            continue;
        }
        safeSeen[name] = true;
        output.push(name);
    }
    return output;
}

function markKnownNames(list, seen) {
    var safeSeen = seen || ({});
    if (!Array.isArray(list)) return safeSeen;
    for (var i = 0; i < list.length; ++i) {
        var name = canonicalName(list[i]);
        if (_definitionRef(name)) safeSeen[name] = true;
    }
    return safeSeen;
}

function allowsCrossPlacementDuplicate(value) {
    var entry = _definitionRef(value);
    return !!entry && entry.allowCrossPlacementDuplicate === true;
}

function markReservedNames(list, seen) {
    var safeSeen = seen || ({});
    if (!Array.isArray(list)) return safeSeen;
    for (var i = 0; i < list.length; ++i) {
        var name = canonicalName(list[i]);
        if (_definitionRef(name) && !allowsCrossPlacementDuplicate(name)) {
            safeSeen[name] = true;
        }
    }
    return safeSeen;
}

function normalizeZoneMap(source, zoneNames, placement, seen) {
    var normalized = ({});
    var safeSource = source || ({});
    var safeSeen = seen || ({});
    for (var i = 0; i < zoneNames.length; ++i) {
        var zoneName = zoneNames[i];
        normalized[zoneName] = normalizeNames(safeSource[zoneName], placement, safeSeen);
    }
    return normalized;
}

// Returns only layout fields. Callers merge them into their config object so
// module migration never discards unrelated settings.
function normalizeBarLayout(config, reservedNames) {
    var source = config || ({});
    var seen = ({});
    // Most modules move between bar and dock. Explicitly repeatable modules
    // remain independently available in both placements.
    markReservedNames(reservedNames, seen);

    var zones = normalizeZoneMap(source, ["left", "center", "right"], "bar", seen);
    zones.inactive = normalizeNames(source.inactive, "inactive", seen);

    for (var i = 0; i < _modules.length; ++i) {
        var name = _modules[i].name;
        if (!seen[name]) {
            seen[name] = true;
            zones.inactive.push(name);
        }
    }
    return zones;
}

function normalizeDockLayout(config) {
    var source = config || ({});
    var seen = ({});
    var zones = normalizeZoneMap({
        leftModules: source.leftModules,
        rightModules: source.rightModules
    }, ["leftModules", "rightModules"], "dock", seen);

    // One-time migration from the original single dock module list.
    if (zones.leftModules.length === 0 && zones.rightModules.length === 0) {
        var legacy = normalizeNames(source.modules, "dock");
        if (legacy.length > 0) {
            zones.leftModules = legacy.indexOf("Weather") !== -1 ? ["Weather"] : [];
            zones.rightModules = [];
            for (var i = 0; i < legacy.length; ++i) {
                if (legacy[i] !== "Weather" && legacy[i] !== "Launcher") {
                    zones.rightModules.push(legacy[i]);
                }
            }
        }
    }
    return zones;
}

function validateDefinitions(candidateModules, candidateAliases) {
    var modules = candidateModules === undefined ? _modules : candidateModules;
    var aliases = candidateAliases === undefined ? _aliases : candidateAliases;
    var errors = [];
    var warnings = [];
    var names = ({});
    var ids = ({});
    var components = ({});

    if (!Array.isArray(modules)) {
        return { valid: false, errors: ["Registry definitions must be an array."], warnings: [], count: 0 };
    }

    for (var i = 0; i < modules.length; ++i) {
        var entry = modules[i];
        var prefix = "Module #" + i;
        if (!entry || typeof entry !== "object") {
            errors.push(prefix + " must be an object.");
            continue;
        }

        var requiredStrings = ["id", "name", "component", "icon", "label", "description", "category", "color", "settingsPage"];
        for (var r = 0; r < requiredStrings.length; ++r) {
            var field = requiredStrings[r];
            if (typeof entry[field] !== "string") errors.push(prefix + "." + field + " must be a string.");
        }

        if (typeof entry.id === "string") {
            if (!/^[a-z][a-z0-9-]*$/.test(entry.id)) errors.push(prefix + ".id is not a stable kebab-case id: " + entry.id);
            if (ids[entry.id]) errors.push("Duplicate module id: " + entry.id);
            ids[entry.id] = true;
        }
        if (typeof entry.name === "string") {
            if (!entry.name.length) errors.push(prefix + ".name cannot be empty.");
            if (names[entry.name]) errors.push("Duplicate module name: " + entry.name);
            names[entry.name] = true;
        }
        if (typeof entry.component === "string") {
            if (!entry.component.length) errors.push(prefix + ".component cannot be empty.");
            if (components[entry.component]) errors.push("Duplicate component key: " + entry.component);
            components[entry.component] = true;
        }
        if (typeof entry.color === "string" && !/^#[0-9a-fA-F]{6}$/.test(entry.color)) {
            errors.push(prefix + ".color must use #RRGGBB format.");
        }
        if (typeof entry.category === "string" && _allowedCategories.indexOf(entry.category) === -1) {
            warnings.push(prefix + " uses unknown category: " + entry.category);
        }

        var arrayFields = ["placements", "services", "contexts"];
        for (var a = 0; a < arrayFields.length; ++a) {
            if (!Array.isArray(entry[arrayFields[a]])) errors.push(prefix + "." + arrayFields[a] + " must be an array.");
        }
        if (Array.isArray(entry.placements)) {
            if (entry.placements.length === 0) errors.push(prefix + ".placements cannot be empty.");
            var placementSeen = ({});
            for (var p = 0; p < entry.placements.length; ++p) {
                var placement = entry.placements[p];
                if (_allowedPlacements.indexOf(placement) === -1) errors.push(prefix + " uses unknown placement: " + placement);
                if (placementSeen[placement]) errors.push(prefix + " repeats placement: " + placement);
                placementSeen[placement] = true;
            }
        }
    }

    var aliasKeys = aliases && typeof aliases === "object" ? Object.keys(aliases) : [];
    if (aliases !== null && typeof aliases !== "object") errors.push("Registry aliases must be an object.");
    for (var k = 0; k < aliasKeys.length; ++k) {
        var alias = aliasKeys[k];
        var target = aliases[alias];
        if (!alias.length) errors.push("Registry alias cannot be empty.");
        if (!names[target]) errors.push("Alias " + alias + " targets unknown module: " + target);
        if (names[alias]) warnings.push("Alias shadows a canonical module name: " + alias);
    }

    return { valid: errors.length === 0, errors: errors, warnings: warnings, count: modules.length };
}

function validateCatalog(componentMap) {
    var errors = [];
    var warnings = [];
    var safeMap = componentMap || ({});
    var registryNames = allNames();

    for (var i = 0; i < registryNames.length; ++i) {
        if (!safeMap[registryNames[i]]) errors.push("Catalog component is missing: " + registryNames[i]);
    }

    var catalogNames = Object.keys(safeMap);
    for (var j = 0; j < catalogNames.length; ++j) {
        if (_definitionRef(catalogNames[j]) === null) warnings.push("Catalog contains an unregistered component: " + catalogNames[j]);
    }

    return {
        valid: errors.length === 0,
        errors: errors,
        warnings: warnings,
        registryCount: registryNames.length,
        catalogCount: catalogNames.length
    };
}
