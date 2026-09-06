pragma Singleton
import QtQuick
import "."
import "../Modules/bar/Settings/SettingsPalette.js" as ColorMath

QtObject {
    readonly property bool themed: Theme.currentTheme === "Material You"
    readonly property color text: themed ? Theme.text : "#f5f7ff"
    readonly property color subtext: themed ? Theme.subtext : "#aeb8cb"
    readonly property color background: themed ? Theme.background : "#11141b"
    readonly property color surface: themed ? Theme.panelSurface : "#171b24"
    readonly property color overlay: themed ? Theme.subtext : "#6f7b91"
    readonly property color overlay2: themed ? Theme.subtext : "#8f9bb1"
    readonly property color border: themed ? Theme.borderStrong : "#2d3544"
    readonly property color card: surface
    readonly property color cardStrong: themed ? Theme.raisedSurface : "#232938"
    readonly property color track: themed ? Theme.surfaceVariant : "#303848"

    function contrast(first, second) { return ColorMath.contrast(first, second); }
    function readableAccent(candidate, canvas) {
        return contrast(candidate, canvas || background) >= 4.5 ? candidate : text;
    }
    function foregroundFor(fill) { return Theme.foregroundFor(fill); }
    function withAlpha(value, alpha) { return ColorMath.withAlpha(value, alpha); }
}
