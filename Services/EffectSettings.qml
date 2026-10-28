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
        visualizer: true,         // cava equalizer next to the track title
        // Hyprland window effects (0.57+), applied by HyprEffectsService.
        hyprBlur: false,          // blur behind transparent windows
        hyprBlurStyle: "kawase",  // one of hyprBlurStyles
        hyprBlurSize: 9,          // blur radius (1 – 30)
        hyprBlurPasses: 3,        // blur passes (1 – 6)
        hyprWobble: false,        // wobbly windows while moving or resizing
        hyprWobbleIntensity: 0.2, // 0.05 – 1
        hyprWobbleStiffness: 200, // 50 – 600
        hyprWobbleDamping: 12,    // 2 – 40
        hyprWobbleScope: "all"    // all | primary (only the primary-role monitor wobbles)
    })

    readonly property var popupStyles: ["liquidRing", "genie", "flip", "jelly", "spring", "fade", "none"]
    readonly property var launchStyles: ["bounce", "pulse", "wiggle", "none"]
    readonly property var toastStyles: ["spring", "elastic", "classic"]
    readonly property var hyprBlurStyles: ["kawase", "frost", "acrylic", "prism", "haze", "aurora",
                                           "ripple", "water", "drops", "heat_shimmer", "fluid_jar"]
    readonly property var hyprWobbleScopes: ["all", "primary"]
    readonly property var numericRanges: ({
        hyprBlurSize: [1, 30, 1], hyprBlurPasses: [1, 6, 1],
        hyprWobbleIntensity: [0.05, 1, 0.05], hyprWobbleStiffness: [50, 600, 10], hyprWobbleDamping: [2, 40, 1]
    })

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
    property bool hyprBlur: defaults.hyprBlur
    property string hyprBlurStyle: defaults.hyprBlurStyle
    property real hyprBlurSize: defaults.hyprBlurSize
    property real hyprBlurPasses: defaults.hyprBlurPasses
    property bool hyprWobble: defaults.hyprWobble
    property real hyprWobbleIntensity: defaults.hyprWobbleIntensity
    property real hyprWobbleStiffness: defaults.hyprWobbleStiffness
    property real hyprWobbleDamping: defaults.hyprWobbleDamping
    property string hyprWobbleScope: defaults.hyprWobbleScope

    property bool loaded: false

    // Emitted after a Hyprland window-effect key is loaded or changed.
    signal hyprEffectsChanged()

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
        if (key === "hyprBlurStyle") return root.hyprBlurStyles.indexOf(value) !== -1 ? value : fallback;
        if (key === "hyprWobbleScope") return root.hyprWobbleScopes.indexOf(value) !== -1 ? value : fallback;
        if (key in root.numericRanges) {
            var range = root.numericRanges[key];
            var v = Number(value);
            if (!isFinite(v)) return fallback;
            v = Math.round(v / range[2]) * range[2];
            return Math.max(range[0], Math.min(range[1], Math.round(v * 100) / 100));
        }
        return typeof value === "boolean" ? value : fallback;
    }

    function set(key, value) {
        if (!(key in root.defaults)) return;
        root[key] = normalize(key, value);
        save();
        if (key.indexOf("hypr") === 0) root.hyprEffectsChanged();
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
            root.loaded = true;
            root.hyprEffectsChanged();
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
