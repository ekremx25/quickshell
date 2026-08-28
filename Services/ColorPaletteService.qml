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

    // State
    property bool available: false
    property bool enabled: false
    property bool isBusy: false
    property string errorMessage: ""
    property int paletteRevision: 0
    property bool configLoaded: false

    // Config
    property string wallpaperPath: ""
    property string mode: "dark"  // "dark" or "light"
    property string matugenType: "scheme-tonal-spot"
    property bool applyToKitty: true
    property bool applyToGtk: false
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
            wallpaperPath: Core.PathService.compactHome(root.wallpaperPath),
            mode: root.mode,
            matugenType: root.matugenType,
            applyToKitty: root.applyToKitty,
            applyToGtk: root.applyToGtk,
            liveUpdate: root.liveUpdate
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
        } else if (root.wallpaperPath.length > 0) {
            root.generateFromWallpaper(root.wallpaperPath);
        } else {
            root.detectCurrentWallpaper();
        }
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

        matugenProc.command = [
            "bash",
            root.scriptPath,
            root.wallpaperPath,
            root.mode,
            root.matugenCommandType(root.matugenType),
            root.applyToKitty ? "true" : "false"
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

        root.isBusy = true;
        root.errorMessage = "";

        matugenProc.command = [root.binPath, "color", "hex", hexColor, "-t", root.matugenCommandType(root.matugenType), "--json", "hex"];
        matugenProc.buf = "";
        matugenProc.errorBuf = "";
        matugenProc.running = true;
    }

    Process {
        id: matugenProc
        running: false
        property string buf: ""
        property string errorBuf: ""
        stdout: SplitParser { onRead: data => { matugenProc.buf += data; } }
        stderr: SplitParser { onRead: data => { matugenProc.errorBuf += data; } }
        onExited: (exitCode) => {
            root.isBusy = false;
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
                root.fullPalette = result;
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
        var forceRefresh = root.pendingPaletteRefresh;
        root.pendingWallpaperPath = "";
        root.pendingPaletteRefresh = false;
        if (forceRefresh || nextPath !== root.wallpaperPath) root.generateFromWallpaper(nextPath);
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
            root.themeApplied();
            return;
        }
        if (root.fullPalette && root.fullPalette.colors) {
            applyPalette(root.fullPalette);
        } else if (root.wallpaperPath.length > 0) {
            root.generateFromWallpaper(root.wallpaperPath);
        } else {
            root.detectCurrentWallpaper();
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
            root.detectCurrentWallpaper();
        }
    }
    function setApplyToKitty(v) { root.applyToKitty = v; saveConfig(); }
    function setApplyToGtk(v) { root.applyToGtk = v; saveConfig(); }
    function setLiveUpdate(v) {
        root.liveUpdate = v;
        saveConfig();
        if (v) wallpaperDetectDebounce.restart();
    }

    // Auto-detect wallpaper
    Process {
        id: autoDetectProc
        command: ["bash", root.autoDetectScriptPath, "--with-backend"]
        property string output: ""
        stdout: SplitParser { onRead: data => autoDetectProc.output += data }
        onExited: (exitCode) => {
            var detected = autoDetectProc.output.toString().trim();
            var separator = detected.indexOf("\t");
            var backend = separator >= 0 ? detected.substring(0, separator).trim() : "unknown";
            var rawPath = separator >= 0 ? detected.substring(separator + 1).trim() : detected;
            var path = Core.PathService.expandHome(rawPath);

            if (path.length > 0) {
                root.autoDetectBackend = backend;
                root.errorMessage = "";
                if (path !== root.wallpaperPath) {
                    if (root.isBusy || matugenProc.running) {
                        root.pendingWallpaperPath = path;
                    } else {
                        root.generateFromWallpaper(path);
                    }
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
        active: root.enabled && root.liveUpdate && root.autoDetectBackend === "waypaper"
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

    // swww and swaybg do not expose a portable config file to watch. Keep a
    // slower safety check for those backends; unchanged paths no longer invoke
    // matugen, so this remains inexpensive.
    Timer {
        interval: 15000
        running: root.enabled && root.liveUpdate && root.autoDetectBackend !== "waypaper"
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
            wallpaperPath: "",
            mode: "dark",
            matugenType: "scheme-tonal-spot",
            applyToKitty: true,
            applyToGtk: false,
            liveUpdate: false
        })
        function validate(data) {
            if (data.mode !== "dark" && data.mode !== "light") data.mode = "dark";
            if (!ThemeSchemes.isSupported(data.matugenType)) data.matugenType = "scheme-tonal-spot";
            if (typeof data.materialYou !== "boolean") data.materialYou = !!data.materialYou;
            if (typeof data.applyToKitty !== "boolean") data.applyToKitty = !!data.applyToKitty;
            if (typeof data.applyToGtk !== "boolean") data.applyToGtk = !!data.applyToGtk;
            if (typeof data.liveUpdate !== "boolean") data.liveUpdate = !!data.liveUpdate;
            return data;
        }
        onLoadedValue: function(cfg) {
            root.enabled = cfg.materialYou || false;
            root.wallpaperPath = Core.PathService.expandHome(cfg.wallpaperPath || "");
            root.mode = cfg.mode || "dark";
            root.matugenType = cfg.matugenType || "scheme-tonal-spot";
            root.applyToKitty = cfg.applyToKitty !== undefined ? cfg.applyToKitty : true;
            root.applyToGtk = cfg.applyToGtk !== undefined ? cfg.applyToGtk : false;
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
