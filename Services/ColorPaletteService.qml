pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.platform
import "./core" as Core
import "./core/Log.js" as Log
import "ThemeSchemeRegistry.js" as ThemeSchemes

Singleton {
    id: root

    IpcHandler {
        target: "materialYou"
        function status(): string {
            return JSON.stringify({
                enabled: root.enabled, live: root.liveUpdate, source: root.wallpaperSource,
                selected: root.wallpaperPath, applied: root.appliedWallpaperPath,
                detected: root.lastDesktopWallpaperPath, backend: root.autoDetectBackend,
                busy: root.isBusy, error: root.errorMessage,
                revision: root.paletteRevision, spectrum: root.spectrumColors
            });
        }
    }

    // State
    property bool available: false
    property bool enabled: false
    property bool isBusy: false
    property string errorMessage: ""
    property int paletteRevision: 0
    property bool configLoaded: false

    // Config
    property string wallpaperPath: ""
    property string wallpaperSource: "selected" // "selected" or "desktop"
    property string appliedWallpaperPath: ""
    property string lastDesktopWallpaperPath: ""
    property int manualSelectionRevision: 0
    property int paletteRequestId: 0
    property string mode: "dark"  // "dark" or "light"
    property string matugenType: "scheme-tonal-spot"
    property bool applyToKitty: true
    property bool liveUpdate: false
    property string autoDetectBackend: "unknown"
    property string pendingWallpaperPath: ""
    // A scheme can change while the wallpaper path stays the same. Keep this
    // separate from the wallpaper queue so matugen is still rerun in that case.
    property bool pendingPaletteRefresh: false

    // Extracted colors (Material You palette)
    property color primaryColor: "#6750A4"
    property color primaryOnColor: "#FFFFFF"
    property color primaryContainerColor: "#EADDFF"
    property color primaryContainerOnColor: "#21005D"
    property color primaryFixedColor: "#EADDFF"
    property color primaryFixedDimColor: "#D0BCFF"
    property color primaryFixedOnColor: "#21005D"
    property color secondaryColor: "#625B71"
    property color secondaryContainerColor: "#E8DEF8"
    property color secondaryFixedColor: "#E8DEF8"
    property color secondaryFixedDimColor: "#CCC2DC"
    property color secondaryFixedOnColor: "#1D192B"
    property color tertiaryColor: "#7D5260"
    property color tertiaryContainerColor: "#FFD8E4"
    property color tertiaryFixedColor: "#FFD8E4"
    property color tertiaryFixedDimColor: "#EFB8C8"
    property color tertiaryFixedOnColor: "#31111D"
    property color surfaceColor: "#1C1B1F"
    property color surfaceContainerColor: "#211f26"
    property color surfaceContainerHighColor: "#2b2930"
    property color surfaceOnColor: "#E6E1E5"
    property color backgroundColor: "#1C1B1F"
    property color surfaceVariantColor: "#49454F"
    property color surfaceVariantOnColor: "#CAC4D0"
    property color outlineColor: "#938F99"
    property color errorColor: "#F2B8B5"
    property color errorContainerColor: "#8C1D18"

    // Full palette from matugen
    property var fullPalette: ({})
    // Actual dominant colours sampled from the wallpaper. This complements
    // Matugen's single-source harmonic palette in Wallpaper Spectrum mode.
    property var spectrumColors: []
    property var manualAccentColors: ["", "", "", "", "", ""]
    function normalizedAccents(values) {
        var result = [];
        for (var i = 0; i < 6; ++i) {
            var value = values instanceof Array ? String(values[i] || "").trim() : "";
            result.push(/^#[0-9a-fA-F]{6}$/.test(value) ? value.toLowerCase() : "");
        }
        return result;
    }
    function setManualAccent(index, value) {
        if (index < 0 || index >= 6 || Math.floor(index) !== index) return;
        value = String(value).trim();
        if (value !== "" && !/^#[0-9a-fA-F]{6}$/.test(value)) return;
        var next = normalizedAccents(root.manualAccentColors);
        next[index] = value.toLowerCase();
        root.manualAccentColors = next;
        saveConfig();
    }
    function resetManualAccents() {
        root.manualAccentColors = ["", "", "", "", "", ""];
        saveConfig();
    }

    readonly property var colorModules: [
        {key:"launcher", label:"Launcher", icon:"󰣇"},
        {key:"cpu", label:"CPU", icon:""},
        {key:"temp", label:"Temperature", icon:""},
        {key:"activity", label:"Activity", icon:"󰨇"},
        {key:"ram", label:"Memory", icon:""},
        {key:"gpu", label:"GPU", icon:"󰢮"},
        {key:"clock", label:"Clock", icon:""},
        {key:"nightLight", label:"Night light", icon:""},
        {key:"disk", label:"Disk", icon:""},
        {key:"workspaces", label:"Workspaces", icon:"󰍹"},
        {key:"calendar", label:"Calendar", icon:""},
        {key:"notepad", label:"Notepad", icon:""},
        {key:"weather", label:"Weather", icon:"󰖐"},
        {key:"media", label:"Media", icon:""},
        {key:"equalizer", label:"Equalizer", icon:"󰺢"},
        {key:"currency", label:"Currency", icon:""},
        {key:"clipboard", label:"Clipboard", icon:""},
        {key:"notification", label:"Notifications", icon:""},
        {key:"system", label:"System", icon:""},
        {key:"power", label:"Power", icon:""},
        {key:"tray", label:"System tray", icon:"󰀻"},
        {key:"display", label:"Display", icon:"󰍹"},
        {key:"bluetooth", label:"Bluetooth", icon:""},
        {key:"battery", label:"Battery", icon:""},
        {key:"powerProfile", label:"Power profile", icon:""}
    ]
    property var moduleAccentColors: ({})
    function normalizedModuleColors(values, legacy) {
        var result = {};
        var groups = [["launcher","temp","clock","nightLight","cpu","ram","battery","system"],
            ["calendar","notepad","workspaces","notification"], ["weather","gpu","tray","display","bluetooth"],
            ["media","disk","equalizer","powerProfile"], ["currency","power"], ["clipboard"]];
        if (!values || typeof values !== "object" || values instanceof Array) {
            var previous = normalizedAccents(legacy);
            for (var i = 0; i < groups.length; ++i)
                if (previous[i]) for (var j = 0; j < groups[i].length; ++j) result[groups[i][j]] = previous[i];
            return result;
        }
        for (var k = 0; k < colorModules.length; ++k) {
            var key = colorModules[k].key;
            var value = String(values[key] || "").trim();
            if (/^#[0-9a-fA-F]{6}$/.test(value)) result[key] = value.toLowerCase();
        }
        return result;
    }
    function setModuleColor(key, value) {
        if (!colorModules.some(function(m) { return m.key === key; })) return;
        value = String(value).trim();
        if (value !== "" && !/^#[0-9a-fA-F]{6}$/.test(value)) return;
        var next = normalizedModuleColors(moduleAccentColors);
        if (value) next[key] = value.toLowerCase(); else delete next[key];
        moduleAccentColors = next;
        saveConfig();
    }
    // Restore through the same validation and persistence path as regular edits.
    function restoreModuleColors(colors) {
        moduleAccentColors = normalizedModuleColors(colors);
        saveConfig();
    }
    function resetModuleColors() {
        moduleAccentColors = ({});
        manualAccentColors = ["", "", "", "", "", ""];
        saveConfig();
    }

    signal colorsExtracted()
    signal themeApplied()

    readonly property string configPath: Core.PathService.configPath("theme_config.json")
    readonly property string scriptPath: Core.PathService.configPath("scripts/matugen-worker.sh")
    readonly property string autoDetectScriptPath: Core.PathService.configPath("scripts/get-active-wallpaper.sh")
    readonly property string waypaperConfigPath: Core.PathService.configHome + "/waypaper/config.ini"

    Component.onCompleted: {
        checkMatugen();
        loadConfig();
    }

    property string binPath: "matugen"

    // Check if matugen is installed (in PATH or ~/.cargo/bin)
    function checkMatugen() {
        matugenCheck.running = true;
    }

    Process {
        id: matugenCheck
        command: ["which", "matugen"]
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.binPath = "matugen";
                root.available = true;
                root.refreshEnabledPalette();
            } else {
                // Not in PATH? Check cargo bin
                cargoBinCheck.running = true;
            }
        }
    }

    Process {
        id: cargoBinCheck
        command: ["sh", "-c", "test -x \"$1\"", "--", (Quickshell.env("HOME") || "") + "/.cargo/bin/matugen"]
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.binPath = (Quickshell.env("HOME") || "") + "/.cargo/bin/matugen";
                root.available = true;
                root.refreshEnabledPalette();
            } else {
                root.available = false;
            }
        }
    }

    // Config load/save
    function loadConfig() {
        configStore.load();
    }

    function saveConfig() {
        var cfg = {
            materialYou: root.enabled,
            wallpaperSource: root.wallpaperSource,
            wallpaperPath: Core.PathService.compactHome(root.wallpaperPath),
            mode: root.mode,
            matugenType: root.matugenType,
            applyToKitty: root.applyToKitty,
            liveUpdate: root.liveUpdate,
            manualAccentColors: root.manualAccentColors,
            moduleAccentColors: root.moduleAccentColors
        };
        configStore.save(cfg);
    }

    readonly property var availableTypes: ThemeSchemes.ids()
    function isStaticType(t) { return ThemeSchemes.isAuthored(t); }
    function isWallpaperReactive(t) { return ThemeSchemes.isWallpaperReactive(t); }
    function schemeLabel(t) { return ThemeSchemes.label(t); }
    function schemePresentation(t) { return ThemeSchemes.presentation(t); }
    function matugenCommandType(t) { return ThemeSchemes.engineType(t); }

    function refreshEnabledPalette() {
        if (!root.configLoaded || !root.enabled || !root.available) return;
        if (root.isStaticType(root.matugenType)) {
            root.themeApplied();
        } else if (root.wallpaperSource === "desktop") {
            root.detectCurrentWallpaper();
        } else if (root.wallpaperPath.length > 0) {
            root.generateFromWallpaper(root.wallpaperPath);
        } else {
            root.useDesktopWallpaper();
        }
    }

    function selectWallpaper(path) {
        root.manualSelectionRevision += 1;
        root.wallpaperSource = "selected";
        root.generateFromWallpaper(path);
    }

    function useDesktopWallpaper() {
        root.wallpaperSource = "desktop";
        root.paletteRequestId += 1;
        root.pendingWallpaperPath = "";
        root.pendingPaletteRefresh = false;
        root.saveConfig();
        root.detectCurrentWallpaper();
    }

    // Generate colors from wallpaper
    function generateFromWallpaper(wallpaperPath) {
        if (!root.available) {
            root.errorMessage = "matugen is not installed";
            return;
        }
        if (!wallpaperPath || wallpaperPath.length === 0) {
            root.errorMessage = "No wallpaper path provided";
            return;
        }

        root.wallpaperPath = Core.PathService.expandHome(wallpaperPath);
        root.paletteRequestId += 1;
        root.saveConfig();
        root.errorMessage = "";

        // Static themes don't use matugen — just apply directly
        if (isStaticType(root.matugenType)) {
            root.themeApplied();
            saveConfig();
            return;
        }

        // Do not mutate a running Process command. Queue the latest request;
        // flushPendingWallpaper() will use the latest selected scheme.
        if (root.isBusy || matugenProc.running) {
            root.pendingWallpaperPath = root.wallpaperPath;
            root.pendingPaletteRefresh = true;
            return;
        }

        root.isBusy = true;

        matugenProc.requestId = root.paletteRequestId;
        matugenProc.wallpaper = root.wallpaperPath;
        matugenProc.command = [
            "bash",
            root.scriptPath,
            root.wallpaperPath,
            root.mode,
            root.matugenCommandType(root.matugenType),
            root.applyToKitty ? "true" : "false",
            root.binPath
        ];
        matugenProc.buf = "";
        matugenProc.errorBuf = "";
        matugenProc.running = true;
    }

    // Generate colors from a hex color
    function generateFromColor(hexColor) {
        if (!root.available) {
            root.errorMessage = "matugen is not installed";
            return;
        }

        if (matugenProc.running) {
            root.errorMessage = "Wait for the current palette to finish";
            return;
        }
        root.isBusy = true;
        root.errorMessage = "";
        root.paletteRequestId += 1;
        matugenProc.requestId = root.paletteRequestId;
        matugenProc.wallpaper = "";
        matugenProc.command = [root.binPath, "color", "hex", hexColor, "-t", root.matugenCommandType(root.matugenType), "--json", "hex"];
        matugenProc.buf = "";
        matugenProc.errorBuf = "";
        matugenProc.running = true;
    }

    Process {
        id: matugenProc
        running: false
        property int requestId: 0
        property string wallpaper: ""
        property string buf: ""
        property string errorBuf: ""
        stdout: SplitParser { onRead: data => { matugenProc.buf += data; } }
        stderr: SplitParser { onRead: data => { matugenProc.errorBuf += data; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            if (matugenProc.requestId !== root.paletteRequestId) {
                matugenProc.buf = "";
                matugenProc.errorBuf = "";
                Qt.callLater(root.flushPendingWallpaper);
                return;
            }
            if (exitCode !== 0) {
                var details = matugenProc.errorBuf.toString().trim();
                root.errorMessage = details.length > 0
                    ? "matugen failed: " + details
                    : "matugen failed (exit " + exitCode + ")";
                matugenProc.buf = "";
                matugenProc.errorBuf = "";
                Qt.callLater(root.flushPendingWallpaper);
                return;
            }
            try {
                var result = JSON.parse(matugenProc.buf);
                if (!result.colors || !result.colors.primary || !result.colors.background)
                    throw new Error("Incomplete wallpaper palette");
                root.fullPalette = result;
                root.appliedWallpaperPath = matugenProc.wallpaper;
                applyPalette(result);
                root.colorsExtracted();
            } catch(e) {
                root.errorMessage = "Failed to parse matugen output: " + e;
            }
            matugenProc.buf = "";
            matugenProc.errorBuf = "";
            Qt.callLater(root.flushPendingWallpaper);
        }
    }

    function flushPendingWallpaper() {
        if (root.isBusy || matugenProc.running || root.pendingWallpaperPath.length === 0) return;
        var nextPath = root.pendingWallpaperPath;

        root.pendingWallpaperPath = "";
        root.pendingPaletteRefresh = false;
        root.generateFromWallpaper(nextPath);
    }

    function applyPalette(palette) {
        var scheme = root.mode === "light" ? "light" : "dark";
        // matugen v2 structure: palette.colors.token.mode.color (e.g. palette.colors.primary.dark.color)
        var cols = palette && palette.colors ? palette.colors : null;
        
        if (!cols) {
            Log.warn("ColorPaletteService", "No colors found in palette");
            return;
        }

        root.spectrumColors = palette.quickshell_spectrum instanceof Array
            ? palette.quickshell_spectrum
            : [];

        // Helper to extract color safely for the current scheme (light/dark)
        function c(token) {
            if (cols[token] && cols[token][scheme] && cols[token][scheme].color) {
                return cols[token][scheme].color;
            }
            return null;
        }

        // Use the role belonging to the active light/dark scheme. In Material
        // palettes the dark-scheme primary is intentionally pale, so always
        // reading the "dark" variant made light-mode bar chips washed out.
        root.primaryColor = c("primary") || root.primaryColor;
        root.primaryOnColor = c("on_primary") || root.primaryOnColor;
        root.primaryContainerColor = c("primary_container") || root.primaryContainerColor;
        root.primaryContainerOnColor = c("on_primary_container") || root.primaryContainerOnColor;
        root.primaryFixedColor = c("primary_fixed") || root.primaryFixedColor;
        root.primaryFixedDimColor = c("primary_fixed_dim") || root.primaryFixedDimColor;
        root.primaryFixedOnColor = c("on_primary_fixed") || root.primaryFixedOnColor;
        
        root.secondaryColor = c("secondary") || root.secondaryColor;
        root.secondaryContainerColor = c("secondary_container") || root.secondaryContainerColor;
        root.secondaryFixedColor = c("secondary_fixed") || root.secondaryFixedColor;
        root.secondaryFixedDimColor = c("secondary_fixed_dim") || root.secondaryFixedDimColor;
        root.secondaryFixedOnColor = c("on_secondary_fixed") || root.secondaryFixedOnColor;
        
        root.tertiaryColor = c("tertiary") || root.tertiaryColor;
        root.tertiaryContainerColor = c("tertiary_container") || root.tertiaryContainerColor;
        root.tertiaryFixedColor = c("tertiary_fixed") || root.tertiaryFixedColor;
        root.tertiaryFixedDimColor = c("tertiary_fixed_dim") || root.tertiaryFixedDimColor;
        root.tertiaryFixedOnColor = c("on_tertiary_fixed") || root.tertiaryFixedOnColor;
        
        root.surfaceColor = c("surface") || root.surfaceColor;
        root.surfaceContainerColor = c("surface_container") || root.surfaceColor;
        root.surfaceContainerHighColor = c("surface_container_high") || c("surface_variant") || root.surfaceColor;
        root.surfaceOnColor = c("on_surface") || root.surfaceOnColor;
        root.backgroundColor = c("background") || root.backgroundColor;
        root.surfaceVariantColor = c("surface_variant") || root.surfaceVariantColor;
        root.surfaceVariantOnColor = c("on_surface_variant") || root.surfaceVariantOnColor;
        root.outlineColor = c("outline") || root.outlineColor;
        
        root.errorColor = c("error") || root.errorColor;
        root.errorContainerColor = c("error_container") || root.errorContainerColor;

        root.paletteRevision += 1;
        root.themeApplied();
        saveConfig();
    }

    // Setters
    function setEnabled(v) {
        root.enabled = v;
        saveConfig();
        if (!v) {
            root.paletteRequestId += 1;
            root.pendingWallpaperPath = "";
            root.themeApplied();
            return;
        }
        if (root.fullPalette && root.fullPalette.colors) {
            applyPalette(root.fullPalette);
        } else if (root.wallpaperPath.length > 0) {
            root.generateFromWallpaper(root.wallpaperPath);
        } else {
            root.useDesktopWallpaper();
        }
    }

    function setMode(m) {
        root.mode = m;
        if (root.fullPalette && root.fullPalette.colors) {
            applyPalette(root.fullPalette);
        } else {
            saveConfig();
        }
    }
    function setMatugenType(t) {
        if (!ThemeSchemes.isSupported(t)) {
            root.errorMessage = "Unsupported color scheme: " + t;
            return;
        }

        if (root.matugenType === t) return;
        root.matugenType = t;
        root.paletteRequestId += 1;
        root.pendingWallpaperPath = "";
        // Authored palettes currently ship as dark variants. Keeping the
        // stored mode aligned prevents the UI from claiming that a light
        // variant is active when the palette itself is unchanged.
        if (isStaticType(t)) root.mode = "dark";
        saveConfig();

        // Persist the choice while Material You is disabled, but do not spend
        // resources generating a palette that is not currently being used.
        if (!root.enabled) return;

        // Static themes don't need matugen — apply immediately
        if (isStaticType(t)) {
            root.pendingPaletteRefresh = false;
            root.themeApplied();
            return;
        }

        // Dynamic schemes must be regenerated even when the wallpaper itself
        // has not changed. If matugen is busy, generateFromWallpaper queues the
        // latest request and applies it as soon as the current run completes.
        if (root.wallpaperPath.length > 0) {
            root.generateFromWallpaper(root.wallpaperPath);
        } else {
            root.useDesktopWallpaper();
        }
    }
    function setApplyToKitty(v) { root.applyToKitty = v; saveConfig(); }
    function setLiveUpdate(v) {
        root.liveUpdate = v;
        if (v) {
            root.useDesktopWallpaper();
        } else {
            root.manualSelectionRevision += 1;
            root.wallpaperSource = "selected";
            root.saveConfig();
        }
    }

    // Auto-detect wallpaper
    Process {
        id: autoDetectProc
        command: ["bash", root.autoDetectScriptPath, "--with-backend"]
        property string output: ""
        property int selectionRevision: 0
        stdout: SplitParser { onRead: data => autoDetectProc.output += data }
        onExited: (exitCode) => {
            var detected = autoDetectProc.output.toString().trim();
            var separator = detected.indexOf("\t");
            var backend = separator >= 0 ? detected.substring(0, separator).trim() : "unknown";
            var rawPath = separator >= 0 ? detected.substring(separator + 1).trim() : detected;
            var path = Core.PathService.expandHome(rawPath);

            if (path.length > 0) {
                root.autoDetectBackend = backend;
                var desktopChanged = root.lastDesktopWallpaperPath.length > 0
                    && path !== root.lastDesktopWallpaperPath;
                root.lastDesktopWallpaperPath = path;
                // A lookup started before a manual selection must not undo it.
                // Keep observing the desktop, however: the NEXT actual wallpaper
                // change should take effect whenever Live is enabled.
                var currentSelection = autoDetectProc.selectionRevision === root.manualSelectionRevision;
                var followDesktop = root.wallpaperSource === "desktop" || (root.liveUpdate && desktopChanged);
                if (currentSelection && followDesktop
                        && (path !== root.wallpaperPath || (!root.isBusy && path !== root.appliedWallpaperPath))) {
                    root.wallpaperSource = "desktop";
                    root.generateFromWallpaper(path);
                }
            } else {
                root.autoDetectBackend = "unknown";
                root.errorMessage = "Could not detect active wallpaper";
            }
            autoDetectProc.output = "";
        }
    }

    function detectCurrentWallpaper() {
        if (autoDetectProc.running) return;
        autoDetectProc.selectionRevision = root.manualSelectionRevision;
        autoDetectProc.running = true;
    }

    Timer {
        id: wallpaperDetectDebounce
        interval: 250
        repeat: false
        onTriggered: root.detectCurrentWallpaper()
    }

    Core.FileChangeWatcher {
        path: root.waypaperConfigPath
        active: root.enabled && root.liveUpdate
        interval: 2000
        onChanged: wallpaperDetectDebounce.restart()
    }

    // Also watch the selected image itself. This covers wallpaper generators
    // that overwrite one stable filename instead of switching to a new path.
    Core.FileChangeWatcher {
        path: root.wallpaperPath
        active: root.enabled && root.liveUpdate
            && root.isWallpaperReactive(root.matugenType)
            && root.wallpaperPath.length > 0
        interval: 1500
        onChanged: wallpaperContentDebounce.restart()
    }

    Timer {
        id: wallpaperContentDebounce
        interval: 350
        repeat: false
        onTriggered: root.generateFromWallpaper(root.wallpaperPath)
    }

    // Detect changes made outside Waypaper as well. Unchanged paths do not
    // regenerate the palette; manually selected images are never polled over.
    Timer {
        interval: 2000
        running: root.configLoaded && root.enabled && root.liveUpdate
        repeat: true
        triggeredOnStart: true
        onTriggered: wallpaperDetectDebounce.restart()
    }

    Core.JsonDataStore {
        id: configStore
        path: root.configPath
        schemaVersion: 1
        defaultValue: ({
            materialYou: false,
            wallpaperSource: "selected",
            wallpaperPath: "",
            mode: "dark",
            matugenType: "scheme-tonal-spot",
            applyToKitty: true,
            liveUpdate: false,
            manualAccentColors: ["", "", "", "", "", ""]
        })
        function validate(data) {
            if (data.mode !== "dark" && data.mode !== "light") data.mode = "dark";
            if (!ThemeSchemes.isSupported(data.matugenType)) data.matugenType = "scheme-tonal-spot";
            if (typeof data.materialYou !== "boolean") data.materialYou = !!data.materialYou;
            if (typeof data.applyToKitty !== "boolean") data.applyToKitty = !!data.applyToKitty;
            delete data.applyToGtk; // Retired setting: no GTK integration exists.
            if (typeof data.liveUpdate !== "boolean") data.liveUpdate = !!data.liveUpdate;
            data.moduleAccentColors = root.normalizedModuleColors(data.moduleAccentColors, data.manualAccentColors);
            data.manualAccentColors = root.normalizedAccents(data.manualAccentColors);
            return data;
        }
        onLoadedValue: function(cfg) {
            root.moduleAccentColors = root.normalizedModuleColors(cfg.moduleAccentColors, cfg.manualAccentColors);
            root.manualAccentColors = ["", "", "", "", "", ""];
            root.enabled = cfg.materialYou || false;
            root.wallpaperPath = Core.PathService.expandHome(cfg.wallpaperPath || "");
            // Live means follow the active desktop, including after a restart.
            root.wallpaperSource = cfg.liveUpdate ? "desktop" : "selected";
            root.mode = cfg.mode || "dark";
            root.matugenType = cfg.matugenType || "scheme-tonal-spot";
            root.applyToKitty = cfg.applyToKitty !== undefined ? cfg.applyToKitty : true;
            root.liveUpdate = cfg.liveUpdate !== undefined ? cfg.liveUpdate : false;
            root.configLoaded = true;
            root.refreshEnabledPalette();
            if (root.enabled && root.liveUpdate) wallpaperDetectDebounce.restart();
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("ColorPaletteService", "Config parse error: " + details);
        }
    }
}
