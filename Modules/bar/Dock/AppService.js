.pragma library

var APP_NAME_RULES = [
    { pattern: /firefox/, value: "Firefox" },
    { pattern: /brave/, value: "Brave" },
    { pattern: /chrom/, value: "Chrome" },
    { pattern: /opera/, value: "Opera" },
    { pattern: /vivaldi/, value: "Vivaldi" },
    { pattern: /edge/, value: "Edge" },
    { pattern: /kitty/, value: "Kitty" },
    { pattern: /konsole/, value: "Konsole" },
    { pattern: /wezterm/, value: "WezTerm" },
    { pattern: /ghostty/, value: "Ghostty" },
    { pattern: /alacritty/, value: "Alacritty" },
    { pattern: /foot/, value: "Foot" },
    { pattern: /gnome-terminal/, value: "Terminal" },
    { pattern: /telegram/, value: "telegram-desktop" },
    { pattern: /discord|vesktop/, value: "Discord" },
    { pattern: /signal/, value: "Signal" },
    { pattern: /whatsapp/, value: "WhatsApp" },
    { pattern: /slack/, value: "Slack" },
    { pattern: /zoom/, value: "Zoom" },
    { pattern: /teams/, value: "Teams" },
    { pattern: /skype/, value: "Skype" },
    { pattern: /dolphin|nautilus/, value: "Dosyalar" },
    { pattern: /thunar/, value: "Thunar" },
    { pattern: /nemo/, value: "Nemo" },
    { pattern: /spotify/, value: "Spotify" },
    { pattern: /vscode|code/, value: "VS Code" },
    { pattern: /cursor/, value: "Cursor" },
    { pattern: /zed/, value: "Zed" },
    { pattern: /intellij/, value: "IntelliJ" },
    { pattern: /pycharm/, value: "PyCharm" },
    { pattern: /android-studio/, value: "Android Studio" },
    { pattern: /obs/, value: "OBS Studio" },
    { pattern: /vlc/, value: "VLC" },
    { pattern: /mpv/, value: "MPV" },
    { pattern: /kdenlive/, value: "Kdenlive" },
    { pattern: /blender/, value: "Blender" },
    { pattern: /gimp/, value: "GIMP" },
    { pattern: /inkscape/, value: "Inkscape" },
    { pattern: /libreoffice/, value: "LibreOffice" },
    { pattern: /steam/, value: "Steam" },
    { pattern: /lutris/, value: "Lutris" },
    { pattern: /heroic/, value: "Heroic" },
    { pattern: /prismlauncher/, value: "Prism Launcher" },
    { pattern: /virtualbox/, value: "VirtualBox" },
    { pattern: /antigravity/, value: "Antigravity" }
];

var FALLBACK_COMMAND_RULES = [
    { pattern: /telegram/, value: "telegram-desktop" },
    { pattern: /vesktop/, value: "vesktop" },
    { pattern: /discord/, value: "discord" },
    { pattern: /brave/, value: "brave-browser-stable" },
    { pattern: /dolphin/, value: "dolphin" },
    { pattern: /obs/, value: "obs" }
];

var NORMALIZED_IDS = {
    "telegram": "telegram-desktop",
    "org.kde.dolphin": "dolphin",
    "firefox-esr": "firefox",
    "microsoft-edge": "microsoft-edge-stable",
    "google-chrome": "google-chrome-stable",
    "brave": "brave-browser-stable"
};

var SPECIAL_ICON_NAMES = {
    "net.lutris.lutris": "lutris",
    "codex": "application-x-executable",
    "kittyfloat": "kitty",
    "hyprpolkitagent": "application-x-executable",
    "com.obsproject.studio": "com.obsproject.Studio"
};

function firstMatchingValue(rules, value) {
    for (var i = 0; i < rules.length; i++) {
        if (rules[i].pattern.test(value)) return rules[i].value;
    }
    return "";
}

function lastToken(value) {
    if (!value || value.indexOf(".") === -1) return "";
    var parts = value.split(".");
    return parts[parts.length - 1].toLowerCase();
}

function compactId(value) {
    return String(value || "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

function resolveDesktopKey(rawId, desktopEntries, desktopIcons, desktopCommands) {
    if (!rawId) return "";

    var id = String(rawId).toLowerCase();
    if (desktopEntries[id] || desktopIcons[id] || desktopCommands[id]) return id;

    var compact = compactId(id);
    if (compact.length === 0) return "";

    var keys = Object.keys(desktopEntries || {});
    for (var i = 0; i < keys.length; i++) {
        if (compactId(keys[i]) === compact) return keys[i];
    }
    for (var j = 0; j < keys.length; j++) {
        var candidate = compactId(keys[j]);
        if (candidate.indexOf(compact) !== -1 || compact.indexOf(candidate) !== -1) return keys[j];
    }

    var shortName = lastToken(id);
    if (shortName && (desktopEntries[shortName] || desktopIcons[shortName] || desktopCommands[shortName])) return shortName;
    return "";
}

function normalizeAppId(appId) {
    if (!appId) return "";
    var lower = String(appId).toLowerCase();
    return NORMALIZED_IDS[lower] || appId;
}

function resolveThemedIconName(iconName) {
    if (!iconName) return "application-x-executable";
    var lowered = String(iconName).toLowerCase();
    return SPECIAL_ICON_NAMES[lowered] || iconName;
}

function getIcon(appId, desktopIcons, desktopEntries, desktopCommands) {
    if (!appId) return "application-x-executable";
    var id = String(appId).toLowerCase();
    var resolvedKey = resolveDesktopKey(id, desktopEntries || {}, desktopIcons || {}, desktopCommands || {});

    if (resolvedKey !== "") return desktopIcons[resolvedKey] || id;
    if (desktopIcons[id]) return desktopIcons[id];

    var shortName = lastToken(id);
    if (shortName && desktopIcons[shortName]) return desktopIcons[shortName];

    if (/resolve|davinci/.test(id)) return "/opt/resolve/graphics/DV_Resolve.png";
    if (SPECIAL_ICON_NAMES[id]) return SPECIAL_ICON_NAMES[id];
    return id;
}

function getAppName(appId) {
    if (!appId) return "Uygulama";
    var lower = String(appId).toLowerCase();
    var matched = firstMatchingValue(APP_NAME_RULES, lower);
    if (matched !== "") return matched;
    return String(appId).charAt(0).toUpperCase() + String(appId).slice(1);
}

function getCmd(appId, desktopEntries, desktopCommands) {
    if (!appId) return "";
    var id = String(appId).toLowerCase();
    var resolvedKey = resolveDesktopKey(id, desktopEntries || {}, {}, desktopCommands || {});
    var steamMatch = id.match(/steam_app[_-](\d+)/);
    if (steamMatch && steamMatch.length > 1) return "__steam_game__:" + steamMatch[1];
    if (id === "dota2" || id === "dota" || id.indexOf("dota 2") !== -1) return "__steam_game__:570";

    if (resolvedKey !== "") {
        if (desktopEntries[resolvedKey]) return "__desktop__:" + desktopEntries[resolvedKey];
        if (desktopCommands[resolvedKey]) return desktopCommands[resolvedKey];
    }

    if (desktopEntries[id]) return "__desktop__:" + desktopEntries[id];
    if (desktopCommands[id]) return desktopCommands[id];

    var shortName = lastToken(id);
    var shortSteamMatch = shortName.match(/steam_app[_-](\d+)/);
    if (shortSteamMatch && shortSteamMatch.length > 1) return "__steam_game__:" + shortSteamMatch[1];
    if (shortName && desktopEntries[shortName]) return "__desktop__:" + desktopEntries[shortName];
    if (shortName && desktopCommands[shortName]) return desktopCommands[shortName];

    var fallback = firstMatchingValue(FALLBACK_COMMAND_RULES, id);
    return fallback !== "" ? fallback : appId;
}
