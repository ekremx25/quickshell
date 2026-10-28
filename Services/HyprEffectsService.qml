import QtQuick
import Quickshell
import Quickshell.Io
import "../Widgets"
import "./core" as Core
import "./core/Log.js" as Log

// Pushes Settings → Effects window blur and wobble to Hyprland. The helper
// writes hypr/lua/quickshell_effects.lua (loaded by hyprland.lua, so the
// settings survive reloads) and evaluates it live. Aurora blur takes its two
// curtain colours from the current theme.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property string helperPath: Core.PathService.configPath("scripts/hypr_effects_apply.py")
    readonly property bool usesThemeColors: EffectSettings.hyprBlur && EffectSettings.hyprBlurStyle === "aurora"
    property bool applyAgain: false

    function hexColor(c) {
        function part(v) {
            var h = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16);
            return h.length < 2 ? "0" + h : h;
        }
        return part(c.r) + part(c.g) + part(c.b) + "ff";
    }

    function scheduleApply() {
        if (EffectSettings.loaded && CompositorService.isHyprland) debounce.restart();
    }

    Connections {
        target: EffectSettings
        function onHyprEffectsChanged() { root.scheduleApply(); }
    }

    Connections {
        target: Theme
        enabled: root.usesThemeColors
        function onPrimaryChanged() { root.scheduleApply(); }
        function onSecondaryChanged() { root.scheduleApply(); }
    }

    // Per-monitor wobble rules are written from the current monitor roles, so
    // rebuild them when a monitor is plugged in, removed or changes role.
    Connections {
        target: ScreenManager
        enabled: EffectSettings.hyprWobbleScope !== "all"
        function onRuntimeRoleMapChanged() { root.scheduleApply(); }
    }

    Timer {
        id: debounce
        // Each applied change makes Hyprland reload its config, so wait for
        // the user to stop dragging a slider.
        interval: 400
        onTriggered: {
            if (applyProc.running) {
                root.applyAgain = true;
                return;
            }
            applyProc.command = [
                "python3", root.helperPath,
                "--blur", String(EffectSettings.hyprBlur),
                "--style", EffectSettings.hyprBlurStyle,
                "--size", String(EffectSettings.hyprBlurSize),
                "--passes", String(EffectSettings.hyprBlurPasses),
                "--aurora1", root.hexColor(Theme.primary),
                "--aurora2", root.hexColor(Theme.secondary),
                "--wobble", String(EffectSettings.hyprWobble),
                "--intensity", String(EffectSettings.hyprWobbleIntensity),
                "--stiffness", String(EffectSettings.hyprWobbleStiffness),
                "--damping", String(EffectSettings.hyprWobbleDamping),
                "--wobble-scope", EffectSettings.hyprWobbleScope
            ];
            applyProc.running = true;
        }
    }

    Process {
        id: applyProc
        stdout: SplitParser { onRead: data => Log.warn("HyprEffects", data) }
        stderr: SplitParser { onRead: data => Log.warn("HyprEffects", data) }
        onExited: function(exitCode) {
            if (exitCode !== 0) Log.warn("HyprEffects", "apply failed with exit code " + exitCode);
            if (root.applyAgain) {
                root.applyAgain = false;
                debounce.restart();
            }
        }
    }

    Component.onCompleted: scheduleApply()
}
