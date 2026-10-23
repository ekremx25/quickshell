import QtQuick
import Quickshell
import "../Services" as S

// Entrance animation for popup windows. Drop `PopupEntrance {}` anywhere inside
// a PopupWindow/PanelWindow: each time the window becomes visible its content
// plays the style chosen in Settings → Effects, starting from the module that
// opened it (or the side facing the bar), at the chosen animation speed.
//
// Styles: liquidRing (rippling circle), genie (funnel), flip (3D hinge),
// jelly (squash and stretch), spring (scale + slide), fade, none.
// Shader layers are only enabled while an animation runs.
Item {
    id: root

    // Module that opened the popup; ring/genie animations start at its centre.
    property Item originItem: null
    property color rimColor: Theme.primary
    // Overrides Settings → Effects when set (e.g. for previews).
    property string style: ""
    // For popups that are not Quickshell windows (plain Qt Window) or that only
    // animate one card inside a larger window: set both, and call play() yourself
    // when autoPlay is false.
    property var hostWindow: null
    property Item targetItem: null
    property bool autoPlay: true
    property int duration: 560          // base duration at 1× speed

    readonly property string activeStyle: style !== "" ? style : S.EffectSettings.popupStyle
    readonly property int scaledDuration: S.EffectSettings.ms(duration)
    readonly property real springScale: Math.max(0.25, S.EffectSettings.speed) * Math.max(0.25, S.EffectSettings.speed)

    readonly property var window: hostWindow ? hostWindow : QsWindow.window
    readonly property Item target: targetItem ? targetItem : (window ? window.contentItem : null)
    property string side: "top"
    property point origin: Qt.point(0, 0)

    // Animated by the styles below.
    property real revealRadius: 0
    property real wobble: 0
    property real phase: 0
    property real rim: 0
    property real progress: 0
    readonly property real maxRadius: {
        if (!target) return 0;
        var dx = Math.max(origin.x, target.width - origin.x);
        var dy = Math.max(origin.y, target.height - origin.y);
        return Math.sqrt(dx * dx + dy * dy) + 12;
    }

    visible: false
    width: 0
    height: 0

    function resolveSide() {
        var w = root.window;
        if (!w) return "top";
        // PopupWindow: compare the anchor rect with the window it hangs off.
        if (w.anchor && w.anchor.window) {
            var r = w.anchor.rect, host = w.anchor.window;
            // Popups of a bottom-edge panel (the dock) open upwards even when the
            // compositor had to flip them, so trust the host's edge first.
            if (host.anchors && host.anchors.bottom && !host.anchors.top) return "bottom";
            if (r.x < 0) return "right";
            if (r.x >= host.width) return "left";
            if (r.y < 0) return "bottom";
            return "top";
        }
        // PanelWindow: start at the screen edge it is anchored to; full-span
        // overlays start from their centre.
        if (w.anchors) {
            if ((w.anchors.top && w.anchors.bottom) || (w.anchors.left && w.anchors.right)) return "center";
            if (w.anchors.bottom && !w.anchors.top) return "bottom";
            // Top-anchored popovers (e.g. the notepad under the bar) open downwards.
            if (w.anchors.top && !w.anchors.bottom) return "top";
            if (w.anchors.left && !w.anchors.right) return "left";
            if (w.anchors.right && !w.anchors.left) return "right";
        }
        return "top";
    }

    // The origin always sits on the edge the popup opens from; only the position
    // along that edge comes from the module that opened it.
    function resolveOrigin() {
        var p = moduleOrigin();
        var tw = target.width, th = target.height;
        if (side === "top") p.y = 0;
        else if (side === "bottom") p.y = th;
        else if (side === "left") p.x = 0;
        else if (side === "right") p.x = tw;
        return p;
    }

    function moduleOrigin() {
        var w = root.window, tw = target.width, th = target.height;
        if (originItem && w.anchor && w.anchor.window && w.anchor.window.contentItem) {
            var m = w.anchor.window.contentItem.mapFromItem(originItem, originItem.width / 2, originItem.height / 2);
            var r = w.anchor.rect;
            return Qt.point(Math.max(0, Math.min(tw, m.x - r.x)), Math.max(0, Math.min(th, m.y - r.y)));
        }
        // No anchor (plain window placed at the screen origin, like the bar):
        // compare both items' positions within their windows.
        if (originItem) {
            var o = originItem.mapToItem(null, originItem.width / 2, originItem.height / 2);
            var t = target.mapToItem(null, 0, 0);
            return Qt.point(Math.max(0, Math.min(tw, o.x - t.x)), Math.max(0, Math.min(th, o.y - t.y)));
        }
        if (side === "bottom") return Qt.point(tw / 2, th);
        if (side === "left") return Qt.point(0, th / 2);
        if (side === "right") return Qt.point(tw, th / 2);
        if (side === "center") return Qt.point(tw / 2, th / 2);
        return Qt.point(tw / 2, 0);
    }

    function stopAll() {
        ringAnim.stop(); genieAnim.stop(); flipAnim.stop();
        jellyAnim.stop(); springAnim.stop(); fadeAnim.stop();
    }

    // Layer-shell windows report a 0×0 size until the compositor configures
    // them, so a play() that arrives too early waits for the real size.
    property bool pendingPlay: false
    Connections {
        target: root.pendingPlay ? root.target : null
        function onWidthChanged() { root.retryPlay() }
        function onHeightChanged() { root.retryPlay() }
    }
    function retryPlay() {
        if (pendingPlay && target && target.width > 0 && target.height > 0) {
            pendingPlay = false;
            play();
        }
    }

    function play() {
        stopAll();
        if (!target) return;
        if (target.width <= 0 || target.height <= 0) {
            pendingPlay = true;
            return;
        }
        pendingPlay = false;
        var styleName = activeStyle;
        if (styleName === "none") return;

        side = resolveSide();
        origin = resolveOrigin();

        // Reset every transform so styles never leak into each other.
        target.transform = [scaleT, rotationT, shift];
        scaleT.xScale = 1; scaleT.yScale = 1;
        rotationT.angle = 0;
        shift.x = 0; shift.y = 0;
        target.opacity = 1;
        target.scale = 1;

        var edgeX = side === "left" ? 0 : side === "right" ? target.width : target.width / 2;
        var edgeY = side === "top" ? 0 : side === "bottom" ? target.height : target.height / 2;
        scaleT.origin.x = edgeX; scaleT.origin.y = edgeY;
        rotationT.origin.x = edgeX; rotationT.origin.y = edgeY;

        if (styleName === "liquidRing" || styleName === "genie") {
            target.layer.effect = styleName === "genie" ? genieEffect : ringEffect;
            target.layer.enabled = true;
            if (styleName === "genie") genieAnim.restart(); else ringAnim.restart();
        } else if (styleName === "flip") {
            var vertical = side === "top" || side === "bottom" || side === "center";
            rotationT.axis.x = vertical ? 1 : 0;
            rotationT.axis.y = vertical ? 0 : 1;
            rotationT.angle = side === "bottom" || side === "left" ? 85 : -85;
            target.opacity = 0;
            flipAnim.restart();
        } else if (styleName === "jelly") {
            jellyAnim.restart();
        } else if (styleName === "fade") {
            target.opacity = 0;
            target.scale = 0.98;
            fadeAnim.restart();
        } else {
            var horizontal = side === "left" || side === "right";
            var sign = (side === "top" || side === "left") ? -1 : 1;
            var d = side === "center" ? 0 : 14;
            shift.x = horizontal ? sign * d : 0;
            shift.y = horizontal ? 0 : sign * d;
            scaleT.xScale = 0.9; scaleT.yScale = 0.9;
            target.opacity = 0;
            springAnim.restart();
        }
    }

    function finish() {
        stopAll();
        pendingPlay = false;
        if (target) {
            target.layer.enabled = false;
            target.layer.effect = null;
            target.opacity = 1;
            target.scale = 1;
        }
        scaleT.xScale = 1; scaleT.yScale = 1;
        rotationT.angle = 0;
        shift.x = 0; shift.y = 0;
    }

    Connections {
        target: root.window
        function onVisibleChanged() {
            if (!root.window.visible) root.finish();
            else if (root.autoPlay) root.play();
        }
    }

    Scale { id: scaleT }
    Rotation { id: rotationT; axis { x: 1; y: 0; z: 0 } }
    Translate { id: shift }

    Component {
        id: ringEffect
        ShaderEffect {
            property size size: Qt.size(width, height)
            property point origin: root.origin
            property real radius: root.revealRadius
            property real wobble: root.wobble
            property real phase: root.phase
            property real rim: root.rim
            property color rimColor: root.rimColor
            fragmentShader: Qt.resolvedUrl("shaders/liquidreveal.frag.qsb")
        }
    }

    Component {
        id: genieEffect
        ShaderEffect {
            property size size: Qt.size(width, height)
            property point origin: root.origin
            property real progress: root.progress
            property real side: root.side === "bottom" ? 1 : root.side === "left" ? 2 : root.side === "right" ? 3 : 0
            fragmentShader: Qt.resolvedUrl("shaders/genie.frag.qsb")
        }
    }

    // Liquid ring: circle grows from the origin; ripples and glint settle as it opens.
    SequentialAnimation {
        id: ringAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "revealRadius"; from: 0; to: root.maxRadius; duration: root.scaledDuration; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "phase"; from: 0; to: 9; duration: root.scaledDuration }
            NumberAnimation { target: root; property: "wobble"; from: 9; to: 0; duration: root.scaledDuration; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "rim"; from: 1; to: 0; duration: root.scaledDuration; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.finish() }
    }

    // Genie: pours out of the opening edge like a funnel.
    SequentialAnimation {
        id: genieAnim
        NumberAnimation { target: root; property: "progress"; from: 0; to: 1; duration: root.scaledDuration; easing.type: Easing.InOutSine }
        ScriptAction { script: root.finish() }
    }

    // 3D flip: swings down from its hinge on the bar edge with a slight overshoot.
    SequentialAnimation {
        id: flipAnim
        ParallelAnimation {
            NumberAnimation { target: root.target; property: "opacity"; from: 0; to: 1; duration: root.scaledDuration * 0.4; easing.type: Easing.OutCubic }
            NumberAnimation { target: rotationT; property: "angle"; to: 0; duration: root.scaledDuration; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        ScriptAction { script: root.finish() }
    }

    // Jelly: squash flat, stretch long, wobble back to rest.
    SequentialAnimation {
        id: jellyAnim
        PropertyAction { target: scaleT; property: "xScale"; value: 1.25 }
        PropertyAction { target: scaleT; property: "yScale"; value: 0.45 }
        ParallelAnimation {
            NumberAnimation { target: scaleT; property: "xScale"; to: 0.86; duration: root.scaledDuration * 0.28; easing.type: Easing.OutSine }
            NumberAnimation { target: scaleT; property: "yScale"; to: 1.14; duration: root.scaledDuration * 0.28; easing.type: Easing.OutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: scaleT; property: "xScale"; to: 1.06; duration: root.scaledDuration * 0.24; easing.type: Easing.InOutSine }
            NumberAnimation { target: scaleT; property: "yScale"; to: 0.95; duration: root.scaledDuration * 0.24; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: scaleT; property: "xScale"; to: 0.98; duration: root.scaledDuration * 0.2; easing.type: Easing.InOutSine }
            NumberAnimation { target: scaleT; property: "yScale"; to: 1.02; duration: root.scaledDuration * 0.2; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: scaleT; property: "xScale"; to: 1; duration: root.scaledDuration * 0.18; easing.type: Easing.OutSine }
            NumberAnimation { target: scaleT; property: "yScale"; to: 1; duration: root.scaledDuration * 0.18; easing.type: Easing.OutSine }
        }
        ScriptAction { script: root.finish() }
    }

    // Spring: grow from 90% and slide in from the bar side.
    SequentialAnimation {
        id: springAnim
        ParallelAnimation {
            NumberAnimation { target: root.target; property: "opacity"; to: 1; duration: root.scaledDuration * 0.35; easing.type: Easing.OutCubic }
            SpringAnimation { target: scaleT; property: "xScale"; to: 1; spring: 5.0 * root.springScale; damping: 0.32; epsilon: 0.002 }
            SpringAnimation { target: scaleT; property: "yScale"; to: 1; spring: 5.0 * root.springScale; damping: 0.32; epsilon: 0.002 }
            SpringAnimation { target: shift; property: "x"; to: 0; spring: 4.0 * root.springScale; damping: 0.30; epsilon: 0.2 }
            SpringAnimation { target: shift; property: "y"; to: 0; spring: 4.0 * root.springScale; damping: 0.30; epsilon: 0.2 }
        }
        ScriptAction { script: root.finish() }
    }

    // Fade: a calm cross-fade with a hint of zoom.
    SequentialAnimation {
        id: fadeAnim
        ParallelAnimation {
            NumberAnimation { target: root.target; property: "opacity"; from: 0; to: 1; duration: root.scaledDuration * 0.6; easing.type: Easing.OutCubic }
            NumberAnimation { target: root.target; property: "scale"; from: 0.98; to: 1; duration: root.scaledDuration * 0.6; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root.finish() }
    }
}
