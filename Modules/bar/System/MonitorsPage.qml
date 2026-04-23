import QtQuick
import QtQuick.Layouts
import Quickshell
import "."
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette
import "../../../Services"
import "../../../Services/core/Log.js" as Log
import "MonitorGeometry.js" as MonitorGeometry

Item {
    id: page

    MonitorsBackend {
        id: backend
        onRefreshRequested: page.syncSelection()
    }

    property alias outputs: backend.outputs
    property alias selectedIdx: backend.selectedIdx
    property alias selectedOutput: backend.selectedOutput
    property alias colorModeOptions: backend.colorModeOptions
    property alias colorModeLabels: backend.colorModeLabels

    property string selRes: ""
    property string selHz: ""
    property real selScale: 1.0
    property int selPosX: 0
    property int selPosY: 0
    property string defaultMonitorName: ""

    property bool selHdr: false
    property int selBitdepth: 10
    property int selVrr: 2
    property int selSdrLuminance: 450
    property real selSdrBrightness: 1.1
    property real selSdrSaturation: 1.3

    property string selColorManagement: "srgb"
    property int selSdrEotf: 1
    readonly property int sdrLuminanceMin: 80
    readonly property int sdrLuminanceMax: 600
    property bool identifyMode: false
    property var draftSettings: ({})

    readonly property color cardColor: Qt.rgba(245 / 255, 247 / 255, 250 / 255, 0.05)
    readonly property color cardBorder: Qt.rgba(255, 255, 255, 0.08)
    readonly property color softBorder: Qt.rgba(255, 255, 255, 0.05)
    readonly property color accentSoft: Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.14)
    readonly property color accentBorder: Qt.rgba(137 / 255, 180 / 255, 250 / 255, 0.55)

    function getDefaultMonitorName() {
        for (var i = 0; i < outputs.length; i++) {
            if (outputs[i].isDefault) return outputs[i].name;
        }
        if (selectedOutput) return selectedOutput.name;
        return outputs.length > 0 ? outputs[0].name : "";
    }

    function hasOutput(name) {
        for (var i = 0; i < outputs.length; i++) {
            if (outputs[i].name === name) return true;
        }
        return false;
    }

    function syncSelection() {
        if (!selectedOutput) return;
        var draft = draftSettings[selectedOutput.name];
        selRes = draft && draft.res !== undefined ? draft.res : selectedOutput.res;
        selHz = draft && draft.hz !== undefined ? draft.hz : selectedOutput.hz;
        selScale = draft && draft.scale !== undefined ? draft.scale : parseFloat(selectedOutput.scale);
        selPosX = draft && draft.posX !== undefined ? draft.posX : Math.round(selectedOutput.posX || 0);
        selPosY = draft && draft.posY !== undefined ? draft.posY : Math.round(selectedOutput.posY || 0);
        if (!defaultMonitorName || !hasOutput(defaultMonitorName)) defaultMonitorName = getDefaultMonitorName();
        selHdr = draft && draft.hdr !== undefined ? draft.hdr : (selectedOutput.hdr || false);
        selBitdepth = draft && draft.bitdepth !== undefined ? draft.bitdepth : (selectedOutput.bitdepth || 10);
        selVrr = draft && draft.vrr !== undefined ? draft.vrr : ((selectedOutput.vrr !== undefined) ? selectedOutput.vrr : 0);
        selSdrLuminance = draft && draft.sdrLuminance !== undefined ? draft.sdrLuminance : ((selectedOutput.sdrLuminance !== undefined) ? selectedOutput.sdrLuminance : 450);
        selSdrBrightness = draft && draft.sdrBrightness !== undefined ? draft.sdrBrightness : (selectedOutput.sdrBrightness || 1.1);
        selSdrSaturation = draft && draft.sdrSaturation !== undefined ? draft.sdrSaturation : (selectedOutput.sdrSaturation || 1.3);
        selColorManagement = draft && draft.colorManagement !== undefined ? draft.colorManagement : (selectedOutput.colorManagement || "srgb");
        selSdrEotf = draft && draft.sdrEotf !== undefined ? draft.sdrEotf : ((selectedOutput.sdrEotf !== undefined) ? selectedOutput.sdrEotf : 1);
    }

    function saveCurrentDraft() {
        if (!selectedOutput) return;
        var nextDrafts = {};
        for (var key in draftSettings) nextDrafts[key] = draftSettings[key];
        nextDrafts[selectedOutput.name] = {
            res: selRes,
            hz: selHz,
            scale: selScale,
            posX: selPosX,
            posY: selPosY,
            hdr: selHdr,
            bitdepth: selBitdepth,
            vrr: selVrr,
            sdrLuminance: selSdrLuminance,
            sdrBrightness: selSdrBrightness,
            sdrSaturation: selSdrSaturation,
            colorManagement: selColorManagement,
            sdrEotf: selSdrEotf
        };
        draftSettings = nextDrafts;
    }

    function selectOutput(index) {
        saveCurrentDraft();
        selectedIdx = index;
    }

    function isHdrColorMode(mode) {
        return backend.isHdrColorMode(mode);
    }

    function isRiskyColorMode(mode) {
        return backend.isRiskyColorMode(mode);
    }

    function getUniqueRes() {
        return backend.getUniqueRes(selectedOutput);
    }

    function getRefreshRates() {
        return backend.getRefreshRates(selectedOutput, selRes);
    }

    // Carries the live selection state as context to the MonitorGeometry helpers.
    function geoCtx() {
        return {
            selectedName: selectedOutput ? selectedOutput.name : "",
            selRes:   selRes,
            selScale: selScale,
            selPosX:  selPosX,
            selPosY:  selPosY
        };
    }

    // Geometry wrappers — the actual logic lives in MonitorGeometry.js.
    function effectiveWidth(output)  { return MonitorGeometry.effectiveWidth(output, geoCtx()); }
    function effectiveHeight(output) { return MonitorGeometry.effectiveHeight(output, geoCtx()); }
    function outputPosX(output)      { return MonitorGeometry.outputPosX(output, geoCtx()); }
    function outputPosY(output)      { return MonitorGeometry.outputPosY(output, geoCtx()); }

    function layoutBounds()                              { return MonitorGeometry.layoutBounds(outputs, geoCtx()); }
    function layoutScale(cW, cH)                         { return MonitorGeometry.layoutScale(outputs, geoCtx(), cW, cH); }
    function boxXForOutput(output, cW, cH)               { return MonitorGeometry.boxXForOutput(output, outputs, geoCtx(), cW, cH); }
    function boxYForOutput(output, cW, cH)               { return MonitorGeometry.boxYForOutput(output, outputs, geoCtx(), cW, cH); }
    function boxWidthForOutput(output, cW, cH)           { return MonitorGeometry.boxWidthForOutput(output, outputs, geoCtx(), cW, cH); }
    function boxHeightForOutput(output, cW, cH)          { return MonitorGeometry.boxHeightForOutput(output, outputs, geoCtx(), cW, cH); }
    function canvasToLayoutX(canvasX, cW, cH)            { return MonitorGeometry.canvasToLayoutX(canvasX, outputs, geoCtx(), cW, cH); }
    function canvasToLayoutY(canvasY, cW, cH)            { return MonitorGeometry.canvasToLayoutY(canvasY, outputs, geoCtx(), cW, cH); }
    function snapDraggedPosition(outputName, rawX, rawY) { return MonitorGeometry.snapDraggedPosition(outputName, rawX, rawY, outputs, geoCtx()); }

    function adjustSelectedPosition(axis, delta) {
        if (axis === "x") selPosX += delta;
        else selPosY += delta;
    }

    function setDefaultMonitor(name) {
        defaultMonitorName = name;
    }

    function applySettings() {
        if (!selectedOutput) return;
        if (!selRes || !selHz) {
            Log.warn("MonitorsPage", "Cannot apply settings without resolution and refresh rate");
            return;
        }
        saveCurrentDraft();
        backend.applySettings(outputs, selectedOutput.name, selRes, selHz, selScale, selPosX, selPosY, selHdr, selBitdepth, selVrr, selSdrLuminance, selSdrBrightness, selSdrSaturation, selColorManagement, selSdrEotf, defaultMonitorName);
        draftSettings = ({});
    }

    function refresh() { backend.refresh(); }

    function monitorLabel(index) {
        return String(index + 1);
    }

    function pendingChanges() {
        if (!selectedOutput) return false;
        var currentScale = parseFloat(selectedOutput.scale || "1");
        var currentHdr = selectedOutput.hdr || false;
        var currentBitdepth = selectedOutput.bitdepth || 10;
        var currentVrr = (selectedOutput.vrr !== undefined) ? selectedOutput.vrr : 0;
        var currentLum = (selectedOutput.sdrLuminance !== undefined) ? selectedOutput.sdrLuminance : 450;
        var currentBri = selectedOutput.sdrBrightness || 1.1;
        var currentSat = selectedOutput.sdrSaturation || 1.3;
        var currentCm = selectedOutput.colorManagement || "srgb";
        var currentEotf = (selectedOutput.sdrEotf !== undefined) ? selectedOutput.sdrEotf : 1;
        return selRes !== selectedOutput.res
            || Math.abs(parseFloat(selHz || "0") - parseFloat(selectedOutput.hz || "0")) >= 0.01
            || Math.abs(selScale - currentScale) >= 0.01
            || selPosX !== Math.round(selectedOutput.posX || 0)
            || selPosY !== Math.round(selectedOutput.posY || 0)
            || defaultMonitorName !== getDefaultMonitorName()
            || selHdr !== currentHdr
            || selBitdepth !== currentBitdepth
            || selVrr !== currentVrr
            || Math.abs(selSdrLuminance - currentLum) >= 1
            || Math.abs(selSdrBrightness - currentBri) >= 0.01
            || Math.abs(selSdrSaturation - currentSat) >= 0.01
            || selColorManagement !== currentCm
            || selSdrEotf !== currentEotf;
    }

    function identifyText(output, index) {
        var parts = [monitorLabel(index), output.name];
        if (output.name === defaultMonitorName) parts.push("Main");
        return parts.join("  ");
    }

    function triggerIdentify() {
        identifyMode = true;
        identifyTimer.restart();
    }

    function recommendedResolution(output) {
        if (!output || !output.modes || output.modes.length === 0) return output ? output.res : "";
        var best = output.modes[0];
        var bestArea = 0;
        var bestHz = 0;
        for (var i = 0; i < output.modes.length; i++) {
            var mode = output.modes[i];
            var parts = String(mode.res || "0x0").split("x");
            var w = parts.length > 0 ? parseInt(parts[0]) || 0 : 0;
            var h = parts.length > 1 ? parseInt(parts[1]) || 0 : 0;
            var area = w * h;
            var hz = parseFloat(mode.hz || "0");
            if (area > bestArea || (area === bestArea && hz > bestHz)) {
                best = mode;
                bestArea = area;
                bestHz = hz;
            }
        }
        return best.res || (output ? output.res : "");
    }

    function isRecommendedResolution(res) {
        return selectedOutput && recommendedResolution(selectedOutput) === res;
    }

    function displayCountText() {
        return outputs.length === 1 ? "1 display" : outputs.length + " displays";
    }

    function selectedModeText() {
        if (!selectedOutput || !selRes || !selHz) return "Choose a display to begin.";
        return selRes + " at " + parseFloat(selHz).toFixed(1) + " Hz";
    }

    function selectedScaleText() {
        if (!selectedOutput || !selRes) return "--";
        var parts = selRes.split("x");
        var w = parts.length > 0 ? parseInt(parts[0]) || 0 : 0;
        var h = parts.length > 1 ? parseInt(parts[1]) || 0 : 0;
        var effW = Math.round(w / Math.max(0.01, selScale));
        var effH = Math.round(h / Math.max(0.01, selScale));
        return selScale.toFixed(2) + "x  |  " + effW + " x " + effH;
    }

    function selectedScalePercentText() {
        if (!selectedOutput) return "--";
        return scaleChipText(selScale);
    }

    function selectedScaleResolutionText() {
        if (!selectedOutput || !selRes) return "--";
        var parts = selRes.split("x");
        var w = parts.length > 0 ? parseInt(parts[0]) || 0 : 0;
        var h = parts.length > 1 ? parseInt(parts[1]) || 0 : 0;
        var effW = Math.round(w / Math.max(0.01, selScale));
        var effH = Math.round(h / Math.max(0.01, selScale));
        return effW + " x " + effH;
    }

    function selectedLayoutText() {
        if (!selectedOutput) return "--";
        return "X " + selPosX + "  Y " + selPosY;
    }

    function selectedColorText() {
        if (!selectedOutput) return "--";
        if (!CompositorService.isHyprland) return "Standard desktop profile";
        var parts = [];
        parts.push(selColorManagement === "default" ? "Default" : (colorModeLabels[selColorManagement] || selColorManagement));
        parts.push(selBitdepth + "-bit");
        parts.push(selHdr ? "HDR" : "SDR");
        if (selVrr === 1) parts.push("VRR on");
        else if (selVrr === 2) parts.push("VRR fullscreen");
        else parts.push("VRR off");
        return parts.join("  |  ");
    }

    function selectedHintText() {
        if (!selectedOutput) return "No active display selected.";
        if (!isRecommendedResolution(selRes)) return "This display is using a non-recommended resolution. Sharpness may be reduced.";
        if (CompositorService.isHyprland && isRiskyColorMode(selColorManagement)) return "Wide color profiles can trade stability for gamut and may force VRR off.";
        if (selHdr) return "HDR is enabled. Tune luminance and SDR controls if apps look washed out.";
        return "This layout looks healthy. You can drag the preview above or fine-tune values below.";
    }

    function getScaleCandidates() {
        var candidates = CompositorService.isHyprland
            ? [0.5, 0.75, 0.8, 1.0, 1.2, 1.25, 1.333333, 1.5, 1.6, 1.75, 2.0]
            : [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

        var result = [];
        var seen = {};
        var resParts = String(selRes || "1920x1080").split("x");
        var resW = resParts.length > 0 ? parseInt(resParts[0]) || 1920 : 1920;
        var resH = resParts.length > 1 ? parseInt(resParts[1]) || 1080 : 1080;

        for (var i = 0; i < candidates.length; i++) {
            var scale = candidates[i];
            if (CompositorService.isHyprland) {
                var effW = resW / scale;
                var effH = resH / scale;
                if (Math.abs(effW - Math.round(effW)) >= 0.01 || Math.abs(effH - Math.round(effH)) >= 0.01) continue;
            }
            var key = scale.toFixed(3);
            if (seen[key]) continue;
            seen[key] = true;
            result.push(scale);
        }

        if (result.length === 0) result.push(1.0);

        var currentKey = selScale.toFixed(3);
        if (!seen[currentKey]) result.push(selScale);

        result.sort(function(a, b) { return a - b; });
        return result;
    }

    function setScaleValue(value) {
        if (!selectedOutput) return;
        var next = parseFloat(value);
        if (!isFinite(next)) return;

        if (CompositorService.isHyprland) {
            var scales = getScaleCandidates();
            var best = scales[0];
            var minDist = Math.abs(next - best);
            for (var i = 1; i < scales.length; i++) {
                var dist = Math.abs(next - scales[i]);
                if (dist < minDist) {
                    minDist = dist;
                    best = scales[i];
                }
            }
            selScale = best;
        } else {
            if (next < 0.5) next = 0.5;
            if (next > 2.0) next = 2.0;
            selScale = Math.round(next * 20) / 20;
        }
    }

    function stepScale(direction) {
        var scales = getScaleCandidates();
        if (scales.length === 0) return;

        var currentIndex = selectedScaleIndex();
        if (currentIndex < 0) currentIndex = 0;

        var nextIndex = Math.max(0, Math.min(scales.length - 1, currentIndex + direction));
        setScaleValue(scales[nextIndex]);
    }

    function selectedScaleIndex() {
        var scales = getScaleCandidates();
        if (scales.length === 0) return -1;

        var index = 0;
        var minDist = Math.abs(selScale - scales[0]);
        for (var i = 1; i < scales.length; i++) {
            var dist = Math.abs(selScale - scales[i]);
            if (dist < minDist) {
                minDist = dist;
                index = i;
            }
        }
        return index;
    }

    function canStepScale(direction) {
        var scales = getScaleCandidates();
        var index = selectedScaleIndex();
        if (scales.length === 0 || index < 0) return false;
        var nextIndex = index + direction;
        return nextIndex >= 0 && nextIndex < scales.length;
    }

    function scaleChipText(value) {
        return Math.round(value * 100) + "%";
    }

    function scaleSupportText() {
        return CompositorService.isHyprland
            ? "Only clean fractional scales for this resolution are shown."
            : "Common scaling presets are shown here for quicker adjustment.";
    }

    onSelectedOutputChanged: syncSelection()

    Timer {
        id: identifyTimer
        interval: 2000
        repeat: false
        onTriggered: page.identifyMode = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 16

        MonitorsHeader {
            Layout.fillWidth: true
            page: page
        }

        MonitorLayoutCanvas {
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            page: page
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: settingsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: settingsColumn
                width: parent.width
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: page.cardColor
                    border.color: page.cardBorder
                    border.width: 1
                    implicitHeight: selectedSummary.implicitHeight + 28

                    ColumnLayout {
                        id: selectedSummary
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Rectangle {
                                width: 58
                                height: 58
                                radius: 16
                                color: page.accentSoft
                                border.color: page.accentBorder
                                border.width: 1

                                Text {
                                    font.family: Theme.fontFamily
                                    anchors.centerIn: parent
                                    text: page.selectedOutput ? page.monitorLabel(page.selectedIdx) : "-"
                                    color: Theme.primary
                                    font.pixelSize: 24
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    font.family: Theme.fontFamily
                                    text: page.selectedOutput ? page.selectedOutput.name : "No display selected"
                                    color: SettingsPalette.text
                                    font.pixelSize: 19
                                    font.bold: true
                                }

                                Text {
                                    font.family: Theme.fontFamily
                                    text: page.selectedOutput ? (page.selectedOutput.desc || "Connected display") : ""
                                    color: SettingsPalette.subtext
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    font.family: Theme.fontFamily
                                    text: page.selectedModeText()
                                    color: page.selectedOutput ? SettingsPalette.text : SettingsPalette.subtext
                                    font.pixelSize: 12
                                    font.bold: page.selectedOutput !== null
                                }
                            }

                            Rectangle {
                                radius: 10
                                color: page.defaultMonitorName === (page.selectedOutput ? page.selectedOutput.name : "") ? page.accentSoft : Qt.rgba(255, 255, 255, 0.04)
                                border.color: page.defaultMonitorName === (page.selectedOutput ? page.selectedOutput.name : "") ? page.accentBorder : page.softBorder
                                border.width: 1
                                implicitWidth: mainDisplayText.implicitWidth + 24
                                implicitHeight: 38

                                Text {
                                    font.family: Theme.fontFamily
                                    id: mainDisplayText
                                    anchors.centerIn: parent
                                    text: page.defaultMonitorName === (page.selectedOutput ? page.selectedOutput.name : "") ? "This is my main display" : "Make main"
                                    color: page.defaultMonitorName === (page.selectedOutput ? page.selectedOutput.name : "") ? Theme.primary : SettingsPalette.text
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: page.selectedOutput !== null
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (page.selectedOutput) page.setDefaultMonitor(page.selectedOutput.name)
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: 10
                            rowSpacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 12
                                color: Qt.rgba(255, 255, 255, 0.03)
                                border.color: page.softBorder
                                border.width: 1
                                implicitHeight: 74

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 3

                                    Text {  text: "Mode"; color: SettingsPalette.subtext; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                                    Text {  text: page.selectedModeText(); color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.family: Theme.fontFamily }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 12
                                color: Qt.rgba(255, 255, 255, 0.03)
                                border.color: page.softBorder
                                border.width: 1
                                implicitHeight: 74

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 3

                                    Text {  text: "Scale"; color: SettingsPalette.subtext; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                                    Text {  text: page.selectedScaleText(); color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.family: Theme.fontFamily }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 12
                                color: Qt.rgba(255, 255, 255, 0.03)
                                border.color: page.softBorder
                                border.width: 1
                                implicitHeight: 74

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 3

                                    Text {  text: "Layout"; color: SettingsPalette.subtext; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                                    Text {  text: page.selectedLayoutText(); color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; font.family: Theme.fontFamily }
                                    Text {  text: page.defaultMonitorName === (page.selectedOutput ? page.selectedOutput.name : "") ? "Main display" : "Secondary display"; color: SettingsPalette.subtext; font.pixelSize: 11; font.family: Theme.fontFamily }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                radius: 12
                                color: Qt.rgba(255, 255, 255, 0.03)
                                border.color: page.softBorder
                                border.width: 1
                                implicitHeight: 74

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 3

                                    Text {  text: "Color"; color: SettingsPalette.subtext; font.pixelSize: 11; font.bold: true; font.family: Theme.fontFamily }
                                    Text {  text: page.selectedColorText(); color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.family: Theme.fontFamily }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: 12
                            color: pendingChanges() ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                            border.color: pendingChanges() ? page.accentBorder : page.softBorder
                            border.width: 1
                            implicitHeight: hintRow.implicitHeight + 20

                            RowLayout {
                                id: hintRow
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 9
                                    color: pendingChanges() ? Qt.rgba(255, 255, 255, 0.14) : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.16)
                                    border.color: pendingChanges() ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.35)
                                    border.width: 1

                                    Text {
                                        font.family: Theme.fontFamily
                                        anchors.centerIn: parent
                                        text: pendingChanges() ? "!" : "i"
                                        color: pendingChanges() ? "white" : "#a6e3a1"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                }

                                Text {
                                    font.family: Theme.fontFamily
                                    Layout.fillWidth: true
                                    text: page.selectedHintText()
                                    color: SettingsPalette.subtext
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 10

                            Repeater {
                                model: page.outputs

                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    radius: 10
                                    color: page.selectedIdx === index ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                                    border.color: page.selectedIdx === index ? page.accentBorder : page.softBorder
                                    border.width: 1
                                    implicitWidth: chipLabel.implicitWidth + 28
                                    implicitHeight: 34

                                    Text {
                                        font.family: Theme.fontFamily
                                        id: chipLabel
                                        anchors.centerIn: parent
                                        text: page.identifyText(modelData, index)
                                        color: page.selectedIdx === index ? Theme.primary : SettingsPalette.text
                                        font.pixelSize: 11
                                        font.bold: page.selectedIdx === index
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.selectOutput(index)
                                    }
                                }
                            }
                        }
                    }
                }

                MonitorDisplaySettings {
                    Layout.fillWidth: true
                    page: page
                }

                MonitorColorSettings {
                    Layout.fillWidth: true
                    page: page
                }
            }
        }

        MonitorsApplyFooter {
            Layout.fillWidth: true
            page: page
        }
    }
}
