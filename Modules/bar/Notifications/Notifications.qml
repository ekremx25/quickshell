import QtQuick
import QtQuick.Layouts
import Quickshell
// We use the singleton from Services directly or via import
import "../../../Services" as S
import "../../../Widgets"

// This component is the button in the bar
Rectangle {
    id: root

    // APPEARANCE
    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 30
    radius: 15

    // Connect to the Notifications singleton
    // Note: S.Notifications is the singleton instance
    property var notifService: S.Notifications

    // Check if there are active notifications
    property bool hasActive: notifService.activeNotifications.length > 0
    property int count: notifService.activeNotifications.length
    readonly property bool monochromeMode: (S.ColorPaletteService.enabled
        && S.ColorPaletteService.matugenType === "scheme-monochrome")
        || Theme.currentThemeName === "Monochrome"
    readonly property color normalColor: monochromeMode
        ? Theme.ramColor
        : Theme.notificationColor
    readonly property color contentColor: Theme.foregroundFor(normalColor)
    readonly property color mutedContentColor: Qt.rgba(contentColor.r, contentColor.g, contentColor.b, 0.68)
    color: normalColor
    border.width: hasActive ? 1 : 0
    border.color: monochromeMode ? contentColor : Theme.notificationColor
    opacity: hasActive || notifService.dnd ? 1 : 0.74

    scale: notifHover.hovered && !notifHover.pressed ? 1.06 : (notifHover.pressed ? 0.92 : 1.0)

    Behavior on opacity    { NumberAnimation { duration: 180 } }
    Behavior on scale      { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
    Behavior on color      { ColorAnimation { duration: Theme.animMedium } }

    HoverHandler {
        id: notifHover
        property bool pressed: false
        onHoveredChanged: if (!hovered) pressed = false
    }

    // Main Layout
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 8

        // --- NOTIFICATION TOGGLE ---
        Item {
            implicitWidth: iconRow.implicitWidth
            implicitHeight: iconRow.implicitHeight
            
            RowLayout {
                id: iconRow
                spacing: 6
                
                // Icon
                Text {
                    text: notifService.dnd ? "" : (hasActive ? "" : "")
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    color: notifService.dnd ? Theme.red : root.contentColor
                }

                // Count
                Text {
                    text: count > 0 ? count : ""
                    font.bold: true
                    font.family: Theme.fontFamily
                    color: root.contentColor
                    visible: count > 0
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: notifHover.pressed = true
                onReleased: notifHover.pressed = false
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        notifPopup.visible = !notifPopup.visible
                        durPopup.visible = false
                    } else if (mouse.button === Qt.RightButton) {
                        notifService.dnd = !notifService.dnd
                    }
                }
            }
        }

        // Separator
        Rectangle {
            width: 1
            height: 14
            color: root.mutedContentColor
            opacity: 0.5
        }

        // --- DURATION CONTROL ---
        Item {
            implicitWidth: durRow.implicitWidth
            implicitHeight: durRow.implicitHeight

            RowLayout {
                id: durRow
                spacing: 2
                
                Text {
                    text: "" // Timer icon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: root.mutedContentColor
                }
                
                Text {
                    font.family: Theme.fontFamily
                    text: (notifService.displayDuration / 1000) + "s"
                    font.bold: true
                    font.pixelSize: 12
                    color: root.contentColor
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // Wheel to change
                onWheel: (wheel) => {
                    var delta = wheel.angleDelta.y > 0 ? 1000 : -1000;
                    var newVal = notifService.displayDuration + delta;
                    if (newVal >= 1000 && newVal <= 600000) {
                        notifService.displayDuration = newVal;
                    }
                }
                // Click to open popup
                onClicked: {
                    durPopup.visible = !durPopup.visible
                    notifPopup.visible = false
                }
            }
        }
    }

    // POPUPs
    Item {
        id: notifPopup
        visible: false
        
        Loader {
            id: notifPopupLoader
            active: true
            source: "NotificationPopup.qml"
            
            Connections {
                target: S.Notifications
                function onPopupPositionChanged() {
                    notifPopupLoader.active = false
                    Qt.callLater(() => { notifPopupLoader.active = true })
                }
            }
            
            onLoaded: {
                item.visible = Qt.binding(() => notifPopup.visible)
            }
        }
        
        Connections {
            target: notifPopupLoader.item
            ignoreUnknownSignals: true
            function onVisibleChanged() {
                if (notifPopupLoader.item && notifPopupLoader.item.visible !== notifPopup.visible) {
                    notifPopup.visible = notifPopupLoader.item.visible
                }
            }
        }
    }
    
    DurationPopup {
        id: durPopup
        visible: false
    }

    // TOAST


}
