pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "./core" as Core
import "./core/Log.js" as Log

Singleton {
    id: root

    readonly property string helperPath: Core.PathService.configPath("scripts/wallpaper_deck.py")
    property string wallpaperDir: Core.PathService.homePath + "/Pictures/wallpapers"
    property var localItems: []
    property var wallhavenItems: []
    property var favorites: []
    property var favoriteWallhavenItems: []
    property bool localBusy: false
    property bool searchBusy: false
    property bool downloadBusy: false
    property bool applyBusy: false
    property string errorMessage: ""
    property string statusMessage: ""
    property string query: ""
    property string submittedQuery: ""
    property string resultQuery: ""
    property string sorting: "relevance"
    property int currentPage: 0
    property int lastPage: 0
    property int totalResults: 0
    property int pendingSearchPage: 0
    property string pendingSearchQuery: ""
    property var pendingRemoteItem: null
    property string pendingApplyPath: ""
    property var deckWindow: null

    signal openRequested()
    signal wallpaperApplied(string path)

    function open() {
        root.openRequested();
        root.reloadLocal();
    }

    function parseOutput(buffer, context) {
        try {
            var result = JSON.parse(String(buffer || "").trim());
            if (!result.ok) throw new Error(result.error || context + " failed");
            return result;
        } catch (e) {
            root.errorMessage = context + ": " + e;
            return null;
        }
    }

    function reloadLocal() {
        if (localProc.running) return;
        root.localBusy = true;
        root.errorMessage = "";
        localProc.buffer = "";
        localProc.command = ["python3", root.helperPath, "local", "--dir", root.wallpaperDir];
        localProc.running = true;
    }

    function searchWallhaven(nextPage) {
        var page = nextPage || 1;
        var requestedQuery = page === 1 ? root.query : root.submittedQuery;
        if (page === 1) root.submittedQuery = requestedQuery;
        if (searchProc.running) {
            root.pendingSearchPage = page;
            root.pendingSearchQuery = requestedQuery;
            return;
        }
        root.startWallhavenSearch(page, requestedQuery);
    }

    function startWallhavenSearch(page, requestedQuery) {
        root.searchBusy = true;
        root.errorMessage = "";
        searchProc.requestedPage = page;
        searchProc.requestedQuery = requestedQuery;
        searchProc.buffer = "";
        searchProc.command = [
            "python3", root.helperPath, "search",
            "--query", requestedQuery,
            "--page", String(page),
            "--sorting", root.sorting,
            "--atleast", "1920x1080"
        ];
        searchProc.running = true;
    }

    function loadNextPage() {
        if (!root.searchBusy && root.currentPage > 0 && root.currentPage < root.lastPage)
            root.searchWallhaven(root.currentPage + 1);
    }

    function applyItem(item) {
        if (!item || root.applyBusy || root.downloadBusy) return;
        root.errorMessage = "";
        if (item.source === "wallhaven") {
            root.pendingRemoteItem = item;
            root.downloadBusy = true;
            root.statusMessage = "Downloading " + item.name + "…";
            downloadProc.buffer = "";
            downloadProc.command = [
                "python3", root.helperPath, "download",
                "--url", item.path,
                "--id", item.id,
                "--dir", root.wallpaperDir
            ];
            downloadProc.running = true;
        } else {
            root.applyPath(item.path);
        }
    }

    function applyPath(path) {
        if (!path || applyProc.running) return;
        root.applyBusy = true;
        root.pendingApplyPath = path;
        root.statusMessage = "Applying wallpaper…";
        applyProc.buffer = "";
        applyProc.command = ["python3", root.helperPath, "apply", "--path", path];
        applyProc.running = true;
    }

    function isFavorite(id) {
        return root.favorites.indexOf(String(id)) !== -1;
    }

    function toggleFavorite(itemOrId) {
        var item = itemOrId && typeof itemOrId === "object" ? itemOrId : null;
        var key = String(item ? item.id : itemOrId);
        var next = root.favorites.slice();
        var remote = root.favoriteWallhavenItems.slice();
        var index = next.indexOf(key);
        if (index === -1) {
            next.push(key);
            if (item && item.source === "wallhaven" && !remote.some(function(saved) { return saved.id === key; })) {
                remote.push({
                    id: key,
                    source: "wallhaven",
                    name: item.name,
                    path: item.path,
                    preview: item.preview,
                    colors: item.colors || [],
                    resolution: item.resolution || "",
                    fileSize: item.fileSize || 0,
                    category: item.category || ""
                });
            }
        } else {
            next.splice(index, 1);
            remote = remote.filter(function(saved) { return saved.id !== key; });
        }
        root.favorites = next;
        root.favoriteWallhavenItems = remote;
        root.saveSettings();
    }

    function setWallpaperDir(path) {
        var clean = String(path || "").trim();
        if (!clean.length) return;
        root.wallpaperDir = Core.PathService.expandHome(clean);
        root.saveSettings();
        root.reloadLocal();
    }

    function saveSettings() {
        settingsStore.save({
            wallpaperDir: Core.PathService.compactHome(root.wallpaperDir),
            favorites: root.favorites,
            wallhavenFavorites: root.favoriteWallhavenItems
        });
    }

    Process {
        id: localProc
        property string buffer: ""
        stdout: SplitParser { onRead: data => localProc.buffer += data }
        onExited: function(exitCode) {
            root.localBusy = false;
            var result = root.parseOutput(localProc.buffer, "Local wallpapers");
            if (exitCode === 0 && result) {
                root.localItems = result.items || [];
                root.wallpaperDir = result.directory || root.wallpaperDir;
                root.statusMessage = root.localItems.length + " local wallpapers";
            }
            localProc.buffer = "";
        }
    }

    Process {
        id: searchProc
        property int requestedPage: 1
        property string requestedQuery: ""
        property string buffer: ""
        stdout: SplitParser { onRead: data => searchProc.buffer += data }
        onExited: function(exitCode) {
            var result = root.parseOutput(searchProc.buffer, "Wallhaven");
            if (exitCode === 0 && result && searchProc.requestedQuery === root.submittedQuery) {
                root.wallhavenItems = searchProc.requestedPage === 1
                    ? (result.items || [])
                    : root.wallhavenItems.concat(result.items || []);
                root.currentPage = result.meta.currentPage || searchProc.requestedPage;
                root.lastPage = result.meta.lastPage || root.currentPage;
                root.totalResults = result.meta.total || root.wallhavenItems.length;
                root.resultQuery = searchProc.requestedQuery;
                root.statusMessage = root.totalResults + " Wallhaven results";
            }
            searchProc.buffer = "";
            var nextPage = root.pendingSearchPage;
            var nextQuery = root.pendingSearchQuery;
            root.pendingSearchPage = 0;
            root.pendingSearchQuery = "";
            if (nextPage > 0) {
                Qt.callLater(function() { root.startWallhavenSearch(nextPage, nextQuery); });
            } else {
                root.searchBusy = false;
            }
        }
    }

    Process {
        id: downloadProc
        property string buffer: ""
        stdout: SplitParser { onRead: data => downloadProc.buffer += data }
        onExited: function(exitCode) {
            root.downloadBusy = false;
            var result = root.parseOutput(downloadProc.buffer, "Download");
            downloadProc.buffer = "";
            if (exitCode === 0 && result) {
                root.reloadLocal();
                root.applyPath(result.path);
            }
            root.pendingRemoteItem = null;
        }
    }

    Process {
        id: applyProc
        property string buffer: ""
        stdout: SplitParser { onRead: data => applyProc.buffer += data }
        onExited: function(exitCode) {
            root.applyBusy = false;
            var result = root.parseOutput(applyProc.buffer, "Apply wallpaper");
            applyProc.buffer = "";
            if (exitCode === 0 && result) {
                if (!ColorPaletteService.enabled) ColorPaletteService.setEnabled(true);
                ColorPaletteService.selectWallpaper(result.path);
                root.statusMessage = "Applied with " + result.backend;
                root.wallpaperApplied(result.path);
            }
            root.pendingApplyPath = "";
        }
    }

    Core.JsonDataStore {
        id: settingsStore
        path: Core.PathService.configPath("wallpaper_deck.json")
        defaultValue: ({ wallpaperDir: "~/Pictures/wallpapers", favorites: [], wallhavenFavorites: [] })
        onLoadedValue: function(cfg, rawText) {
            root.wallpaperDir = Core.PathService.expandHome(cfg.wallpaperDir || "~/Pictures/wallpapers");
            root.favorites = cfg.favorites instanceof Array ? cfg.favorites.map(String) : [];
            root.favoriteWallhavenItems = cfg.wallhavenFavorites instanceof Array
                ? cfg.wallhavenFavorites.filter(function(item) {
                    return item && item.source === "wallhaven" && item.id && item.path && item.preview;
                })
                : [];
            if (String(rawText || "").trim() === "" || cfg.wallhavenFavorites === undefined) root.saveSettings();
            root.reloadLocal();
        }
        onFailed: function(phase, exitCode, details) {
            if (phase === "parse") Log.warn("WallpaperDeck", "Config parse error: " + details);
        }
    }

    Component.onCompleted: settingsStore.load()
}
