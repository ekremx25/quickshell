import QtQuick
import Quickshell
import Quickshell.Io
import "../Services" as S

// Hover-to-open for a module's popup (Settings → Effects → Open on Hover).
// Put `HoverOpen { id: hoverOpen; popup: myPopup }` inside the module: the popup
// opens shortly after the pointer rests on the module, stays open while the
// pointer is on the module or the popup, and closes shortly after it leaves
// both. Route the module's click through handleClick() so a click while
// hovering opens instead of toggling the popup shut.
//
// Mapping a popup makes Wayland report a pointer "leave" on the bar even though
// the pointer never moved, and no new enter arrives until it moves again. So
// before closing, the real cursor position is asked from Hyprland: if it is
// still on the module the popup stays open.
Item {
    id: root

    property var popup: null
    // Item inside the popup that counts as "on the popup" (default: the whole
    // window). Full-screen overlays like the EQ pass their card here.
    property Item popupHoverItem: null
    // Optional function used instead of `popup.visible = false` (e.g. to play a
    // closing animation first).
    property var closer: null
    property bool hoverMode: S.EffectSettings.hoverOpen
    // While true the popup ignores hover-out (e.g. the notepad once you type);
    // a click on the module then closes it.
    property bool keepOpen: false
    readonly property bool triggerHovered: triggerHover.hovered
    property int openDelay: 140
    property int closeDelay: 400
    signal aboutToOpen()
    signal opened()

    anchors.fill: parent

    HoverHandler { id: triggerHover }

    // Hover tracking inside the popup window, created on demand.
    property var popupHover: null
    readonly property bool popupHovered: popupHover ? popupHover.hovered : false
    readonly property bool anyHover: triggerHover.hovered || popupHovered

    Component { id: popupHoverComponent; HoverHandler {} }

    function attachPopupHover() {
        var host = popupHoverItem ? popupHoverItem : (popup ? popup.contentItem : null);
        if (popupHover || !host) return;
        popupHover = popupHoverComponent.createObject(host);
    }

    function hide() {
        if (!popup || !popup.visible) return;
        if (closer) closer();
        else popup.visible = false;
    }

    function show() {
        if (!popup) return;
        attachPopupHover();
        closeTimer.stop();
        if (!popup.visible) {
            root.aboutToOpen();
            popup.visible = true;
            root.opened();
        }
    }

    function handleClick() {
        if (!popup) return;
        if (hoverMode && !(popup.visible && keepOpen)) show();
        else if (popup.visible) hide();
        else show();
    }

    // Module rectangle in global (compositor) coordinates.
    function moduleRect() {
        var win = root.QsWindow.window;
        if (!win || !win.screen) return null;
        var scr = win.screen;
        var wx = 0, wy = 0;
        if (win.windowScreenX !== undefined) {
            // The dock publishes where its layer surface sits.
            wx = win.windowScreenX; wy = win.windowScreenY;
        } else if (win.anchors) {
            var m = win.margins || {};
            wx = win.anchors.left ? (m.left || 0) : scr.width - win.width - (m.right || 0);
            wy = win.anchors.top ? (m.top || 0) : scr.height - win.height - (m.bottom || 0);
        }
        var p = root.mapToItem(null, 0, 0);
        return { x: scr.x + wx + p.x, y: scr.y + wy + p.y, w: root.width, h: root.height };
    }

    onPopupChanged: popupHover = null
    onPopupHoverItemChanged: popupHover = null
    Component.onCompleted: Qt.callLater(attachPopupHover)

    onAnyHoverChanged: {
        if (!hoverMode || !popup) return;
        if (anyHover) {
            closeTimer.stop();
            if (!popup.visible) openTimer.restart();
        } else {
            openTimer.stop();
            if (popup.visible && !keepOpen) closeTimer.restart();
        }
    }

    Timer {
        id: openTimer
        interval: root.openDelay
        onTriggered: if (root.anyHover) root.show()
    }

    Timer {
        id: closeTimer
        interval: root.closeDelay
        onTriggered: {
            if (root.anyHover || root.keepOpen || !root.popup || !root.popup.visible) return;
            if (!cursorProbe.running) cursorProbe.running = true;
        }
    }

    // A warped or fast-moving pointer can leave without a leave event, so while
    // the popup is open and the pointer is not on it, confirm its position.
    Timer {
        interval: 1000
        repeat: true
        running: root.hoverMode && !root.keepOpen && !!root.popup && root.popup.visible && !root.popupHovered
        onTriggered: if (!cursorProbe.running) cursorProbe.running = true
    }

    // `hyprctl cursorpos` prints "x, y" in global logical pixels.
    Process {
        id: cursorProbe
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.popupHovered || root.keepOpen || !root.popup || !root.popup.visible) return;
                var parts = String(text).split(",");
                var cx = parseFloat(parts[0]), cy = parseFloat(parts[1]);
                var r = root.moduleRect();
                var onModule = r && !isNaN(cx) && !isNaN(cy)
                    && cx >= r.x && cx < r.x + r.w && cy >= r.y && cy < r.y + r.h;
                // Still resting on the module: keep the popup (and look again later if
                // the hover state was lost). Anywhere else: close.
                if (onModule) {
                    if (!triggerHover.hovered) closeTimer.restart();
                } else {
                    root.hide();
                }
            }
        }
        // Without Hyprland (or on failure) fall back to closing.
        onExited: code => { if (code !== 0 && !root.anyHover) root.hide(); }
    }
}
