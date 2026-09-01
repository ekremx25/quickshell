import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Basic
import Quickshell
import Quickshell.Wayland
import "../../../Widgets"
import "../../../Services" as S
import "Model.js" as Model

Rectangle {
    id: root

    readonly property string schemePresentation: S.ColorPaletteService.schemePresentation(
        S.ColorPaletteService.matugenType)
    readonly property bool directMaterialRoles: S.ColorPaletteService.enabled
        && schemePresentation === "material"
    readonly property string paletteLabel: S.ColorPaletteService.enabled
        ? S.ColorPaletteService.schemeLabel(S.ColorPaletteService.matugenType)
        : Theme.currentThemeName

    // Standard Material schemes expose proper Material 3 colour roles. Read
    // them directly so every matugen variant updates this panel immediately.
    // Authored and special presentations continue through Theme, where their
    // semantic Catppuccin/Kanagawa/Tokyo/Monochrome mappings already live.
    readonly property color preferredTextColor: directMaterialRoles
        ? S.ColorPaletteService.surfaceOnColor : Theme.text
    readonly property color accent: directMaterialRoles
        ? S.ColorPaletteService.primaryColor : Theme.systemColor
    readonly property color chipText: directMaterialRoles
        ? S.ColorPaletteService.primaryOnColor : Theme.foregroundFor(accent)
    readonly property color panelColor: directMaterialRoles
        ? solidColor(S.ColorPaletteService.backgroundColor)
        : solidColor(Theme.background)
    readonly property color cardColor: directMaterialRoles
        ? mixColor(S.ColorPaletteService.surfaceColor,
                   S.ColorPaletteService.surfaceVariantColor, 0.22)
        : solidColor(Theme.surface)
    readonly property color textColor: contrastText(preferredTextColor, panelColor, 4.5)
    readonly property color cardTextColor: contrastText(preferredTextColor, cardColor, 4.5)
    readonly property color mutedColor: contrastText(
        directMaterialRoles
            ? S.ColorPaletteService.surfaceVariantOnColor
            : mixColor(textColor, panelColor, 0.30),
        panelColor, 3.0)
    readonly property color cardMutedColor: contrastText(
        directMaterialRoles
            ? S.ColorPaletteService.surfaceVariantOnColor
            : mixColor(cardTextColor, cardColor, 0.32),
        cardColor, 3.0)
    readonly property color softBorder: directMaterialRoles
        ? alphaColor(S.ColorPaletteService.outlineColor, 0.52)
        : alphaColor(textColor, 0.10)
    readonly property color layerFaint: alphaColor(textColor, 0.035)
    readonly property color layerLow: alphaColor(textColor, 0.06)
    readonly property color layerMedium: alphaColor(textColor, 0.10)
    readonly property color layerHigh: alphaColor(textColor, 0.15)
    readonly property color cpuAccent: directMaterialRoles
        ? S.ColorPaletteService.tertiaryColor : Theme.cpuColor
    readonly property color memoryAccent: directMaterialRoles
        ? S.ColorPaletteService.primaryColor : Theme.ramColor
    readonly property color gpuAccent: directMaterialRoles
        ? S.ColorPaletteService.errorColor : Theme.gpuColor
    readonly property color diskAccent: directMaterialRoles
        ? S.ColorPaletteService.secondaryColor : Theme.diskColor
    readonly property color networkAccent: directMaterialRoles
        ? S.ColorPaletteService.tertiaryColor : Theme.bluetoothColor
    readonly property color dangerAccent: directMaterialRoles
        ? S.ColorPaletteService.errorColor : Theme.red
    readonly property var temperature: Model.cpuTemperature(activity.thermalSnapshot.temperatures)
    readonly property var storageVolume: Model.selectStorageVolume(
        Model.storageVolumes(activity.storageSnapshot), "", false)
    readonly property var gpu: activity.gpus.length > 0 ? activity.gpus[0] : null
    readonly property var filteredProcesses: Model.filterAndSortProcesses(
        activity.processes, processSearch.text, sortKey, false)

    property bool expanded: false
    property bool transitionRunning: false
    property bool pendingExpanded: false
    property string sortKey: "cpu"

    function solidColor(value) {
        return Qt.rgba(value.r, value.g, value.b, 1);
    }

    function alphaColor(value, alpha) {
        return Qt.rgba(value.r, value.g, value.b, alpha);
    }

    function mixColor(first, second, amount) {
        var t = Math.max(0, Math.min(1, Number(amount)));
        return Qt.rgba(
            first.r * (1 - t) + second.r * t,
            first.g * (1 - t) + second.g * t,
            first.b * (1 - t) + second.b * t,
            1);
    }

    function linearChannel(value) {
        return value <= 0.04045
            ? value / 12.92
            : Math.pow((value + 0.055) / 1.055, 2.4);
    }

    function luminance(value) {
        return 0.2126 * linearChannel(value.r)
            + 0.7152 * linearChannel(value.g)
            + 0.0722 * linearChannel(value.b);
    }

    function contrastRatio(first, second) {
        var lighter = Math.max(luminance(first), luminance(second));
        var darker = Math.min(luminance(first), luminance(second));
        return (lighter + 0.05) / (darker + 0.05);
    }

    function contrastText(preferred, background, minimum) {
        var candidate = solidColor(preferred);
        return contrastRatio(candidate, background) >= minimum
            ? candidate
            : Theme.foregroundFor(background);
    }

    function toggleDetails() {
        if (transitionRunning || !activityPopup.visible) return;
        pendingExpanded = !expanded;
        transitionRunning = true;
        detailTransition.restart();
        sweepTransition.restart();
    }

    function percent(value) {
        var number = Number(value);
        return isFinite(number) && number >= 0 ? Math.round(number) + "%" : "—";
    }

    function bytes(value, suffix) {
        return Model.formatBytes(Number(value) || 0, suffix || "");
    }

    function temperatureText() {
        return temperature ? Model.formatTemperature(temperature.value, "Celsius") : "—";
    }

    function gpuMemoryText() {
        if (!gpu || Number(gpu.memoryTotal) <= 0) return "Memory unavailable";
        return bytes(gpu.memoryUsed) + " / " + bytes(gpu.memoryTotal);
    }

    function storageText() {
        if (!storageVolume || Number(storageVolume.total) <= 0) return "Storage unavailable";
        return bytes(storageVolume.used) + " / " + bytes(storageVolume.total);
    }

    function storagePercent() {
        return storageVolume ? Math.round(Model.storageUsedFraction(storageVolume) * 100) + "%" : "—";
    }

    implicitWidth: compactRow.implicitWidth + 20
    implicitHeight: 34
    radius: 17
    color: activityMouse.containsMouse || activityPopup.visible ? Qt.lighter(accent, 1.08) : accent
    border.width: 1
    border.color: activityPopup.visible
        ? Qt.rgba(chipText.r, chipText.g, chipText.b, 0.42)
        : "transparent"
    scale: activityMouse.pressed ? 0.94 : (activityMouse.containsMouse ? 1.04 : 1)

    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutBack } }
    Behavior on color { ColorAnimation { duration: Theme.animNormal } }

    component MetricCard: Rectangle {
        required property string title
        required property string value
        property string subtitle: ""
        property color accentColor: root.accent
        readonly property color readableAccent: root.contrastText(accentColor, root.cardColor, 3.0)
        property var sparkValues: []
        property real sparkCeiling: 0

        Layout.fillWidth: true
        Layout.preferredHeight: 150
        radius: 14
        color: root.cardColor
        border.width: 1
        border.color: root.softBorder

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 4

            Text {
                text: title.toUpperCase()
                color: root.cardMutedColor
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.1
            }
            Text {
                text: value
                color: readableAccent
                font.family: Theme.monoFontFamily
                font.pixelSize: 25
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: subtitle
                color: root.cardMutedColor
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Item { Layout.fillHeight: true }
            ActivitySparkline {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                values: sparkValues
                ceiling: sparkCeiling
                lineColor: accentColor
            }
        }
    }

    RowLayout {
        id: compactRow
        anchors.centerIn: parent
        spacing: 7

        Text {
            text: "󰓅"
            color: root.chipText
            font.family: Theme.iconFontFamily
            font.pixelSize: 17
        }
        Text {
            text: "Activity"
            color: root.chipText
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: true
        }
    }

    MouseArea {
        id: activityMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: activityPopup.visible = !activityPopup.visible
    }

    ActivityController {
        id: activity
        active: activityPopup.visible
        expanded: root.expanded
        processPowerEnabled: false
        settings: ({
            samplingSpeed: "Balanced",
            historySamples: 60,
            temperatureUnit: "Celsius",
            processPowerEnabled: false
        })
    }

    PopupWindow {
        id: activityPopup

        visible: false
        grabFocus: true
        color: "transparent"
        implicitWidth: root.expanded ? 1040 : 650
        implicitHeight: root.expanded ? 720 : 560

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function() { openTransition.restart(); });
            } else {
                detailTransition.stop();
                sweepTransition.stop();
                root.transitionRunning = false;
                panelContent.opacity = 1;
                panelContent.scale = 1;
                contentTranslate.y = 0;
                root.expanded = false;
                processSearch.text = "";
            }
        }

        anchor.window: root.QsWindow.window
        anchor.onAnchoring: {
            if (!anchor.window) return;
            var win = anchor.window;
            var itemPos = win.contentItem.mapFromItem(root, 0, 0);
            var vertical = win.height > win.width;
            if (vertical) {
                var opensLeft = Number(win.x || 0) > 100;
                activityPopup.anchor.rect.x = opensLeft ? -activityPopup.width - 6 : win.width + 6;
                activityPopup.anchor.rect.y = Math.max(6, Math.min(
                    itemPos.y + root.height / 2 - activityPopup.height / 2,
                    win.height - activityPopup.height - 6));
            } else {
                var opensUp = Number(win.y || 0) > 100;
                activityPopup.anchor.rect.x = Math.max(6, Math.min(
                    itemPos.x + root.width / 2 - activityPopup.width / 2,
                    win.width - activityPopup.width - 6));
                activityPopup.anchor.rect.y = opensUp ? -activityPopup.height - 6 : win.height + 6;
            }
        }

        ParallelAnimation {
            id: openTransition
            NumberAnimation {
                target: panelSurface
                property: "opacity"
                from: 0
                to: 1
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: panelSurface
                property: "scale"
                from: 0.965
                to: 1
                duration: 240
                easing.type: Easing.OutBack
                easing.overshoot: 0.65
            }
        }

        SequentialAnimation {
            id: detailTransition

            ParallelAnimation {
                NumberAnimation {
                    target: panelContent
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 85
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: contentTranslate
                    property: "y"
                    from: 0
                    to: -7
                    duration: 85
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: panelContent
                    property: "scale"
                    from: 1
                    to: 0.992
                    duration: 85
                    easing.type: Easing.InCubic
                }
            }

            ScriptAction { script: root.expanded = root.pendingExpanded }
            PropertyAction { target: contentTranslate; property: "y"; value: 9 }
            PauseAnimation { duration: 18 }

            ParallelAnimation {
                NumberAnimation {
                    target: panelContent
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 205
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: contentTranslate
                    property: "y"
                    from: 9
                    to: 0
                    duration: 225
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: panelContent
                    property: "scale"
                    from: 0.992
                    to: 1
                    duration: 225
                    easing.type: Easing.OutCubic
                }
            }

            ScriptAction { script: root.transitionRunning = false }
        }

        ParallelAnimation {
            id: sweepTransition
            NumberAnimation {
                target: transitionSweep
                property: "x"
                from: -180
                to: 1100
                duration: 410
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: transitionSweep
                    property: "opacity"
                    from: 0
                    to: 0.82
                    duration: 70
                    easing.type: Easing.OutCubic
                }
                PauseAnimation { duration: 170 }
                NumberAnimation {
                    target: transitionSweep
                    property: "opacity"
                    from: 0.82
                    to: 0
                    duration: 170
                    easing.type: Easing.InCubic
                }
            }
        }

        Rectangle {
            id: panelSurface
            anchors.fill: parent
            radius: 18
            color: root.panelColor
            border.width: 1
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
            clip: true

            Rectangle {
                id: transitionSweep
                z: 20
                x: -180
                y: 0
                width: 180
                height: 2
                radius: 1
                color: root.accent
                opacity: 0
            }

            ColumnLayout {
                id: panelContent
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12
                transform: Translate {
                    id: contentTranslate
                    y: 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 38
                        height: 38
                        radius: 11
                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                        Text {
                            anchors.centerIn: parent
                            text: "󰓅"
                            color: root.accent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 21
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "Activity Monitor"
                            color: root.textColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Text {
                            text: activity.snapshot.sample > 0
                                ? "Uptime " + Model.formatDuration(activity.snapshot.uptime)
                                  + "  •  " + activity.snapshot.tasks.running + " active tasks"
                                  + "  •  " + root.paletteLabel
                                : "Preparing live system metrics…  •  " + root.paletteLabel
                            color: root.mutedColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Basic.Button {
                        id: refreshButton
                        implicitWidth: 34
                        implicitHeight: 34
                        background: Rectangle {
                            radius: 10
                            color: refreshButton.hovered ? root.layerHigh : root.layerLow
                        }
                        contentItem: Text {
                            text: "󰑓"
                            color: root.textColor
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: activity.refresh()
                    }

                    Basic.Button {
                        id: expandButton
                        enabled: !root.transitionRunning
                        implicitWidth: 102
                        implicitHeight: 34
                        scale: pressed ? 0.96 : (hovered ? 1.03 : 1)
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.animNormal
                                easing.type: Easing.OutBack
                            }
                        }
                        background: Rectangle {
                            radius: 10
                            color: root.expanded
                                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.17)
                                : (expandButton.hovered ? root.layerHigh : root.layerLow)
                            border.width: 1
                            border.color: root.expanded
                                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.70)
                                : root.softBorder
                            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }
                        }
                        contentItem: Text {
                            text: root.expanded ? "Compact  ↙" : "Details  ↗"
                            color: root.expanded ? root.accent : root.textColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                        }
                        onClicked: root.toggleDetails()
                    }

                    Basic.Button {
                        id: closeButton
                        implicitWidth: 34
                        implicitHeight: 34
                        background: Rectangle {
                            radius: 10
                            color: closeButton.hovered ? root.alphaColor(root.dangerAccent, 0.20) : "transparent"
                        }
                        contentItem: Text {
                            text: "✕"
                            color: closeButton.hovered ? root.dangerAccent : root.mutedColor
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: activityPopup.visible = false
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.expanded ? 3 : 2
                    columnSpacing: 10
                    rowSpacing: 10

                    MetricCard {
                        title: "Processor"
                        value: root.percent(activity.metrics.cpu)
                        subtitle: root.temperatureText()
                            + (activity.snapshot.cpuFrequencyMHz > 0
                                ? "  •  " + Math.round(activity.snapshot.cpuFrequencyMHz) + " MHz"
                                : "")
                        accentColor: root.cpuAccent
                        sparkValues: activity.metrics.cpuHistory
                        sparkCeiling: 100
                    }

                    MetricCard {
                        title: "Memory"
                        value: root.percent(activity.metrics.memory)
                        subtitle: root.bytes(Math.max(0,
                            activity.snapshot.memory.total - activity.snapshot.memory.available))
                            + " / " + root.bytes(activity.snapshot.memory.total)
                        accentColor: root.memoryAccent
                        sparkValues: activity.metrics.memoryHistory
                        sparkCeiling: 100
                    }

                    MetricCard {
                        visible: root.expanded
                        title: root.gpu ? root.gpu.vendor + " Graphics" : "Graphics"
                        value: root.gpu ? root.percent(root.gpu.usage) : "Detecting…"
                        subtitle: root.gpuMemoryText()
                            + (root.gpu && root.gpu.frequencyMHz > 0
                                ? "  •  " + Math.round(root.gpu.frequencyMHz) + " MHz"
                                : "")
                        accentColor: root.gpuAccent
                        sparkValues: []
                        sparkCeiling: 100
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 82
                        radius: 13
                        color: root.cardColor
                        border.width: 1
                        border.color: root.softBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 14

                            Text { text: "󰖟"; color: root.networkAccent; font.family: Theme.iconFontFamily; font.pixelSize: 23 }
                            ColumnLayout {
                                spacing: 2
                                Text { text: "NETWORK"; color: root.cardMutedColor; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                                Text {
                                    text: "↓ " + root.bytes(activity.metrics.download, "/s")
                                        + "    ↑ " + root.bytes(activity.metrics.upload, "/s")
                                    color: root.cardTextColor
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: activity.metrics.networkInterface || "No active interface"
                                    color: root.cardMutedColor
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 82
                        radius: 13
                        color: root.cardColor
                        border.width: 1
                        border.color: root.softBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 14

                            Text { text: "󰋊"; color: root.diskAccent; font.family: Theme.iconFontFamily; font.pixelSize: 23 }
                            ColumnLayout {
                                spacing: 2
                                Text { text: "DISK ACTIVITY"; color: root.cardMutedColor; font.family: Theme.fontFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                                Text {
                                    text: "R " + root.bytes(activity.metrics.diskRead, "/s")
                                        + "    W " + root.bytes(activity.metrics.diskWrite, "/s")
                                    color: root.cardTextColor
                                    font.family: Theme.monoFontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: root.expanded ? root.storageText() : "All devices"
                                    color: root.cardMutedColor
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                visible: root.expanded
                                text: root.storagePercent()
                                color: root.diskAccent
                                font.family: Theme.monoFontFamily
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.expanded ? "PROCESSES" : "BUSIEST PROCESSES"
                        color: root.mutedColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.1
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: !activity.processMetricsReady
                        text: "Warming up…"
                        color: root.mutedColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                    Basic.TextField {
                        id: processSearch
                        visible: root.expanded
                        Layout.preferredWidth: 240
                        implicitHeight: 32
                        placeholderText: "Search processes"
                        color: root.cardTextColor
                        placeholderTextColor: root.cardMutedColor
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        leftPadding: 11
                        rightPadding: 11
                        background: Rectangle {
                            radius: 9
                            color: root.cardColor
                            border.width: 1
                            border.color: processSearch.activeFocus ? root.accent : root.softBorder
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 13
                    color: root.cardColor
                    border.width: 1
                    border.color: root.softBorder
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            color: root.layerLow

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Text { Layout.fillWidth: true; text: "NAME"; color: root.cardMutedColor; font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true }
                                Text { visible: root.expanded; Layout.preferredWidth: 62; text: "PID"; color: root.cardMutedColor; font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true; horizontalAlignment: Text.AlignRight }
                                Text { Layout.preferredWidth: 66; text: "CPU"; color: root.cardMutedColor; font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true; horizontalAlignment: Text.AlignRight }
                                Text { Layout.preferredWidth: 78; text: "MEMORY"; color: root.cardMutedColor; font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: true; horizontalAlignment: Text.AlignRight }
                            }
                        }

                        ListView {
                            id: processList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: root.expanded ? root.filteredProcesses : root.filteredProcesses.slice(0, 5)

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: processList.width
                                height: root.expanded ? 39 : 43
                                color: processRowMouse.containsMouse
                                    ? root.layerMedium
                                    : (index % 2 ? root.layerFaint : "transparent")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name || "Unknown"
                                            color: root.cardTextColor
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            visible: root.expanded
                                            Layout.fillWidth: true
                                            text: modelData.user || ""
                                            color: root.cardMutedColor
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Text {
                                        visible: root.expanded
                                        Layout.preferredWidth: 62
                                        text: String(modelData.pid)
                                        color: root.cardMutedColor
                                        font.family: Theme.monoFontFamily
                                        font.pixelSize: 10
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    Text {
                                        Layout.preferredWidth: 66
                                        text: root.percent(modelData.cpu)
                                        color: modelData.cpu >= 50 ? root.dangerAccent : root.cpuAccent
                                        font.family: Theme.monoFontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    Text {
                                        Layout.preferredWidth: 78
                                        text: root.bytes(modelData.rss)
                                        color: root.memoryAccent
                                        font.family: Theme.monoFontFamily
                                        font.pixelSize: 10
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                MouseArea {
                                    id: processRowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: processList.count === 0
                                text: activity.processMetricsReady ? "No matching processes" : "Collecting process data…"
                                color: root.cardMutedColor
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Balanced sampling • Active only while this panel is open • No administrator access"
                    color: root.mutedColor
                    opacity: 0.78
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
