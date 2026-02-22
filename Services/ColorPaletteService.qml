pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.platform

Singleton {
    id: root

    // State
    property bool available: false
    property bool enabled: false
    property bool isBusy: false
    property string errorMessage: ""

    // Config
    property string wallpaperPath: ""
    property string mode: "dark"  // "dark" or "light"
    property string matugenType: "scheme-tonal-spot"
    property bool applyToKitty: true
    property bool applyToGtk: false
    property bool liveUpdate: false

    // Extracted colors (Material You palette)
    property color primaryColor: "#6750A4"
    property color primaryOnColor: "#FFFFFF"
    property color primaryContainerColor: "#EADDFF"
    property color primaryContainerOnColor: "#21005D"
    property color secondaryColor: "#625B71"
    property color secondaryContainerColor: "#E8DEF8"
    property color tertiaryColor: "#7D5260"
    property color tertiaryContainerColor: "#FFD8E4"
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

    signal colorsExtracted()
    signal themeApplied()

    readonly property string configPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/theme_config.json"
    readonly property string scriptPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/scripts/matugen-worker.sh"
    readonly property string autoDetectScriptPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/scripts/get-active-wallpaper.sh"

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
                console.log("[ColorPaletteService] matugen found in PATH");
            } else {
                // Not in PATH? Check cargo bin
                cargoBinCheck.running = true;
            }
        }
    }

    Process {
        id: cargoBinCheck
        command: ["sh", "-c", "test -x $HOME/.cargo/bin/matugen"]
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.binPath = "$HOME/.cargo/bin/matugen";
                root.available = true;
                console.log("[ColorPaletteService] matugen found in ~/.cargo/bin");
            } else {
                root.available = false;
                console.log("[ColorPaletteService] matugen not found — Material You disabled");
            }
        }
    }

    // Config load/save
    function loadConfig() {
        readConfigProc.output = "";
        readConfigProc.running = true;
    }

    Process {
        id: readConfigProc
        command: ["cat", root.configPath]
        property string output: ""
        stdout: SplitParser { onRead: data => { readConfigProc.output += data; } }
        onExited: {
            try {
                var cfg = JSON.parse(readConfigProc.output);
                root.enabled = cfg.materialYou || false;
                root.wallpaperPath = cfg.wallpaperPath || "";
                root.mode = cfg.mode || "dark";
                root.matugenType = cfg.matugenType || "scheme-tonal-spot";
                root.applyToKitty = cfg.applyToKitty !== undefined ? cfg.applyToKitty : true;
                root.applyToGtk = cfg.applyToGtk !== undefined ? cfg.applyToGtk : false;
                root.liveUpdate = cfg.liveUpdate !== undefined ? cfg.liveUpdate : false;
            } catch(e) {
                console.log("[ColorPaletteService] Config parse error: " + e);
            }
            readConfigProc.output = "";
        }
    }

    function saveConfig() {
        var cfg = {
            materialYou: root.enabled,
            wallpaperPath: root.wallpaperPath,
            mode: root.mode,
            matugenType: root.matugenType,
            applyToKitty: root.applyToKitty,
            applyToGtk: root.applyToGtk,
            liveUpdate: root.liveUpdate
        };
        writeConfigProc.jsonData = JSON.stringify(cfg, null, 2);
        writeConfigProc.running = false;
        writeConfigProc.running = true;
    }

    Process {
        id: writeConfigProc
        property string jsonData: ""
        command: ["bash", "-c", "cat > " + root.configPath + " << 'ENDOFJSON'\n" + jsonData + "\nENDOFJSON"]
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

        root.wallpaperPath = wallpaperPath;
        root.errorMessage = "";

        // Static themes don't use matugen — just apply directly
        if (isStaticType(root.matugenType)) {
            root.themeApplied();
            saveConfig();
            return;
        }

        root.isBusy = true;

        // Escape single quotes primarily, as we wraps the path in single quotes for bash
        var escaped = "'" + wallpaperPath.replace(/'/g, "'\\''") + "'";
        matugenProc.command = ["bash", "-c", root.binPath + " image " + escaped + " -t " + root.matugenType + " --json hex --source-color-index 0 2>/dev/null"];
        matugenProc.buf = "";
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

        var escaped = "'" + hexColor.replace(/'/g, "'\\''") + "'";
        matugenProc.command = ["bash", "-c", root.binPath + " color hex " + escaped + " -t " + root.matugenType + " --json hex 2>/dev/null"];
        matugenProc.buf = "";
        matugenProc.running = true;
    }

    Process {
        id: matugenProc
        running: false
        property string buf: ""
        stdout: SplitParser { onRead: data => { matugenProc.buf += data; } }
        onExited: (exitCode) => {
            root.isBusy = false;
            if (exitCode !== 0) {
                root.errorMessage = "matugen failed (exit " + exitCode + ")";
                matugenProc.buf = "";
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
        }
    }

    function applyPalette(palette) {
        var scheme = root.mode === "light" ? "light" : "dark";
        // matugen v2 structure: palette.colors.token.mode.color (e.g. palette.colors.primary.dark.color)
        var cols = palette && palette.colors ? palette.colors : null;
        
        if (!cols) {
            console.log("[ColorPaletteService] No colors found in palette");
            return;
        }

        // Helper to extract color safely for the current scheme (light/dark)
        function c(token) {
            if (cols[token] && cols[token][scheme] && cols[token][scheme].color) {
                return cols[token][scheme].color;
            }
            return null;
        }

        // Helper to always extract the 'dark' variant for vibrant base colors
        function cVivid(token) {
            if (cols[token] && cols[token]["dark"] && cols[token]["dark"].color) {
                return cols[token]["dark"].color;
            }
            // Fallback to current scheme if dark fails
            return c(token);
        }

        // ALWAYS USE VIVID (DARK) COLORS FOR BASES SO THEY POP IN LIGHT MODE
        root.primaryColor = cVivid("primary") || root.primaryColor;
        root.primaryOnColor = c("on_primary") || root.primaryOnColor;
        root.primaryContainerColor = c("primary_container") || root.primaryContainerColor;
        root.primaryContainerOnColor = c("on_primary_container") || root.primaryContainerOnColor;
        
        root.secondaryColor = cVivid("secondary") || root.secondaryColor;
        root.secondaryContainerColor = c("secondary_container") || root.secondaryContainerColor;
        
        root.tertiaryColor = cVivid("tertiary") || root.tertiaryColor;
        root.tertiaryContainerColor = c("tertiary_container") || root.tertiaryContainerColor;
        
        root.surfaceColor = c("surface") || root.surfaceColor;
        root.surfaceOnColor = c("on_surface") || root.surfaceOnColor;
        root.backgroundColor = c("background") || root.backgroundColor;
        root.surfaceVariantColor = c("surface_variant") || root.surfaceVariantColor;
        root.surfaceVariantOnColor = c("on_surface_variant") || root.surfaceVariantOnColor;
        root.outlineColor = c("outline") || root.outlineColor;
        
        root.errorColor = cVivid("error") || root.errorColor;
        root.errorContainerColor = c("error_container") || root.errorContainerColor;

        root.themeApplied();
        saveConfig();
    }

    // Setters
    function setEnabled(v) { root.enabled = v; saveConfig(); }
    function setMode(m) { root.mode = m; saveConfig(); if (root.fullPalette && root.fullPalette.colors) applyPalette(root.fullPalette); }
    // Static (non-matugen) scheme types
    readonly property var staticTypes: ["scheme-catppuccin", "scheme-kanagawa", "scheme-tokyo-night"]
    function isStaticType(t) { return staticTypes.indexOf(t) >= 0; }

    function setMatugenType(t) {
        root.matugenType = t;
        saveConfig();
        // Static themes don't need matugen — apply immediately
        if (isStaticType(t)) {
            root.themeApplied();
        }
    }
    function setApplyToKitty(v) { root.applyToKitty = v; saveConfig(); }
    function setApplyToGtk(v) { root.applyToGtk = v; saveConfig(); }
    function setLiveUpdate(v) { root.liveUpdate = v; saveConfig(); }

    // Available matugen types
    readonly property var availableTypes: [
        "scheme-tonal-spot",
        "scheme-neutral",
        "scheme-fidelity",
        "scheme-vibrant",
        "scheme-expressive",
        "scheme-fruit-salad",
        "scheme-rainbow",
        "scheme-monochrome",
        "scheme-content",
        "scheme-catppuccin",
        "scheme-kanagawa",
        "scheme-tokyo-night"
    ]

    // Auto-detect wallpaper
    Process {
        id: autoDetectProc
        command: ["bash", root.autoDetectScriptPath]
        property string output: ""
        stdout: SplitParser { onRead: data => autoDetectProc.output += data }
        onExited: (exitCode) => {
            // Trim any whitespace/newlines from the script output
            var path = autoDetectProc.output.toString().trim();
            if (path.length > 0) {
                root.wallpaperPath = path;
                root.generateFromWallpaper(path);
            } else {
                root.errorMessage = "Could not detect active wallpaper";
            }
            root.isBusy = false;
            autoDetectProc.output = "";
        }
    }

    function detectCurrentWallpaper() {
        if (root.isBusy) return;
        root.isBusy = true;
        root.errorMessage = "";
        autoDetectProc.running = true;
    }

    Timer {
        interval: 5000 // Check every 5 seconds
        running: root.enabled && root.liveUpdate
        repeat: true
        onTriggered: root.detectCurrentWallpaper()
    }
}
