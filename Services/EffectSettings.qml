pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "./core" as Core
import "./core/Log.js" as Log

// Visual effect preferences (Settings → Effects), stored in effects_config.json.
// Every effect reads its switch, style and the shared speed from here.
Singleton {
    id: root

    readonly property var defaults: ({
        speed: 1.0,               // animation speed multiplier (0.25 – 3)
        liquidGlass: false,       // glass dock, bar islands, menus, toasts and OSD
        glassShimmer: true,       // light sweep across the glass
        glassDroplet: false,      // magnifying droplet under the cursor
        dropletSize: 20,          // droplet radius in pixels (10 – 40)
        launchStyle: "bounce",    // dock icon while an app starts: bounce | pulse | wiggle | none
        dockPoof: true,           // smoke puff when an icon leaves the dock
        liquidWorkspace: true,    // flowing active-workspace indicator
        popupStyle: "liquidRing", // liquidRing | genie | flip | jelly | spring | fade | none
        hoverOpen: false,         // module popups open when the pointer rests on the module
        toastStyle: "spring",     // spring | elastic | classic
        osdWave: true,            // rippling volume OSD fill
        visualizer: true          // cava equalizer next to the track title
    })

    readonly property var popupStyles: ["liquidRing", "genie", "flip", "jelly", "spring", "fade", "none"]
    readonly property var launchStyles: ["bounce", "pulse", "wiggle", "none"]
    readonly property var toastStyles: ["spring", "elastic", "classic"]

    property real speed: defaults.speed
    property bool liquidGlass: defaults.liquidGlass
    property bool glassShimmer: defaults.glassShimmer
    property bool glassDroplet: defaults.glassDroplet
    property real dropletSize: defaults.dropletSize
    property string launchStyle: defaults.launchStyle
    property bool dockPoof: defaults.dockPoof
    property bool liquidWorkspace: defaults.liquidWorkspace
    property string popupStyle: defaults.popupStyle
    property bool hoverOpen: defaults.hoverOpen
    property string toastStyle: defaults.toastStyle
    property bool osdWave: defaults.osdWave
    property bool visualizer: defaults.visualizer

    // Base duration (ms at 1×) scaled by the speed setting.
    function ms(base) {
        return Math.max(1, Math.round(base / Math.max(0.25, root.speed)));
    }

    function normalize(key, value) {
        var fallback = root.defaults[key];
        if (key === "speed") {
            var n = Number(value);
            return isFinite(n) ? Math.max(0.25, Math.min(3, Math.round(n * 20) / 20)) : fallback;
        }
        if (key === "dropletSize") {
            var px = Number(value);
            return isFinite(px) ? Math.max(10, Math.min(40, Math.round(px))) : fallback;
        }
        if (key === "popupStyle") return root.popupStyles.indexOf(value) !== -1 ? value : fallback;
        if (key === "launchStyle") return root.launchStyles.indexOf(value) !== -1 ? value : fallback;
        if (key === "toastStyle") return root.toastStyles.indexOf(value) !== -1 ? value : fallback;
        return typeof value === "boolean" ? value : fallback;
    }

    function set(key, value) {
        if (!(key in root.defaults)) return;
        root[key] = normalize(key, value);
        save();
    }

    function save() {
        var obj = {};
        for (var key in root.defaults) obj[key] = root[key];
        store.save(obj);
    }

    Core.JsonDataStore {
        id: store
        path: Core.PathService.configPath("effects_config.json")
        defaultValue: root.defaults
        onLoadedValue: function(cfg, rawText) {
            // Earlier versions stored on/off switches instead of styles.
            if (cfg.popupStyle === undefined && cfg.popupReveal === false) cfg.popupStyle = "none";
            if (cfg.launchStyle === undefined && cfg.launchBounce === false) cfg.launchStyle = "none";
            if (cfg.toastStyle === undefined && cfg.springToasts === false) cfg.toastStyle = "classic";
            for (var key in root.defaults)
                root[key] = cfg[key] !== undefined ? root.normalize(key, cfg[key]) : root.defaults[key];
            // First run: carry over the glass switch that used to live in the dock config.
            if (String(rawText || "").trim() === "") legacyDockConfig.reload();
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("EffectSettings", "Config parse error: " + details);
        }
    }

    FileView {
        id: legacyDockConfig
        path: Core.PathService.configPath("dock_config.json")
        preload: false
        onLoaded: {
            try {
                if (JSON.parse(text()).liquidGlass === true) root.set("liquidGlass", true);
                else root.save();
            } catch (e) {
                root.save();
            }
        }
        onLoadFailed: root.save()
    }

    Component.onCompleted: store.load()
}
