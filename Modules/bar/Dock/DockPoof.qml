import QtQuick
import "../../../Widgets"
import "../../../Services" as S

// macOS-style "poof" played where a dock icon was removed: the icon shrinks
// away while a ring of smoke puffs billows out and fades. Destroys itself.
Item {
    id: poof

    property url iconSource
    property real iconSize: 32
    signal finished()

    width: iconSize * 2.6
    height: iconSize * 2.6

    Image {
        id: ghost
        anchors.centerIn: parent
        width: poof.iconSize
        height: poof.iconSize
        source: poof.iconSource
        sourceSize: Qt.size(64, 64)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Repeater {
        id: puffs
        model: 7
        Rectangle {
            required property int index
            // Spread evenly around the icon with a little jitter in size.
            readonly property real angle: index / 7 * Math.PI * 2 + 0.4
            readonly property real reach: poof.iconSize * (0.55 + (index % 3) * 0.12)
            property real t: 0

            width: poof.iconSize * (0.42 + (index % 2) * 0.12)
            height: width
            radius: width / 2
            x: poof.width / 2 - width / 2 + Math.cos(angle) * reach * t
            y: poof.height / 2 - height / 2 + Math.sin(angle) * reach * t - poof.iconSize * 0.25 * t
            scale: 0.3 + 1.1 * t
            opacity: (1 - t) * 0.85
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.withAlpha("#ffffff", 0.95) }
                GradientStop { position: 1.0; color: Theme.withAlpha(Theme.text, 0.55) }
            }

            NumberAnimation on t {
                from: 0; to: 1
                duration: S.EffectSettings.ms(520 + (index % 3) * 60)
                easing.type: Easing.OutCubic
            }
        }
    }

    ParallelAnimation {
        running: true
        NumberAnimation { target: ghost; property: "scale"; from: 1; to: 0.15; duration: S.EffectSettings.ms(260); easing.type: Easing.InBack }
        NumberAnimation { target: ghost; property: "opacity"; from: 1; to: 0; duration: S.EffectSettings.ms(260); easing.type: Easing.InCubic }
    }

    Timer {
        interval: S.EffectSettings.ms(720)
        running: true
        onTriggered: {
            poof.finished();
            poof.destroy();
        }
    }
}
