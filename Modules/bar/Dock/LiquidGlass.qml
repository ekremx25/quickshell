import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Services" as S

// "Liquid glass" backdrop. Wayland clients cannot read what is behind them, so
// this samples the wallpaper region under the item instead: awww draws the
// wallpaper with crop:center, which PreserveAspectCrop reproduces exactly.
// The region then goes through shaders/liquidglass.frag (frost, rim
// refraction, chromatic split and specular rim), plus an optional droplet
// that follows the cursor and an occasional light sweep.
Item {
    id: glass

    required property var screen          // ShellScreen the dock is on
    property real screenX: 0              // top-left of this item in screen coords
    property real screenY: 0
    property real radius: 14
    property real refraction: 18
    property real edgeWidth: 18
    property real blurRadius: 9
    property real chroma: 0.6
    property real rimLight: 0.6
    property color tint: "white"
    property real tintStrength: 0.06

    // Droplet: set `hovered` and `pointerX/Y` (item coords) from a HoverHandler.
    property bool hovered: false
    property real pointerX: 0
    property real pointerY: 0
    property real pointerRadius: S.EffectSettings.dropletSize
    property real pointerStrength: hovered ? 1 : 0
    Behavior on pointerStrength { NumberAnimation { duration: S.EffectSettings.ms(260); easing.type: Easing.OutCubic } }

    // Light sweep every `shimmerInterval` ms; `shimmerDelay` staggers instances.
    property bool shimmerEnabled: false
    property int shimmerInterval: 9000
    property int shimmerDelay: 0
    property real shimmerPhase: 0

    property string wallpaperPath: ""
    property string awwwVersion: ""
    readonly property bool ready: wallpaper.status === Image.Ready
    readonly property real margin: refraction + blurRadius + 4
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || ((Quickshell.env("HOME") || "") + "/.cache")

    function parseQuery(text) {
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var version = /^awww\s+(\S+)/.exec(lines[i]);
            if (version) glass.awwwVersion = version[1];
            if (lines[i].indexOf(": " + glass.screen.name + ":") === -1) continue;
            var image = /image:\s*(.+)$/.exec(lines[i]);
            if (image) glass.wallpaperPath = image[1].trim();
        }
    }

    // One query at startup; afterwards awww's per-output cache file is watched.
    Process {
        running: true
        command: ["sh", "-c", "awww --version; awww query"]
        stdout: StdioCollector { onStreamFinished: glass.parseQuery(text) }
    }

    // Cache format: <header>|crop:center|<filter>|/path/to/image
    FileView {
        path: glass.awwwVersion ? glass.cacheHome + "/awww/" + glass.awwwVersion + "/" + glass.screen.name : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var content = text();
            var start = content.lastIndexOf("|/");
            if (start !== -1) glass.wallpaperPath = content.substring(start + 1).trim();
        }
    }

    SequentialAnimation {
        running: glass.shimmerEnabled && glass.visible && glass.ready
        loops: Animation.Infinite
        PauseAnimation { duration: S.EffectSettings.ms(glass.shimmerDelay) }
        NumberAnimation { target: glass; property: "shimmerPhase"; from: 0; to: 1; duration: S.EffectSettings.ms(1600); easing.type: Easing.InOutSine }
        PauseAnimation { duration: S.EffectSettings.ms(Math.max(0, glass.shimmerInterval - 1600 - glass.shimmerDelay)) }
    }

    Image {
        id: wallpaper
        width: glass.screen.width
        height: glass.screen.height
        source: glass.wallpaperPath ? "file://" + glass.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }

    ShaderEffectSource {
        id: region
        sourceItem: wallpaper
        hideSource: true
        visible: false
        sourceRect: Qt.rect(glass.screenX - glass.margin, glass.screenY - glass.margin,
                            glass.width + 2 * glass.margin, glass.height + 2 * glass.margin)
        textureSize: Qt.size(Math.max(1, Math.ceil(sourceRect.width * glass.screen.devicePixelRatio)),
                             Math.max(1, Math.ceil(sourceRect.height * glass.screen.devicePixelRatio)))
    }

    ShaderEffect {
        anchors.fill: parent
        visible: glass.ready && glass.width > 0 && glass.height > 0

        property variant source: region
        property size itemSize: Qt.size(width, height)
        property real margin: glass.margin
        property real radius: glass.radius
        property real refraction: glass.refraction
        property real edgeWidth: glass.edgeWidth
        property real blurRadius: glass.blurRadius
        property real chroma: glass.chroma
        property real rimLight: glass.rimLight
        property real tintStrength: glass.tintStrength
        property color tint: glass.tint
        property point pointer: Qt.point(glass.pointerX, glass.pointerY)
        property real pointerStrength: glass.pointerStrength
        property real pointerRadius: glass.pointerRadius
        property real shimmer: glass.shimmerPhase
        // Clamp sampling to the on-screen part of the source rect.
        property vector4d uvBounds: {
            var r = region.sourceRect;
            return Qt.vector4d(Math.max(0, -r.x / r.width), Math.max(0, -r.y / r.height),
                               Math.min(1, (glass.screen.width - r.x) / r.width),
                               Math.min(1, (glass.screen.height - r.y) / r.height));
        }

        fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")
    }
}
