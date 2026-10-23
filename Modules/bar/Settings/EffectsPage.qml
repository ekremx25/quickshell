import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../Widgets"
import "../../../Services" as S

// Settings → Effects: animation speed, per-effect switches and style pickers,
// all saved by EffectSettings and applied immediately.
Item {
    id: root

    // ─── colors (matching DockPage) ────────────────────────────
    property color colorText:       SettingsPalette.text
    property color colorSubtext:    SettingsPalette.subtext
    property color colorPrimary:    SettingsPalette.readableAccent(Theme.primary)
    property color colorPrimaryText: SettingsPalette.foregroundFor(colorPrimary)
    property color colorBackground: SettingsPalette.background
    property color colorCard:       SettingsPalette.card
    property color colorCardStrong: SettingsPalette.cardStrong
    property color colorBorder:     SettingsPalette.border
    property color colorTrack:      SettingsPalette.track

    component SectionTitle: Text {
        font.family: Theme.fontFamily
        font.bold: true
        font.pixelSize: 13
        color: root.colorSubtext
        Layout.topMargin: 6
    }

    Rectangle {
        anchors.fill: parent
        color: root.colorBackground
        radius: 12
    }

    Flickable {
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight + 48
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentCol
            width: parent.width - 48
            x: 24
            y: 24
            spacing: 12

            Text { text: "Effects"; font.bold: true; font.pixelSize: 24; color: root.colorText; font.family: Theme.fontFamily }
            Text {
                Layout.fillWidth: true
                text: "Pick the effects you like and how fast they move. Changes apply immediately."
                font.pixelSize: 14; color: root.colorSubtext; font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
            }

            Item { height: 6 }

            // ═══ ANIMATION SPEED ═══
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: speedCol.implicitHeight + 24
                radius: 10
                color: root.colorCard
                border.color: root.colorPrimary
                border.width: 1

                ColumnLayout {
                    id: speedCol
                    anchors.fill: parent; anchors.margins: 12; spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        EffectCardTitle {
                            title: "Animation Speed"
                            description: "Speeds up or slows down every effect on this page at once."
                        }
                        Text {
                            text: S.EffectSettings.speed.toFixed(2).replace(/0$/, "") + "×"
                            font.pixelSize: 20; font.bold: true; color: root.colorPrimary; font.family: Theme.fontFamily
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: "Slow"; font.pixelSize: 11; color: root.colorSubtext; font.family: Theme.fontFamily }
                        Slider {
                            id: speedSlider
                            Layout.fillWidth: true
                            from: 0.25; to: 3; stepSize: 0.05
                            value: S.EffectSettings.speed
                            onMoved: S.EffectSettings.set("speed", value)
                            background: Rectangle {
                                x: speedSlider.leftPadding
                                y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                                width: speedSlider.availableWidth; height: 6; radius: 3
                                color: root.colorTrack
                                Rectangle {
                                    width: speedSlider.visualPosition * parent.width; height: parent.height
                                    radius: 3; color: root.colorPrimary
                                }
                            }
                            handle: Rectangle {
                                x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                                y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                                width: 18; height: 18; radius: 9
                                color: root.colorPrimary
                                border.color: root.colorPrimaryText; border.width: 2
                            }
                        }
                        Text { text: "Fast"; font.pixelSize: 11; color: root.colorSubtext; font.family: Theme.fontFamily }
                    }
                    RowLayout {
                        spacing: 6
                        Repeater {
                            model: [
                                { label: "Relaxed", value: 0.6 },
                                { label: "Normal", value: 1.0 },
                                { label: "Snappy", value: 1.6 },
                                { label: "Instant", value: 2.6 }
                            ]
                            Rectangle {
                                required property var modelData
                                readonly property bool selected: Math.abs(S.EffectSettings.speed - modelData.value) < 0.01
                                width: presetLabel.implicitWidth + 24; height: 28; radius: 14
                                color: selected ? root.colorPrimary : root.colorCardStrong
                                Text {
                                    id: presetLabel
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    font.pixelSize: 12; font.family: Theme.fontFamily
                                    color: parent.selected ? root.colorPrimaryText : root.colorText
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: S.EffectSettings.set("speed", parent.modelData.value)
                                }
                            }
                        }
                    }
                }
            }

            // ═══ POPUPS ═══
            SectionTitle { text: "POPUPS" }
            EffectStylePicker {
                key: "popupStyle"; title: "Popup Opening"
                description: "How module popups (clipboard, power profile, weather, settings…) appear."
                options: [
                    { value: "liquidRing", label: "Liquid Ring", hint: "A rippling circle grows from the module you clicked." },
                    { value: "genie", label: "Genie", hint: "Pours out of the bar like a funnel, the macOS way." },
                    { value: "flip", label: "3D Flip", hint: "Swings down from its hinge on the bar like a card." },
                    { value: "jelly", label: "Jelly", hint: "Squashes, stretches and wobbles into place." },
                    { value: "spring", label: "Spring", hint: "Grows and slides in with a springy settle." },
                    { value: "fade", label: "Fade", hint: "A calm fade with a hint of zoom." },
                    { value: "none", label: "Off", hint: "Popups appear instantly." }
                ]
            }

            EffectToggleCard {
                key: "hoverOpen"; title: "Open on Hover"
                description: "Popups of small bar modules open when the pointer rests on them and close when it leaves, like the calendar."
            }

            // ═══ LIQUID GLASS ═══
            SectionTitle { text: "LIQUID GLASS" }
            EffectToggleCard {
                key: "liquidGlass"; title: "Liquid Glass"
                description: "Glass made from your wallpaper for the dock, bar, menus, notifications and volume OSD."
            }
            EffectToggleCard {
                key: "glassShimmer"; title: "Light Sweep"
                description: "A soft band of light glides across the glass every few seconds."
                available: S.EffectSettings.liquidGlass
            }
            EffectToggleCard {
                key: "glassDroplet"; title: "Cursor Droplet"
                description: "A magnifying droplet follows the cursor over the glass."
                available: S.EffectSettings.liquidGlass
            }
            EffectSliderCard {
                key: "dropletSize"; title: "Droplet Size"
                description: "How large the cursor droplet is."
                from: 10; to: 40; stepSize: 1; unit: " px"
                available: S.EffectSettings.liquidGlass && S.EffectSettings.glassDroplet
            }

            // ═══ DOCK ═══
            SectionTitle { text: "DOCK" }
            EffectStylePicker {
                key: "launchStyle"; title: "App Launch"
                description: "What a dock icon does while its app is starting."
                options: [
                    { value: "bounce", label: "Bounce", hint: "Hops up and down, like on macOS." },
                    { value: "pulse", label: "Pulse", hint: "Beats like a heart until the window appears." },
                    { value: "wiggle", label: "Wiggle", hint: "Tilts side to side impatiently." },
                    { value: "none", label: "Off", hint: "Icons stay still." }
                ]
            }
            EffectToggleCard {
                key: "dockPoof"; title: "Poof"
                description: "A puff of smoke when an icon is removed from the dock."
            }
            EffectToggleCard {
                key: "visualizer"; title: "Music Visualizer"
                description: "Small equalizer next to the track title while music plays (needs cava)."
            }
            // cava is an optional package; say so where the switch lives.
            Rectangle {
                Layout.fillWidth: true
                visible: S.CavaService.checked && !S.CavaService.available
                implicitHeight: cavaHint.implicitHeight + 20
                radius: 10
                color: Theme.withAlpha(Theme.yellow, 0.12)
                border.color: Theme.withAlpha(Theme.yellow, 0.45)
                border.width: 1
                Text {
                    id: cavaHint
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    text: "cava is not installed, so the visualizer stays hidden. Install it with: sudo pacman -S cava"
                    color: root.colorText
                    font.pixelSize: 12
                    font.family: Theme.fontFamily
                    wrapMode: Text.WordWrap
                }
            }

            // ═══ NOTIFICATIONS ═══
            SectionTitle { text: "NOTIFICATIONS" }
            EffectStylePicker {
                key: "toastStyle"; title: "Notification Entrance"
                description: "How new notifications arrive on screen."
                options: [
                    { value: "spring", label: "Spring", hint: "Slides in and settles like a physical card." },
                    { value: "elastic", label: "Elastic", hint: "Snaps in and rings like a rubber band." },
                    { value: "classic", label: "Classic", hint: "The original smooth slide." }
                ]
            }

            // ═══ BAR & OSD ═══
            SectionTitle { text: "BAR & OSD" }
            EffectToggleCard {
                key: "liquidWorkspace"; title: "Flowing Workspace Indicator"
                description: "The active workspace highlight stretches and flows to the new workspace."
            }
            EffectToggleCard {
                key: "osdWave"; title: "Liquid Volume OSD"
                description: "The volume bar ripples like water while it is shown."
            }
        }
    }
}
