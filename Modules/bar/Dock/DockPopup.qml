import QtQuick
import Quickshell

// A real popup surface, positioned by the compositor rather than clipped to the dock panel.
PopupWindow {
    id: popup
    required property Item anchorItem
    required property string dockPosition
    required property bool shown

    visible: shown && anchorItem !== null
    color: "transparent"
    anchor.item: anchorItem
    anchor.edges: dockPosition === "top" ? Edges.Bottom
        : dockPosition === "left" ? Edges.Right
        : dockPosition === "right" ? Edges.Left : Edges.Top
    anchor.gravity: anchor.edges
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
}
