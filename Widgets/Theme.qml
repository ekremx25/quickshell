pragma Singleton
import QtQuick
import "../Services"

QtObject {
    id: root
    property var themeConfig: ({})
    property string userSelectedTheme: themeConfig.name || "Catppuccin Mocha"
    property string currentTheme: userSelectedTheme
    property string currentThemeName: currentTheme

    // --- TEMALAR ---
    readonly property var themes: ({
        "Catppuccin Mocha": {
            background: "#1e1e2e", surface: "#313244", text: "#cdd6f4",
            launcher: "#ffffff", launcherIcon: "#3377ff", workspaces: "#313244",
            temp: "#fab387", gpu: "#f5e0dc", disk: "#74c7ec",
            calendar: "#f9e2af", weather: "#94e2d5", media: "#cba6f7",
            system: "#74c7ec", power: "#f38ba8", tray: "#f2cdcd", display: "#f5c2e7",
            bluetooth: "#89b4fa", battery: "#a6e3a1", powerProfile: "#cba6f7"
        },
        "Dracula": {
            background: "#282a36", surface: "#44475a", text: "#f8f8f2",
            launcher: "#bd93f9", launcherIcon: "#282a36", workspaces: "#bd93f9",
            temp: "#ffb86c", gpu: "#ff5555", disk: "#f1fa8c",
            calendar: "#8be9fd", weather: "#50fa7b", media: "#ff79c6",
            system: "#6272a4", power: "#ff5555", tray: "#f8f8f2", display: "#ff79c6",
            bluetooth: "#8be9fd", battery: "#50fa7b", powerProfile: "#bd93f9"
        },
        "Nord": {
            background: "#2e3440", surface: "#3b4252", text: "#eceff4",
            launcher: "#5e81ac", launcherIcon: "#2e3440", workspaces: "#81a1c1",
            temp: "#d08770", gpu: "#bf616a", disk: "#ebcb8b",
            calendar: "#88c0d0", weather: "#a3be8c", media: "#b48ead",
            system: "#4c566a", power: "#bf616a", tray: "#d8dee9", display: "#b48ead",
            bluetooth: "#81a1c1", battery: "#a3be8c", powerProfile: "#b48ead"
        },
        "Monochrome": {
            background: "#000000", surface: "#222222", text: "#ffffff",
            launcher: "#ffffff", launcherIcon: "#3377ff", workspaces: "#222222",
            temp: "#ffffff", gpu: "#ffffff", disk: "#ffffff",
            calendar: "#ffffff", weather: "#ffffff", media: "#ffffff",
            system: "#ffffff", power: "#ffffff", tray: "#ffffff", display: "#ffffff",
            bluetooth: "#ffffff", battery: "#ffffff", powerProfile: "#ffffff"
        },
        "Cyberpunk": {
             background: "#050a0e", surface: "#0a141c", text: "#00ff9f",
             launcher: "#ff003c", launcherIcon: "#050a0e", workspaces: "#00ff9f",
             temp: "#00f0ff", gpu: "#ff003c", disk: "#bf00ff",
             calendar: "#00ff9f", weather: "#00f0ff", media: "#ff003c",
             system: "#bf00ff", power: "#ff003c", tray: "#00ff9f", display: "#00f0ff",
             bluetooth: "#00f0ff", battery: "#00ff9f", powerProfile: "#bf00ff",
             workspaceActiveText: "#050a0e"
        },
        "Gruvbox Dark": {
            background: "#282828", surface: "#3c3836", text: "#ebdbb2",
            launcher: "#fabd2f", launcherIcon: "#282828", workspaces: "#689d6a",
            temp: "#fe8019", gpu: "#fb4934", disk: "#fabd2f",
            calendar: "#83a598", weather: "#8ec07c", media: "#d3869b",
            system: "#458588", power: "#cc241d", tray: "#ebdbb2", display: "#b16286",
            bluetooth: "#83a598", battery: "#b8bb26", powerProfile: "#d3869b",
            workspaceActiveText: "#282828"
        },
        "Tokyo Night": {
            background: "#1a1b26", surface: "#24283b", text: "#c0caf5",
            launcher: "#7aa2f7", launcherIcon: "#1a1b26", workspaces: "#7aa2f7",
            temp: "#ff9e64", gpu: "#f7768e", disk: "#e0af68",
            calendar: "#7dcfff", weather: "#9ece6a", media: "#bb9af7",
            system: "#2ac3de", power: "#f7768e", tray: "#a9b1d6", display: "#7aa2f7",
            bluetooth: "#7aa2f7", battery: "#9ece6a", powerProfile: "#bb9af7",
            workspaceActiveText: "#1a1b26"
        },
        "Rose Pine": {
            background: "#191724", surface: "#26233a", text: "#e0def4",
            launcher: "#c4a7e7", launcherIcon: "#191724", workspaces: "#c4a7e7",
            temp: "#f6c177", gpu: "#eb6f92", disk: "#c4a7e7",
            calendar: "#9ccfd8", weather: "#31748f", media: "#ebbcba",
            system: "#3e8fb0", power: "#eb6f92", tray: "#e0def4", display: "#c4a7e7",
            bluetooth: "#9ccfd8", battery: "#31748f", powerProfile: "#c4a7e7",
            workspaceActiveText: "#191724"
        },
        "Solarized Dark": {
            background: "#002b36", surface: "#073642", text: "#839496",
            launcher: "#268bd2", launcherIcon: "#002b36", workspaces: "#268bd2",
            temp: "#cb4b16", gpu: "#dc322f", disk: "#b58900",
            calendar: "#268bd2", weather: "#859900", media: "#d33682",
            system: "#6c71c4", power: "#dc322f", tray: "#93a1a1", display: "#2aa198",
            bluetooth: "#268bd2", battery: "#859900", powerProfile: "#6c71c4",
            workspaceActiveText: "#fdf6e3"
        },
        "Everforest": {
            background: "#2d353b", surface: "#343f44", text: "#d3c6aa",
            launcher: "#a7c080", launcherIcon: "#2d353b", workspaces: "#a7c080",
            temp: "#e69875", gpu: "#e67e80", disk: "#dbbc7f",
            calendar: "#7fbbb3", weather: "#a7c080", media: "#d699b6",
            system: "#7fbbb3", power: "#e67e80", tray: "#d3c6aa", display: "#83c092",
            bluetooth: "#7fbbb3", battery: "#a7c080", powerProfile: "#d699b6",
            workspaceActiveText: "#2d353b"
        },
        "Kanagawa": {
            background: "#1f1f28", surface: "#2a2a37", text: "#dcd7ba",
            launcher: "#7e9cd8", launcherIcon: "#1f1f28", workspaces: "#7e9cd8",
            temp: "#ffa066", gpu: "#ff5d62", disk: "#e6c384",
            calendar: "#7fb4ca", weather: "#ffffff", media: "#d27e99",
            system: "#7aa89f", power: "#ff5d62", tray: "#c8c093", display: "#938aa9",
            bluetooth: "#7e9cd8", battery: "#76946a", powerProfile: "#957fb8",
            workspaceActiveText: "#1f1f28"
        }
    })

    // Custom Material You Theme Holder
    property var materialYouTheme: ({
        background: "#1C1B1F", surface: "#1C1B1F", text: "#E6E1E5",
        launcher: "#D0BCFF", launcherIcon: "#381E72", workspaces: "#4A4458",
        temp: "#F2B8B5", gpu: "#F2B8B5", disk: "#CCC2DC",
        calendar: "#D0BCFF", weather: "#D0BCFF", media: "#CCC2DC",
        system: "#D0BCFF", power: "#F2B8B5", tray: "#E6E1E5", display: "#D0BCFF",
        bluetooth: "#D0BCFF", battery: "#D0BCFF", powerProfile: "#CCC2DC",
        workspaceActiveText: "#381E72"
    })

    // Active theme colors (Fallback: Catppuccin)
    property var activeTheme: (currentTheme === "Material You") ? materialYouTheme : (themes[currentTheme] || themes["Catppuccin Mocha"])

    property color background: activeTheme.background
    property color surface: activeTheme.surface
    property color text: activeTheme.text
    
    // Modül Renkleri
    property color launcherColor: activeTheme.launcher
    property color launcherIconColor: activeTheme.launcherIcon || "#1e1e2e"
    property color workspacesColor: activeTheme.workspaces
    property color workspaceActiveTextColor: activeTheme.workspaceActiveText || activeTheme.text
    property color tempColor: activeTheme.temp
    property color gpuColor: activeTheme.gpu
    property color diskColor: activeTheme.disk
    property color calendarColor: activeTheme.calendar
    property color weatherColor: activeTheme.weather
    property color mediaColor: activeTheme.media
    property color systemColor: activeTheme.system
    property color powerColor: activeTheme.power
    property color trayColor: activeTheme.tray
    property color displayColor: activeTheme.display
    property color bluetoothColor: activeTheme.bluetooth || "#89b4fa"
    property color batteryColor: activeTheme.battery || "#a6e3a1"
    property color powerProfileColor: activeTheme.powerProfile || "#cba6f7"

    // Geriye dönük uyumluluk (Eski Theme özellikleri)
    property color subtext: activeTheme.subtext || "#a6adc8"
    property color primary: activeTheme.launcher 
    property color secondary: activeTheme.media
    property color red: activeTheme.redText || activeTheme.power
    property color green: activeTheme.greenText || activeTheme.battery || "#a6e3a1"
    property color yellow: activeTheme.yellowText || activeTheme.calendar || "#f9e2af"
    property color mauve: activeTheme.mauveText || activeTheme.powerProfile || "#cba6f7"
    property color base: activeTheme.background
    property color overlay2: "#9399b2"
    property color overlay: "#6c7086"
    property int radius: themeConfig.radius || 12

    // Dışarıdan tema değiştirme
    function setTheme(name) {
        if (name && themes[name]) {
            userSelectedTheme = name;
            
            if (name === "Monochrome") {
                ColorPaletteService.setMatugenType("scheme-monochrome");
                ColorPaletteService.setEnabled(true);
            } else {
                ColorPaletteService.setEnabled(false);
                currentTheme = name;
                currentThemeName = name;
            }
            console.log("Theme.qml: User theme set to " + name + " (Active: " + currentTheme + ")");
        }
    }

    // --- Integration with ColorPaletteService ---

    // Fix: Assign to property instead of default
    property Connections serviceConnections: Connections {
        target: ColorPaletteService
        function onThemeApplied() { root.syncMaterialYou(); }
        function onEnabledChanged() { root.syncMaterialYou(); }
        function onModeChanged() { root.syncMaterialYou(); }
        function onMatugenTypeChanged() { root.syncMaterialYou(); }
    }

    function syncMaterialYou() {
        if (ColorPaletteService.enabled) {
            console.log("Theme.qml: Syncing Material You colors...");
            
            // Map service colors to theme structure
            var p = ColorPaletteService;
            // Modules - mix of palette colors (Prioritize Light/Pastel backgrounds for hardcoded dark text)
            // In Light Mode: Use Container colors (Light)
            // In Dark Mode: Use Main colors (Pastel/Light)
            var isLight = (p.mode === "light");
            console.log("Theme.qml: Syncing. Mode: " + p.mode + " IsLight: " + isLight + " Type: " + p.matugenType);
            
            var newTheme;

            if (p.matugenType === "scheme-monochrome") {
                 // Monochrome Override (Pitch Black / Pure White)
                 if (isLight) {
                     // Light Mode: White background, Black text
                     newTheme = {
                        background: "#FFFFFF",
                        surface: "#F0F0F0",
                        text: "#000000",
                        
                        launcher: "#000000",
                        launcherIcon: "#FFFFFF",
                        workspaces: "#DDDDDD",
                        workspaceActiveText: "#000000",
                        
                        temp: "#E0E0E0", gpu: "#E0E0E0", disk: "#E0E0E0",
                        calendar: "#E0E0E0", weather: "#E0E0E0", media: "#E0E0E0",
                        system: "#E0E0E0", power: "#E0E0E0", tray: "#E0E0E0", display: "#E0E0E0",
                        
                        bluetooth: "#E0E0E0", battery: "#E0E0E0", powerProfile: "#E0E0E0",
                        
                        redText: "#000000",
                        greenText: "#000000",
                        yellowText: "#000000",
                        mauveText: "#000000",
                        
                        subtext: "#666666"
                    };
                 } else {
                     // Dark Mode: Black background, White text
                     newTheme = {
                        background: "#000000",
                        surface: "#111111",
                        text: "#FFFFFF",
                        
                        launcher: "#FFFFFF",
                        launcherIcon: "#000000",
                        workspaces: "#222222",
                        workspaceActiveText: "#FFFFFF",
                        
                        temp: "#FFFFFF", gpu: "#FFFFFF", disk: "#FFFFFF",
                        calendar: "#FFFFFF", weather: "#FFFFFF", media: "#FFFFFF",
                        system: "#FFFFFF", power: "#FFFFFF", tray: "#FFFFFF", display: "#FFFFFF",
                        
                        bluetooth: "#FFFFFF", battery: "#FFFFFF", powerProfile: "#FFFFFF",
                        
                        redText: "#FFFFFF",
                        greenText: "#FFFFFF",
                        yellowText: "#FFFFFF",
                        mauveText: "#FFFFFF",
                        
                        subtext: "#888888"
                    };
                 }
            } else if (p.matugenType === "scheme-catppuccin") {
                // Catppuccin Mocha Override
                newTheme = {
                    background: "#1e1e2e", surface: "#313244", text: "#cdd6f4",
                    launcher: "#ffffff", launcherIcon: "#3377ff", workspaces: "#313244",
                    workspaceActiveText: "#cdd6f4",
                    temp: "#fab387", gpu: "#f5e0dc", disk: "#74c7ec",
                    calendar: "#f9e2af", weather: "#94e2d5", media: "#cba6f7",
                    system: "#74c7ec", power: "#f38ba8", tray: "#f2cdcd", display: "#f5c2e7",
                    bluetooth: "#89b4fa", battery: "#a6e3a1", powerProfile: "#cba6f7",
                    redText: "#f38ba8", greenText: "#a6e3a1", yellowText: "#f9e2af", mauveText: "#cba6f7",
                    subtext: "#a6adc8"
                };
            } else if (p.matugenType === "scheme-kanagawa") {
                // Kanagawa Override
                newTheme = {
                    background: "#1f1f28", surface: "#2a2a37", text: "#dcd7ba",
                    launcher: "#7e9cd8", launcherIcon: "#1f1f28", workspaces: "#7e9cd8",
                    workspaceActiveText: "#1f1f28",
                    temp: "#ffa066", gpu: "#ff5d62", disk: "#e6c384",
                    calendar: "#7fb4ca", weather: "#ffffff", media: "#d27e99",
                    system: "#7aa89f", power: "#ff5d62", tray: "#c8c093", display: "#938aa9",
                    bluetooth: "#7e9cd8", battery: "#76946a", powerProfile: "#957fb8",
                    redText: "#ff5d62", greenText: "#76946a", yellowText: "#e6c384", mauveText: "#957fb8",
                    subtext: "#727169"
                };
            } else if (p.matugenType === "scheme-tokyo-night") {
                // Tokyo Night Override
                newTheme = {
                    background: "#1a1b26", surface: "#24283b", text: "#c0caf5",
                    launcher: "#7aa2f7", launcherIcon: "#1a1b26", workspaces: "#7aa2f7",
                    workspaceActiveText: "#1a1b26",
                    temp: "#ff9e64", gpu: "#f7768e", disk: "#e0af68",
                    calendar: "#7dcfff", weather: "#9ece6a", media: "#bb9af7",
                    system: "#2ac3de", power: "#f7768e", tray: "#a9b1d6", display: "#7aa2f7",
                    bluetooth: "#7aa2f7", battery: "#9ece6a", powerProfile: "#bb9af7",
                    redText: "#f7768e", greenText: "#9ece6a", yellowText: "#e0af68", mauveText: "#bb9af7",
                    subtext: "#565f89"
                };
            } else {
                // Standard Material You Logic
                newTheme = {
                    background: p.backgroundColor,
                    surface: p.surfaceColor,
                    text: p.surfaceOnColor,
                    
                    launcher: p.primaryColor,
                    launcherIcon: p.primaryOnColor,
                    workspaces: p.primaryContainerColor,
                    workspaceActiveText: p.primaryContainerOnColor,
                    
                    // Modules
                    temp: isLight ? p.tertiaryContainerColor : p.tertiaryColor,
                    gpu: isLight ? p.errorContainerColor : p.errorColor, 
                    disk: isLight ? p.secondaryContainerColor : p.secondaryColor,
                    calendar: isLight ? p.primaryContainerColor : p.primaryColor,
                    weather: isLight ? p.tertiaryContainerColor : p.tertiaryColor,
                    media: isLight ? p.secondaryContainerColor : p.secondaryColor,
                    system: isLight ? p.primaryContainerColor : p.primaryColor,
                    power: isLight ? p.errorContainerColor : p.errorColor,
                    tray: p.surfaceOnColor,
                    display: isLight ? p.tertiaryContainerColor : p.tertiaryColor,
                    
                    bluetooth: isLight ? p.primaryContainerColor : p.primaryColor,
                    battery: isLight ? p.tertiaryContainerColor : p.tertiaryColor,
                    powerProfile: isLight ? p.secondaryContainerColor : p.secondaryColor,
                    
                    // Specific text/icon colors (Always vibrant/dark for visibility)
                    redText: p.errorColor,
                    greenText: p.tertiaryColor,
                    yellowText: p.primaryColor,
                    mauveText: p.secondaryColor,
                    
                    // Extra
                    subtext: p.surfaceVariantOnColor
                };
            }
            
            materialYouTheme = newTheme;
            currentTheme = "Material You";
            currentThemeName = "Material You";
        } else {
            console.log("Theme.qml: Reverting to user theme: " + userSelectedTheme);
            currentTheme = userSelectedTheme;
            currentThemeName = userSelectedTheme;
        }
    }

    Component.onCompleted: {
        // Initial sync
        if (ColorPaletteService.enabled) syncMaterialYou();
    }
}
