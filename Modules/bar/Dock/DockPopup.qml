import QtQuick
import Quickshell

// A real popup surface, positioned by the compositor rather than clipped to the dock panel.
PopupWindow {
    id: popup
    required property Item anchorItem
    required property string dockPosition
    required property bool shown

    // Optional glass background. The owner supplies the component (so this file
    // stays dependency-free) and the dock window for screen coordinates.
    property var panel: null
    property Component glassComponent: null
    property real glassRadius: 12
    readonly property bool glass: panel !== null && glassComponent !== null

    visible: shown && anchorItem !== null
    color: "transparent"
    anchor.item: anchorItem
    anchor.edges: dockPosition === "top" ? Edges.Bottom
        : dockPosition === "left" ? Edges.Right
        : dockPosition === "right" ? Edges.Left : Edges.Top
    anchor.gravity: anchor.edges
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip

    // xdg-popup does not report its final position, so mirror the anchor rules:
    // centred on the anchor edge, slid back inside the screen.
    property real glassScreenX: 0
    property real glassScreenY: 0
    function updateGlassPosition() {
        if (!glass || !anchorItem) return;
        var a = anchorItem.mapToItem(null, 0, 0);
        var ax = panel.windowScreenX + a.x;
        var ay = panel.windowScreenY + a.y;
        var x, y;
        if (dockPosition === "left") { x = ax + anchorItem.width; y = ay + (anchorItem.height - height) / 2; }
        else if (dockPosition === "right") { x = ax - width; y = ay + (anchorItem.height - height) / 2; }
        else if (dockPosition === "top") { x = ax + (anchorItem.width - width) / 2; y = ay + anchorItem.height; }
        else { x = ax + (anchorItem.width - width) / 2; y = ay - height; }
        glassScreenX = Math.max(0, Math.min(x, panel.screen.width - width));
        glassScreenY = Math.max(0, Math.min(y, panel.screen.height - height));
    }
    onVisibleChanged: if (visible) updateGlassPosition()
    onWidthChanged: updateGlassPosition()
    onHeightChanged: updateGlassPosition()

    Loader {
        // The loaded item reads its geometry from `popupHost`.
        readonly property var popupHost: popup
        anchors.fill: parent
        z: -1
        active: popup.glass && popup.visible
        sourceComponent: popup.glassComponent
    }
}
