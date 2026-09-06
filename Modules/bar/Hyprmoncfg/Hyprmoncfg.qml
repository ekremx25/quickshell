import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Basic
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../System" as Sys

Rectangle {
    id: root

    property int advancedWidth: 1320
    property int advancedHeight: 900
    property int advancedRestoreWidth: 1320
    property int advancedRestoreHeight: 900
    property int advancedRestoreX: 0
    property int advancedRestoreY: 0
    property bool advancedMaximized: false

    readonly property color accent: Theme.displayColor
    readonly property color accentText: Theme.foregroundFor(accent)
    readonly property color panelColor: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 1)
    readonly property color cardColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 1)
    readonly property color textColor: Theme.text
    readonly property color mutedColor: Theme.subtext
    readonly property color borderColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.12)

    function advancedScreenWidth() {
        return advancedPopup.width > 0 ? advancedPopup.width : 1920;
    }

    function advancedScreenHeight() {
        return advancedPopup.height > 0 ? advancedPopup.height : 1080;
    }

    function resizeAdvanced(deltaWidth, deltaHeight) {
        setAdvancedSize(advancedPanel.width + deltaWidth, advancedPanel.height + deltaHeight);
    }

    function setAdvancedSize(width, height) {
        advancedMaximized = false;
        var oldCenterX = advancedPanel.x + advancedPanel.width / 2;
        var oldCenterY = advancedPanel.y + advancedPanel.height / 2;
        advancedWidth = Math.max(980, Math.min(advancedScreenWidth() - 24, Math.round(width)));
        advancedHeight = Math.max(680, Math.min(advancedScreenHeight() - 24, Math.round(height)));
        advancedPanel.width = advancedWidth;
        advancedPanel.height = advancedHeight;
        advancedPanel.x = Math.max(12, Math.min(advancedScreenWidth() - advancedPanel.width - 12,
            oldCenterX - advancedPanel.width / 2));
        advancedPanel.y = Math.max(12, Math.min(advancedScreenHeight() - advancedPanel.height - 12,
            oldCenterY - advancedPanel.height / 2));
    }

    function toggleAdvancedMaximized() {
        if (advancedMaximized) {
            advancedPanel.width = advancedRestoreWidth;
            advancedPanel.height = advancedRestoreHeight;
            advancedPanel.x = advancedRestoreX;
            advancedPanel.y = advancedRestoreY;
            advancedWidth = advancedRestoreWidth;
            advancedHeight = advancedRestoreHeight;
            advancedMaximized = false;
        } else {
            advancedRestoreWidth = advancedPanel.width;
            advancedRestoreHeight = advancedPanel.height;
            advancedRestoreX = advancedPanel.x;
            advancedRestoreY = advancedPanel.y;
            advancedWidth = advancedScreenWidth() - 24;
            advancedHeight = advancedScreenHeight() - 24;
            advancedPanel.width = advancedWidth;
            advancedPanel.height = advancedHeight;
            advancedPanel.x = 12;
            advancedPanel.y = 12;
            advancedMaximized = true;
        }
    }

    implicitWidth: 38
    implicitHeight: 34
    radius: 17
    color: displayMouse.containsMouse || displayPopup.visible ? Qt.lighter(accent, 1.10) : accent
    border.width: displayPopup.visible ? 1 : 0
    border.color: Qt.rgba(accentText.r, accentText.g, accentText.b, 0.4)
    scale: displayMouse.pressed ? 0.93 : (displayMouse.containsMouse ? 1.05 : 1)

    Behavior on color { ColorAnimation { duration: Theme.animNormal } }
    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutBack } }

    Text {
        anchors.centerIn: parent
        text: "󰍹"
        color: Theme.foregroundFor(root.color)
        font.family: Theme.iconFontFamily
        font.pixelSize: 19
    }

    MouseArea {
        id: displayMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: displayPopup.visible = !displayPopup.visible
    }

    HyprmoncfgBackend { id: backend }

    Timer {
        interval: 5000
        repeat: true
        running: displayPopup.visible
        triggeredOnStart: true
        onTriggered: backend.refresh()
    }

    component ActionButton: Rectangle {
        id: button
        required property string label
        property string icon: ""
        property color buttonColor: root.cardColor
        property color labelColor: root.textColor
        property bool outlined: true
        signal clicked()

        implicitHeight: 38
        implicitWidth: buttonRow.implicitWidth + 24
        radius: 11
        color: buttonMouse.containsMouse ? Qt.lighter(buttonColor, 1.12) : buttonColor
        border.width: outlined ? 1 : 0
        border.color: root.borderColor
        enabled: !backend.busy
        opacity: enabled ? 1 : 0.55

        RowLayout {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 7
            Text {
                visible: button.icon.length > 0
                text: button.icon
                color: button.labelColor
                font.family: Theme.iconFontFamily
                font.pixelSize: 14
            }
            Text {
                text: button.label
                color: button.labelColor
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: true
            }
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

    PopupWindow {
        id: displayPopup
        visible: false
        grabFocus: true
        color: "transparent"
        implicitWidth: 680
        implicitHeight: 600

        onVisibleChanged: {
            if (visible) {
                panel.opacity = 0;
                panel.scale = 0.96;
                openAnimation.restart();
                backend.refresh();
            } else {
                openAnimation.stop();
            }
        }

        anchor.window: root.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return;
            var win = anchor.window;
            var itemPos = win.contentItem.mapFromItem(root, 0, 0);
            if (win.height > win.width) {
                displayPopup.anchor.rect.x = Number(win.x || 0) > 100 ? -displayPopup.width - 8 : win.width + 8;
                displayPopup.anchor.rect.y = Math.max(8, Math.min(itemPos.y, win.height - displayPopup.height - 8));
            } else {
                displayPopup.anchor.rect.x = Math.max(8, Math.min(itemPos.x + root.width / 2 - displayPopup.width / 2,
                    win.width - displayPopup.width - 8));
                displayPopup.anchor.rect.y = win.height + 8;
            }
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: 18
            color: root.panelColor
            border.width: 1
            border.color: root.borderColor
            opacity: 0
            scale: 0.96

            SequentialAnimation {
                id: openAnimation
                PauseAnimation { duration: 20 }
                ParallelAnimation {
                    NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 190; easing.type: Easing.OutCubic }
                    NumberAnimation { target: panel; property: "scale"; to: 1; duration: 240; easing.type: Easing.OutBack }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        width: 42; height: 42; radius: 13
                        color: root.accent
                        Text { anchors.centerIn: parent; text: "󰍹"; color: root.accentText; font.family: Theme.iconFontFamily; font.pixelSize: 21 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Display Studio"; color: root.textColor; font.family: Theme.fontFamily; font.pixelSize: 18; font.bold: true }
                        Text {
                            text: backend.daemonActive
                                ? (backend.activeProfile + " · Automatic switching active")
                                : "Manual mode · Current Quickshell layout preserved"
                            color: root.mutedColor; font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                    }
                    Rectangle {
                        radius: 10
                        color: backend.daemonActive ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.16) : root.cardColor
                        border.width: 1; border.color: backend.daemonActive ? Theme.green : root.borderColor
                        implicitWidth: stateText.implicitWidth + 20; implicitHeight: 30
                        Text {
                            id: stateText; anchors.centerIn: parent
                            text: backend.daemonActive ? "LIVE" : "MANUAL"
                            color: backend.daemonActive ? Theme.green : root.mutedColor
                            font.family: Theme.monoFontFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: backend.monitors
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 112
                            radius: 14
                            color: root.cardColor
                            border.width: 1
                            border.color: modelData.focused ? root.accent : root.borderColor
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 3
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "󰍹"; color: root.accent; font.family: Theme.iconFontFamily; font.pixelSize: 18 }
                                    Text { text: modelData.name; color: root.textColor; font.family: Theme.monoFontFamily; font.pixelSize: 12; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Text { visible: modelData.focused; text: "ACTIVE"; color: root.accent; font.family: Theme.monoFontFamily; font.pixelSize: 9; font.bold: true }
                                }
                                Text {
                                    Layout.fillWidth: true; text: modelData.description
                                    color: root.mutedColor; elide: Text.ElideRight
                                    font.family: Theme.fontFamily; font.pixelSize: 10
                                }
                                Text {
                                    text: modelData.width + "×" + modelData.height + "  ·  "
                                        + Math.round(modelData.refreshRate) + " Hz  ·  "
                                        + Number(modelData.scale).toFixed(2) + "×"
                                    color: root.textColor; font.family: Theme.monoFontFamily; font.pixelSize: 11
                                }
                                Text {
                                    text: "Position " + modelData.x + ", " + modelData.y + "  ·  VRR " + (modelData.vrr ? "On" : "Off")
                                    color: root.mutedColor; font.family: Theme.fontFamily; font.pixelSize: 10
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    ActionButton {
                        label: "Display controls"; icon: "󰏘"
                        buttonColor: root.accent; labelColor: root.accentText; outlined: false
                        onClicked: {
                            displayPopup.visible = false;
                            advancedPopup.visible = true;
                        }
                    }
                    ActionButton {
                        label: "Safe TUI"; icon: "󰆍"
                        onClicked: backend.openEditor()
                    }
                    ActionButton {
                        label: "Refresh"; icon: "󰑓"
                        onClicked: backend.refresh()
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: backend.installed ? ("hyprmoncfg " + backend.version) : "hyprmoncfg missing"
                        color: root.mutedColor; font.family: Theme.monoFontFamily; font.pixelSize: 10
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.borderColor }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "PROFILES"; color: root.mutedColor; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2 }
                    Item { Layout.fillWidth: true }
                    Text { text: backend.profiles.length + " saved"; color: root.mutedColor; font.family: Theme.monoFontFamily; font.pixelSize: 10 }
                }

                Basic.ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    clip: true
                    ColumnLayout {
                        width: parent.width
                        spacing: 6
                        Text {
                            visible: backend.profiles.length === 0
                            text: "No profiles yet. Save the current layout below."
                            color: root.mutedColor; font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                        Repeater {
                            model: backend.profiles
                            delegate: Rectangle {
                                required property string modelData
                                property bool deleteArmed: false
                                Layout.fillWidth: true; Layout.preferredHeight: 42
                                radius: 10; color: root.cardColor; border.width: 1; border.color: root.borderColor
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                                    Text { text: "󰆓"; color: root.accent; font.family: Theme.iconFontFamily; font.pixelSize: 14 }
                                    Text { Layout.fillWidth: true; text: modelData; color: root.textColor; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                                    ActionButton { label: "Apply"; implicitHeight: 30; onClicked: backend.applyProfile(modelData) }
                                    ActionButton {
                                        label: parent.parent.deleteArmed ? "Confirm" : "Delete"
                                        implicitHeight: 30
                                        labelColor: Theme.red
                                        onClicked: {
                                            if (parent.parent.deleteArmed) backend.deleteProfile(modelData);
                                            else {
                                                parent.parent.deleteArmed = true;
                                                deleteReset.restart();
                                            }
                                        }
                                    }
                                }
                                Timer { id: deleteReset; interval: 4000; repeat: false; onTriggered: parent.deleteArmed = false }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Basic.TextField {
                        id: profileName
                        Layout.fillWidth: true
                        placeholderText: "Profile name"
                        text: "linuxlifex-dual"
                        color: root.textColor
                        placeholderTextColor: root.mutedColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        selectByMouse: true
                        background: Rectangle { radius: 10; color: root.cardColor; border.width: 1; border.color: profileName.activeFocus ? root.accent : root.borderColor }
                    }
                    ActionButton { label: "Save current layout"; icon: "󰆓"; onClicked: backend.saveProfile(profileName.text) }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    radius: 14
                    color: root.cardColor
                    border.width: 1
                    border.color: backend.daemonActive ? Theme.green : root.borderColor
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { text: "Automatic profile switching"; color: root.textColor; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true }
                            Text {
                                Layout.fillWidth: true
                                text: backend.daemonActive
                                    ? "hyprmoncfg owns hot-plug changes; the previous monitor watcher is paused."
                                    : "Enable after saving a profile. Your old monitor settings remain available."
                                color: root.mutedColor; font.family: Theme.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap
                            }
                        }
                        ActionButton {
                            label: backend.daemonActive ? "Disable" : "Enable"
                            buttonColor: backend.daemonActive ? root.cardColor : root.accent
                            labelColor: backend.daemonActive ? Theme.red : root.accentText
                            outlined: backend.daemonActive
                            onClicked: backend.daemonActive ? backend.disableManagement() : backend.enableManagement()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: backend.busy || backend.message.length > 0 || backend.errorMessage.length > 0
                    text: backend.busy ? "Working…" : (backend.errorMessage.length > 0 ? backend.errorMessage : backend.message)
                    color: backend.errorMessage.length > 0 ? Theme.red : (backend.busy ? root.mutedColor : Theme.green)
                    font.family: Theme.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap
                }
            }
        }
    }

    Timer {
        id: profileSyncDelay
        interval: 1300
        repeat: false
        onTriggered: backend.syncCurrentProfile()
    }

    PanelWindow {
        id: advancedPopup
        visible: false
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        function initializePanelGeometry() {
            if (!visible || width < 1 || height < 1) return false;

            advancedPanel.width = Math.max(advancedPanel.minW,
                Math.min(root.advancedWidth, width - 24));
            advancedPanel.height = Math.max(advancedPanel.minH,
                Math.min(root.advancedHeight, height - 24));
            advancedPanel.x = Math.max(12, (width - advancedPanel.width) / 2);
            advancedPanel.y = Math.max(12, (height - advancedPanel.height) / 2);
            advancedPanel.geometryInitialized = true;
            return true;
        }

        onWidthChanged: {
            if (visible && !advancedPanel.geometryInitialized) initializePanelGeometry();
        }
        onHeightChanged: {
            if (visible && !advancedPanel.geometryInitialized) initializePanelGeometry();
        }

        onVisibleChanged: {
            if (visible) {
                advancedPanel.geometryInitialized = false;
                Qt.callLater(advancedPopup.initializePanelGeometry);
                advancedPanel.opacity = 0;
                advancedPanel.scale = 0.97;
                advancedOpen.restart();
                monitorSettingsLoader.active = true;
                Qt.callLater(function() {
                    if (monitorSettingsLoader.item) monitorSettingsLoader.item.refresh();
                });
            } else {
                advancedOpen.stop();
                if (monitorSettingsLoader.item) monitorSettingsLoader.item.cancelPendingPreview();
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: advancedPopup.visible
            onActivated: advancedPopup.visible = false
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) {
                    var outsidePanel = mouse.x < advancedPanel.x
                        || mouse.x > advancedPanel.x + advancedPanel.width
                        || mouse.y < advancedPanel.y
                        || mouse.y > advancedPanel.y + advancedPanel.height;
                    if (outsidePanel) advancedPopup.visible = false;
                    mouse.accepted = true;
                }
            }
        }

        Rectangle {
            id: advancedPanel
            width: 1320
            height: 900
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            radius: 18
            color: root.panelColor
            border.width: 1
            border.color: root.borderColor
            clip: true

            property real minW: 980
            property real minH: 680
            property bool resizing: false
            property bool geometryInitialized: false
            property point startMousePos
            property size startSize
            property point startPos
            property point moveStartMousePos
            property point moveStartPos

            function startMove(mouseArea, mouse) {
                var global = mouseArea.mapToGlobal(mouse.x, mouse.y);
                moveStartMousePos = Qt.point(global.x, global.y);
                moveStartPos = Qt.point(x, y);
            }

            function updateMove(mouseArea, mouse) {
                var global = mouseArea.mapToGlobal(mouse.x, mouse.y);
                var nextX = moveStartPos.x + global.x - moveStartMousePos.x;
                var nextY = moveStartPos.y + global.y - moveStartMousePos.y;
                var maxX = Math.max(12, advancedPopup.width - width - 12);
                var maxY = Math.max(12, advancedPopup.height - height - 12);
                x = Math.max(12, Math.min(maxX, nextX));
                y = Math.max(12, Math.min(maxY, nextY));
            }

            function startResize(mouseArea, mouse) {
                resizing = true;
                root.advancedMaximized = false;
                var global = mouseArea.mapToGlobal(mouse.x, mouse.y);
                startMousePos = Qt.point(global.x, global.y);
                startSize = Qt.size(width, height);
                startPos = Qt.point(x, y);
            }

            function endResize() {
                resizing = false;
                root.advancedWidth = Math.round(width);
                root.advancedHeight = Math.round(height);
            }

            function updateResize(mouseArea, mouse, isLeft, isTop, isHorizontal, isVertical) {
                var global = mouseArea.mapToGlobal(mouse.x, mouse.y);
                var dx = isHorizontal ? global.x - startMousePos.x : 0;
                var dy = isVertical ? global.y - startMousePos.y : 0;
                var newW = width;
                var newH = height;
                var newX = x;
                var newY = y;

                if (dx !== 0) {
                    if (isLeft) {
                        newW = Math.max(minW, startSize.width - dx);
                        if (newW !== startSize.width - dx) dx = startSize.width - newW;
                        newX = startPos.x + dx;
                    } else {
                        newW = Math.max(minW, startSize.width + dx);
                    }
                }

                if (dy !== 0) {
                    if (isTop) {
                        newH = Math.max(minH, startSize.height - dy);
                        if (newH !== startSize.height - dy) dy = startSize.height - newH;
                        newY = startPos.y + dy;
                    } else {
                        newH = Math.max(minH, startSize.height + dy);
                    }
                }

                x = newX;
                y = newY;
                width = newW;
                height = newH;
            }

            Behavior on width { enabled: !advancedPanel.resizing; NumberAnimation { duration: 0 } }
            Behavior on height { enabled: !advancedPanel.resizing; NumberAnimation { duration: 0 } }

            SequentialAnimation {
                id: advancedOpen
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: advancedPanel; property: "opacity"; to: 1; duration: 190; easing.type: Easing.OutCubic }
                    NumberAnimation { target: advancedPanel; property: "scale"; to: 1; duration: 230; easing.type: Easing.OutBack }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ActionButton {
                        label: "Back"; icon: "󰁍"
                        onClicked: {
                            advancedPopup.visible = false;
                            displayPopup.visible = true;
                        }
                    }

                    Rectangle {
                        width: 40; height: 40; radius: 12
                        color: root.accent
                        Text { anchors.centerIn: parent; text: "󰍹"; color: root.accentText; font.family: Theme.iconFontFamily; font.pixelSize: 20 }
                    }

                    Item {
                        id: advancedTitleArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: "Display Studio · Advanced Controls"
                                color: root.textColor; font.family: Theme.fontFamily; font.pixelSize: 17; font.bold: true
                            }
                            Text {
                                text: "Resolution · Refresh rate · Scale · Position · HDR · 10-bit · VRR · ICC"
                                color: root.mutedColor; font.family: Theme.fontFamily; font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.advancedMaximized
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.SizeAllCursor : Qt.ArrowCursor
                            onPressed: (mouse) => advancedPanel.startMove(this, mouse)
                            onPositionChanged: (mouse) => {
                                if (pressed) advancedPanel.updateMove(this, mouse);
                            }
                        }
                    }

                    ActionButton {
                        label: "−"
                        implicitWidth: 38
                        onClicked: root.resizeAdvanced(-120, -80)
                    }

                    Text {
                        text: Math.round(advancedPanel.width) + " × " + Math.round(advancedPanel.height)
                        color: root.mutedColor
                        font.family: Theme.monoFontFamily
                        font.pixelSize: 9
                    }

                    ActionButton {
                        label: "+"
                        implicitWidth: 38
                        onClicked: root.resizeAdvanced(120, 80)
                    }

                    ActionButton {
                        label: root.advancedMaximized ? "Restore" : "Maximize"
                        icon: root.advancedMaximized ? "󰁌" : "󰊓"
                        onClicked: root.toggleAdvancedMaximized()
                    }

                    Rectangle {
                        radius: 9
                        color: Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.14)
                        border.width: 1; border.color: Theme.green
                        implicitWidth: syncLabel.implicitWidth + 20; implicitHeight: 30
                        Text {
                            id: syncLabel
                            anchors.centerIn: parent
                            text: profileSyncDelay.running || backend.busy ? "SYNCING" : "PROFILE LINKED"
                            color: Theme.green; font.family: Theme.monoFontFamily; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8
                        }
                    }

                    ActionButton {
                        label: "×"
                        implicitWidth: 38
                        labelColor: Theme.red
                        onClicked: advancedPopup.visible = false
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.borderColor }

                Loader {
                    id: monitorSettingsLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: false
                    sourceComponent: Component {
                        Sys.MonitorsPage {
                            onSettingsApplied: profileSyncDelay.restart()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: backend.message.length > 0 || backend.errorMessage.length > 0
                    text: backend.errorMessage.length > 0 ? backend.errorMessage : backend.message
                    color: backend.errorMessage.length > 0 ? Theme.red : Theme.green
                    font.family: Theme.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap
                }
            }

            MouseArea {
                width: 10; height: parent.height
                anchors.right: parent.right
                cursorShape: Qt.SizeHorCursor
                onPressed: (mouse) => advancedPanel.startResize(this, mouse)
                onPositionChanged: (mouse) => advancedPanel.updateResize(this, mouse, false, false, true, false)
                onReleased: advancedPanel.endResize()
                onCanceled: advancedPanel.endResize()
                z: 500
            }
            MouseArea {
                width: 10; height: parent.height
                anchors.left: parent.left
                cursorShape: Qt.SizeHorCursor
                onPressed: (mouse) => advancedPanel.startResize(this, mouse)
                onPositionChanged: (mouse) => advancedPanel.updateResize(this, mouse, true, false, true, false)
                onReleased: advancedPanel.endResize()
                onCanceled: advancedPanel.endResize()
                z: 500
            }
            MouseArea {
                height: 10; width: parent.width
                anchors.bottom: parent.bottom
                cursorShape: Qt.SizeVerCursor
                onPressed: (mouse) => advancedPanel.startResize(this, mouse)
                onPositionChanged: (mouse) => advancedPanel.updateResize(this, mouse, false, false, false, true)
                onReleased: advancedPanel.endResize()
                onCanceled: advancedPanel.endResize()
                z: 500
            }
            MouseArea {
                height: 10; width: parent.width
                anchors.top: parent.top
                cursorShape: Qt.SizeVerCursor
                onPressed: (mouse) => advancedPanel.startResize(this, mouse)
                onPositionChanged: (mouse) => advancedPanel.updateResize(this, mouse, false, true, false, true)
                onReleased: advancedPanel.endResize()
                onCanceled: advancedPanel.endResize()
                z: 500
            }
            MouseArea {
                width: 30; height: 30
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                cursorShape: Qt.SizeFDiagCursor
                onPressed: (mouse) => advancedPanel.startResize(this, mouse)
                onPositionChanged: (mouse) => advancedPanel.updateResize(this, mouse, false, false, true, true)
                onReleased: advancedPanel.endResize()
                onCanceled: advancedPanel.endResize()
                z: 501
            }
            MouseArea {
                width: 30; height: 30
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                cursorShape: Qt.SizeBDiagCursor
                onPressed: (mouse) => advancedPanel.startResize(this, mouse)
                onPositionChanged: (mouse) => advancedPanel.updateResize(this, mouse, true, false, true, true)
                onReleased: advancedPanel.endResize()
                onCanceled: advancedPanel.endResize()
                z: 501
            }
            MouseArea {
                width: 30; height: 30
                anchors.top: parent.top
                anchors.right: parent.right
                cursorShape: Qt.SizeBDiagCursor
                onPressed: (mouse) => advancedPanel.startResize(this, mouse)
                onPositionChanged: (mouse) => advancedPanel.updateResize(this, mouse, false, true, true, true)
                onReleased: advancedPanel.endResize()
                onCanceled: advancedPanel.endResize()
                z: 501
            }
            MouseArea {
                width: 30; height: 30
                anchors.top: parent.top
                anchors.left: parent.left
                cursorShape: Qt.SizeFDiagCursor
                onPressed: (mouse) => advancedPanel.startResize(this, mouse)
                onPositionChanged: (mouse) => advancedPanel.updateResize(this, mouse, true, true, true, true)
                onReleased: advancedPanel.endResize()
                onCanceled: advancedPanel.endResize()
                z: 501
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 7
                text: "◢"
                color: root.accent
                opacity: 0.75
                font.family: Theme.fontFamily
                font.pixelSize: 14
                z: 499
            }
        }
    }
}
