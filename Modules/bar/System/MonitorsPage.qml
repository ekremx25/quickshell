import QtQuick
import QtQuick.Layouts
import Quickshell
import "."
import "../../../Widgets"
import "../Settings/SettingsPalette.js" as SettingsPalette
import "../../../Services"
import "../../../Services/core/Log.js" as Log

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

    function effectiveWidth(output) {
        if (!output) return 0;
        var res = output.name === (selectedOutput ? selectedOutput.name : "") ? selRes : output.res;
        var scale = output.name === (selectedOutput ? selectedOutput.name : "") ? selScale : parseFloat(output.scale || 1);
        var parts = String(res || "0x0").split("x");
        var width = parts.length > 0 ? parseInt(parts[0]) : 0;
        return scale > 0 ? Math.round(width / scale) : width;
    }

    function effectiveHeight(output) {
        if (!output) return 0;
        var res = output.name === (selectedOutput ? selectedOutput.name : "") ? selRes : output.res;
        var scale = output.name === (selectedOutput ? selectedOutput.name : "") ? selScale : parseFloat(output.scale || 1);
        var parts = String(res || "0x0").split("x");
        var height = parts.length > 1 ? parseInt(parts[1]) : 0;
        return scale > 0 ? Math.round(height / scale) : height;
    }

    function outputPosX(output) {
        if (!output) return 0;
        return output.name === (selectedOutput ? selectedOutput.name : "") ? selPosX : Math.round(output.posX || 0);
    }

    function outputPosY(output) {
        if (!output) return 0;
        return output.name === (selectedOutput ? selectedOutput.name : "") ? selPosY : Math.round(output.posY || 0);
    }

    function layoutBounds() {
        if (!outputs.length) return { minX: 0, minY: 0, maxX: 1, maxY: 1 };
        var minX = 0;
        var minY = 0;
        var maxX = 1;
        var maxY = 1;
        for (var i = 0; i < outputs.length; i++) {
            var out = outputs[i];
            var x = outputPosX(out);
            var y = outputPosY(out);
            var w = effectiveWidth(out);
            var h = effectiveHeight(out);
            minX = Math.min(minX, x);
            minY = Math.min(minY, y);
            maxX = Math.max(maxX, x + w);
            maxY = Math.max(maxY, y + h);
        }
        return { minX: minX, minY: minY, maxX: maxX, maxY: maxY };
    }

    function layoutScale(canvasWidth, canvasHeight) {
        var bounds = layoutBounds();
        var totalWidth = Math.max(1, bounds.maxX - bounds.minX);
        var totalHeight = Math.max(1, bounds.maxY - bounds.minY);
        return Math.min((canvasWidth - 40) / totalWidth, (canvasHeight - 40) / totalHeight);
    }

    function boxXForOutput(output, canvasWidth, canvasHeight) {
        var bounds = layoutBounds();
        var scale = layoutScale(canvasWidth, canvasHeight);
        var totalWidth = Math.max(1, bounds.maxX - bounds.minX);
        var usedWidth = totalWidth * scale;
        var offsetX = (canvasWidth - usedWidth) / 2;
        return offsetX + (outputPosX(output) - bounds.minX) * scale;
    }

    function boxYForOutput(output, canvasWidth, canvasHeight) {
        var bounds = layoutBounds();
        var scale = layoutScale(canvasWidth, canvasHeight);
        var totalHeight = Math.max(1, bounds.maxY - bounds.minY);
        var usedHeight = totalHeight * scale;
        var offsetY = (canvasHeight - usedHeight) / 2;
        return offsetY + (outputPosY(output) - bounds.minY) * scale;
    }

    function boxWidthForOutput(output, canvasWidth, canvasHeight) {
        return Math.max(90, effectiveWidth(output) * layoutScale(canvasWidth, canvasHeight));
    }

    function boxHeightForOutput(output, canvasWidth, canvasHeight) {
        return Math.max(60, effectiveHeight(output) * layoutScale(canvasWidth, canvasHeight));
    }

    function canvasToLayoutX(canvasX, canvasWidth, canvasHeight) {
        var bounds = layoutBounds();
        var scale = layoutScale(canvasWidth, canvasHeight);
        var totalWidth = Math.max(1, bounds.maxX - bounds.minX);
        var usedWidth = totalWidth * scale;
        var offsetX = (canvasWidth - usedWidth) / 2;
        return Math.round(((canvasX - offsetX) / Math.max(scale, 0.0001)) + bounds.minX);
    }

    function canvasToLayoutY(canvasY, canvasWidth, canvasHeight) {
        var bounds = layoutBounds();
        var scale = layoutScale(canvasWidth, canvasHeight);
        var totalHeight = Math.max(1, bounds.maxY - bounds.minY);
        var usedHeight = totalHeight * scale;
        var offsetY = (canvasHeight - usedHeight) / 2;
        return Math.round(((canvasY - offsetY) / Math.max(scale, 0.0001)) + bounds.minY);
    }

    function snapDraggedPosition(outputName, rawX, rawY) {
        var target = null;
        for (var i = 0; i < outputs.length; i++) {
            if (outputs[i].name === outputName) {
                target = outputs[i];
                break;
            }
        }
        if (!target) return { x: rawX, y: rawY };

        var targetW = effectiveWidth(target);
        var targetH = effectiveHeight(target);
        var best = { x: rawX, y: rawY, score: 999999 };

        for (var j = 0; j < outputs.length; j++) {
            var other = outputs[j];
            if (other.name === outputName) continue;

            var otherX = outputPosX(other);
            var otherY = outputPosY(other);
            var otherW = effectiveWidth(other);
            var otherH = effectiveHeight(other);

            var targetCenterX = rawX + targetW / 2;
            var targetCenterY = rawY + targetH / 2;
            var otherCenterX = otherX + otherW / 2;
            var otherCenterY = otherY + otherH / 2;
            var dx = targetCenterX - otherCenterX;
            var dy = targetCenterY - otherCenterY;
            var candidate = { x: rawX, y: rawY };
            var centeredY = otherY + Math.round((otherH - targetH) / 2);
            var centeredX = otherX + Math.round((otherW - targetW) / 2);

            if (Math.abs(dx) >= Math.abs(dy)) {
                if (dx <= 0) candidate = { x: otherX - targetW, y: centeredY };
                else candidate = { x: otherX + otherW, y: centeredY };
            } else {
                if (dy <= 0) candidate = { x: centeredX, y: otherY - targetH };
                else candidate = { x: centeredX, y: otherY + otherH };
            }

            var score = Math.abs(rawX - candidate.x) + Math.abs(rawY - candidate.y);
            if (score < best.score) best = { x: candidate.x, y: candidate.y, score: score };
        }

        return { x: best.x, y: best.y };
    }

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

        Rectangle {
            Layout.fillWidth: true
            radius: 14
            color: page.cardColor
            border.color: page.cardBorder
            border.width: 1
            implicitHeight: headerContent.implicitHeight + 28

            RowLayout {
                id: headerContent
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                Rectangle {
                    width: 42
                    height: 42
                    radius: 12
                    color: page.accentSoft
                    border.color: page.accentBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: page.outputs.length
                        color: Theme.primary
                        font.pixelSize: 18
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Displays"
                        color: SettingsPalette.text
                        font.pixelSize: 20
                        font.bold: true
                    }

                        Text {
                            text: selectedOutput
                            ? (displayCountText() + " connected. Arrange your displays, choose the main screen, and tune resolution, scale, and color.")
                            : "No active display detected."
                            color: SettingsPalette.subtext
                            font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    visible: selectedOutput !== null
                    radius: 9
                    color: pendingChanges() ? page.accentSoft : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.16)
                    border.color: pendingChanges() ? page.accentBorder : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.55)
                    border.width: 1
                    implicitWidth: statusText.implicitWidth + 20
                    implicitHeight: 34

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: pendingChanges() ? "Unsaved changes" : "Up to date"
                        color: pendingChanges() ? Theme.primary : "#a6e3a1"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                Rectangle {
                    width: 38
                    height: 38
                    radius: 10
                    color: refreshArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
                    border.color: page.softBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "R"
                        color: SettingsPalette.text
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.refresh()
                    }
                }

                Rectangle {
                    radius: 10
                    color: identifyHeaderArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
                    border.color: page.softBorder
                    border.width: 1
                    implicitWidth: identifyHeaderText.implicitWidth + 20
                    implicitHeight: 38

                    Text {
                        id: identifyHeaderText
                        anchors.centerIn: parent
                        text: "Identify"
                        color: SettingsPalette.text
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        id: identifyHeaderArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.triggerIdentify()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            radius: 16
            color: page.cardColor
            border.color: page.cardBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Rearrange your displays"
                            color: SettingsPalette.text
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            text: "Drag the display tiles to match how your monitors are physically placed on your desk."
                            color: SettingsPalette.subtext
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        radius: 8
                        color: Qt.rgba(255, 255, 255, 0.04)
                        border.color: page.softBorder
                        border.width: 1
                        implicitWidth: hintText.implicitWidth + 16
                        implicitHeight: 30

                        Text {
                            id: hintText
                            anchors.centerIn: parent
                            text: "Tip: select a display, then drag to snap"
                            color: SettingsPalette.subtext
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    id: desktopPreview
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.rgba(12 / 255, 15 / 255, 21 / 255, 0.55)
                    border.color: Qt.rgba(255, 255, 255, 0.06)
                    border.width: 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(45 / 255, 53 / 255, 69 / 255, 0.45) }
                            GradientStop { position: 1.0; color: Qt.rgba(16 / 255, 21 / 255, 29 / 255, 0.20) }
                        }
                    }

                    Item {
                        id: layoutCanvas
                        anchors.fill: parent
                        anchors.margins: 12

                        Repeater {
                            model: page.outputs

                            Rectangle {
                                required property var modelData
                                required property int index
                                property real dragOffsetX: 0
                                property real dragOffsetY: 0

                                x: page.boxXForOutput(modelData, layoutCanvas.width, layoutCanvas.height)
                                y: page.boxYForOutput(modelData, layoutCanvas.width, layoutCanvas.height)
                                width: page.boxWidthForOutput(modelData, layoutCanvas.width, layoutCanvas.height)
                                height: page.boxHeightForOutput(modelData, layoutCanvas.width, layoutCanvas.height)
                                radius: 14
                                color: page.selectedIdx === index ? Qt.rgba(65 / 255, 101 / 255, 166 / 255, 0.60) : Qt.rgba(65 / 255, 72 / 255, 84 / 255, 0.78)
                                border.color: page.selectedIdx === index ? "#8dbbff" : Qt.rgba(255, 255, 255, 0.16)
                                border.width: page.selectedIdx === index ? 2 : 1

                                Behavior on color { ColorAnimation { duration: 140 } }
                                Behavior on border.color { ColorAnimation { duration: 140 } }
                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 8
                                            color: Qt.rgba(255, 255, 255, page.selectedIdx === index ? 0.18 : 0.10)
                                            border.color: Qt.rgba(255, 255, 255, 0.22)
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: page.monitorLabel(index)
                                                color: "white"
                                                font.pixelSize: 13
                                                font.bold: true
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            visible: page.defaultMonitorName === modelData.name
                                            radius: 7
                                            color: Qt.rgba(255, 255, 255, 0.12)
                                            border.color: Qt.rgba(255, 255, 255, 0.18)
                                            border.width: 1
                                            implicitWidth: mainText.implicitWidth + 14
                                            implicitHeight: 24

                                            Text {
                                                id: mainText
                                                anchors.centerIn: parent
                                                text: "Main display"
                                                color: "white"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }

                                    Text {
                                        text: modelData.name
                                        color: "white"
                                        font.pixelSize: Math.max(13, Math.min(17, parent.width / 7))
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: page.effectiveWidth(modelData) + " x " + page.effectiveHeight(modelData)
                                        color: Qt.rgba(255, 255, 255, 0.86)
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: Math.round(page.outputPosX(modelData)) + ", " + Math.round(page.outputPosY(modelData))
                                        color: Qt.rgba(255, 255, 255, 0.74)
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Item { Layout.fillHeight: true }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width * 0.45, 86)
                                    height: width
                                    radius: width / 2
                                    color: Qt.rgba(11 / 255, 17 / 255, 26 / 255, 0.88)
                                    border.color: Qt.rgba(255, 255, 255, 0.28)
                                    border.width: 2
                                    visible: page.identifyMode
                                    opacity: page.identifyMode ? 1 : 0

                                    Behavior on opacity { NumberAnimation { duration: 160 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: page.monitorLabel(index)
                                        color: "white"
                                        font.pixelSize: Math.max(24, parent.width * 0.34)
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        page.selectOutput(index);
                                        parent.dragOffsetX = mouse.x;
                                        parent.dragOffsetY = mouse.y;
                                    }
                                    onPositionChanged: function(mouse) {
                                        if (!pressed) return;
                                        page.selectOutput(index);
                                        var newX = page.canvasToLayoutX(parent.x + mouse.x - parent.dragOffsetX, layoutCanvas.width, layoutCanvas.height);
                                        var newY = page.canvasToLayoutY(parent.y + mouse.y - parent.dragOffsetY, layoutCanvas.width, layoutCanvas.height);
                                        var snapped = page.snapDraggedPosition(modelData.name, newX, newY);
                                        if (page.selectedOutput && page.selectedOutput.name === modelData.name) {
                                            page.selPosX = snapped.x;
                                            page.selPosY = snapped.y;
                                        }
                                    }
                                    onClicked: page.selectOutput(index)
                                }
                            }
                        }
                    }
                }
            }
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
                                    text: page.selectedOutput ? page.selectedOutput.name : "No display selected"
                                    color: SettingsPalette.text
                                    font.pixelSize: 19
                                    font.bold: true
                                }

                                Text {
                                    text: page.selectedOutput ? (page.selectedOutput.desc || "Connected display") : ""
                                    color: SettingsPalette.subtext
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Text {
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

                                    Text { text: "Mode"; color: SettingsPalette.subtext; font.pixelSize: 11; font.bold: true }
                                    Text { text: page.selectedModeText(); color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
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

                                    Text { text: "Scale"; color: SettingsPalette.subtext; font.pixelSize: 11; font.bold: true }
                                    Text { text: page.selectedScaleText(); color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
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

                                    Text { text: "Layout"; color: SettingsPalette.subtext; font.pixelSize: 11; font.bold: true }
                                    Text { text: page.selectedLayoutText(); color: SettingsPalette.text; font.pixelSize: 13; font.bold: true }
                                    Text { text: page.defaultMonitorName === (page.selectedOutput ? page.selectedOutput.name : "") ? "Main display" : "Secondary display"; color: SettingsPalette.subtext; font.pixelSize: 11 }
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

                                    Text { text: "Color"; color: SettingsPalette.subtext; font.pixelSize: 11; font.bold: true }
                                    Text { text: page.selectedColorText(); color: SettingsPalette.text; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
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
                                        anchors.centerIn: parent
                                        text: pendingChanges() ? "!" : "i"
                                        color: pendingChanges() ? "white" : "#a6e3a1"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                }

                                Text {
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

                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: page.cardColor
                    border.color: page.cardBorder
                    border.width: 1
                    implicitHeight: displaySettings.implicitHeight + 28

                    ColumnLayout {
                        id: displaySettings
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "Display settings"
                                color: SettingsPalette.text
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                text: page.selectedOutput
                                    ? "Choose the sharpest mode first, then tune scale and placement."
                                    : "Select a display above to edit its settings."
                                color: SettingsPalette.subtext
                                font.pixelSize: 11
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Display resolution"
                                color: SettingsPalette.subtext
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 130
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: page.getUniqueRes()

                                    Rectangle {
                                        required property string modelData
                                        radius: 9
                                        color: page.selRes === modelData ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                                        border.color: page.selRes === modelData ? page.accentBorder : page.softBorder
                                        border.width: 1
                                        implicitWidth: resolutionText.implicitWidth + 22
                                        implicitHeight: 34

                                        Text {
                                            id: resolutionText
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 11
                                            text: modelData.replace("x", " x ")
                                            color: page.selRes === modelData ? Theme.primary : SettingsPalette.text
                                            font.pixelSize: 12
                                            font.bold: page.selRes === modelData
                                        }

                                        Rectangle {
                                            visible: page.isRecommendedResolution(modelData)
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            radius: 6
                                            color: page.selRes === modelData ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.16)
                                            border.color: page.selRes === modelData ? Qt.rgba(255, 255, 255, 0.26) : Qt.rgba(166 / 255, 227 / 255, 161 / 255, 0.44)
                                            border.width: 1
                                            implicitWidth: recommendedText.implicitWidth + 12
                                            implicitHeight: 20

                                            Text {
                                                id: recommendedText
                                                anchors.centerIn: parent
                                                text: "Recommended"
                                                color: page.selRes === modelData ? "white" : "#a6e3a1"
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                page.selRes = modelData;
                                                var rates = page.getRefreshRates();
                                                var safe = rates[0];
                                                page.selHz = safe ? safe.hz : page.selHz;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Refresh rate"
                                color: SettingsPalette.subtext
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 130
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: page.getRefreshRates()

                                    Rectangle {
                                        required property var modelData
                                        radius: 9
                                        color: page.selHz === modelData.hz ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                                        border.color: page.selHz === modelData.hz ? page.accentBorder : page.softBorder
                                        border.width: 1
                                        implicitWidth: refreshText.implicitWidth + 22
                                        implicitHeight: 34

                                        Text {
                                            id: refreshText
                                            anchors.centerIn: parent
                                            text: parseFloat(modelData.hz).toFixed(1) + " Hz"
                                            color: page.selHz === modelData.hz ? Theme.primary : SettingsPalette.text
                                            font.pixelSize: 12
                                            font.bold: page.selHz === modelData.hz
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.selHz = modelData.hz
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Text {
                                text: "Scale"
                                color: SettingsPalette.subtext
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 130
                            }

                            ScaleSelector {
                                Layout.fillWidth: true
                                scaleOptions: page.getScaleCandidates()
                                selectedScale: page.selScale
                                summaryText: page.selectedScalePercentText()
                                detailText: page.selectedScaleResolutionText()
                                helperText: page.scaleSupportText()
                                canStepDown: page.canStepScale(-1)
                                canStepUp: page.canStepScale(1)
                                onScaleSelected: value => page.setScaleValue(value)
                                onStepRequested: direction => page.stepScale(direction)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Position"
                                color: SettingsPalette.subtext
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 130
                            }

                            RowLayout {
                                spacing: 6

                                Repeater {
                                    model: [
                                        { label: "X-", axis: "x", delta: -100 },
                                        { label: "X+", axis: "x", delta: 100 },
                                        { label: "Y-", axis: "y", delta: -100 },
                                        { label: "Y+", axis: "y", delta: 100 }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        radius: 8
                                        color: buttonArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
                                        border.color: page.softBorder
                                        border.width: 1
                                        implicitWidth: 44
                                        implicitHeight: 32

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: SettingsPalette.text
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: buttonArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.adjustSelectedPosition(modelData.axis, modelData.delta)
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                radius: 8
                                color: Qt.rgba(255, 255, 255, 0.03)
                                border.color: page.softBorder
                                border.width: 1
                                implicitWidth: 90
                                implicitHeight: 32

                                Text {
                                    anchors.centerIn: parent
                                    text: "X: " + page.selPosX
                                    color: SettingsPalette.text
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                radius: 8
                                color: Qt.rgba(255, 255, 255, 0.03)
                                border.color: page.softBorder
                                border.width: 1
                                implicitWidth: 90
                                implicitHeight: 32

                                Text {
                                    anchors.centerIn: parent
                                    text: "Y: " + page.selPosY
                                    color: SettingsPalette.text
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                radius: 8
                                color: resetYArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03)
                                border.color: page.softBorder
                                border.width: 1
                                implicitWidth: 86
                                implicitHeight: 32

                                Text {
                                    anchors.centerIn: parent
                                    text: "Reset Y"
                                    color: SettingsPalette.text
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    id: resetYArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.selPosY = 0
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: 14
                    color: page.cardColor
                    border.color: page.cardBorder
                    border.width: 1
                    visible: CompositorService.isHyprland
                    implicitHeight: advancedSettings.implicitHeight + 28

                    ColumnLayout {
                        id: advancedSettings
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: "Advanced color"
                            color: SettingsPalette.text
                            font.pixelSize: 15
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "HDR"
                                color: SettingsPalette.subtext
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 130
                            }

                            Rectangle {
                                width: 48
                                height: 28
                                radius: 14
                                color: page.selHdr ? Theme.primary : Qt.rgba(255, 255, 255, 0.10)

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: page.selHdr ? parent.width - width - 3 : 3
                                    color: "white"
                                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        page.selHdr = !page.selHdr;
                                        if (page.selHdr) page.selColorManagement = "hdr";
                                        else if (page.isHdrColorMode(page.selColorManagement) && page.selColorManagement !== "hdredid") page.selColorManagement = "srgb";
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: page.selHdr ? "High dynamic range is enabled" : "Use SDR for a more stable desktop"
                                color: SettingsPalette.subtext
                                font.pixelSize: 11
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Bit depth"
                                color: SettingsPalette.subtext
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 130
                            }

                            Repeater {
                                model: [8, 10]

                                Rectangle {
                                    required property int modelData
                                    radius: 8
                                    color: page.selBitdepth === modelData ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                                    border.color: page.selBitdepth === modelData ? page.accentBorder : page.softBorder
                                    border.width: 1
                                    implicitWidth: 62
                                    implicitHeight: 32

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData + "-bit"
                                        color: page.selBitdepth === modelData ? Theme.primary : SettingsPalette.text
                                        font.pixelSize: 11
                                        font.bold: page.selBitdepth === modelData
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.selBitdepth = modelData
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Variable refresh rate"
                                color: SettingsPalette.subtext
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 130
                            }

                            Repeater {
                                model: [
                                    { value: 0, label: "Off" },
                                    { value: 1, label: "On" },
                                    { value: 2, label: "Fullscreen only" }
                                ]

                                Rectangle {
                                    required property var modelData
                                    radius: 8
                                    color: page.selVrr === modelData.value ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                                    border.color: page.selVrr === modelData.value ? page.accentBorder : page.softBorder
                                    border.width: 1
                                    implicitWidth: vrrLabel.implicitWidth + 22
                                    implicitHeight: 32

                                    Text {
                                        id: vrrLabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: page.selVrr === modelData.value ? Theme.primary : SettingsPalette.text
                                        font.pixelSize: 11
                                        font.bold: page.selVrr === modelData.value
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.selVrr = modelData.value
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Color profile"
                                color: SettingsPalette.subtext
                                font.pixelSize: 12
                                font.bold: true
                                Layout.preferredWidth: 130
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: [
                                        { value: "srgb", label: "sRGB" },
                                        { value: "default", label: "Default" },
                                        { value: "hdr", label: "HDR" },
                                        { value: "dcip3", label: "DCI-P3" },
                                        { value: "hdredid", label: "HDR (EDID)" }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        radius: 8
                                        color: page.selColorManagement === modelData.value ? page.accentSoft : Qt.rgba(255, 255, 255, 0.03)
                                        border.color: page.selColorManagement === modelData.value ? page.accentBorder : page.softBorder
                                        border.width: 1
                                        implicitWidth: profileText.implicitWidth + 22
                                        implicitHeight: 32

                                        Text {
                                            id: profileText
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: page.selColorManagement === modelData.value ? Theme.primary : SettingsPalette.text
                                            font.pixelSize: 11
                                            font.bold: page.selColorManagement === modelData.value
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                page.selColorManagement = modelData.value;
                                                if (page.isHdrColorMode(modelData.value)) page.selHdr = true;
                                                else if (page.selHdr && !page.isHdrColorMode(modelData.value)) page.selHdr = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: page.selHdr

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 16

                                Text {
                                    text: "SDR luminance"
                                    color: SettingsPalette.subtext
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.preferredWidth: 130
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 32

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 8
                                        radius: 4
                                        color: Qt.rgba(255, 255, 255, 0.08)

                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(1, (page.selSdrLuminance - page.sdrLuminanceMin) / Math.max(1, page.sdrLuminanceMax - page.sdrLuminanceMin)))
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.primary
                                        }
                                    }

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: parent.width * Math.max(0, Math.min(1, (page.selSdrLuminance - page.sdrLuminanceMin) / Math.max(1, page.sdrLuminanceMax - page.sdrLuminanceMin))) - 9
                                        color: Theme.primary
                                        border.color: Qt.lighter(Theme.primary, 1.4)
                                        border.width: 2
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        function setVal(mx) {
                                            var ratio = Math.max(0, Math.min(1, mx / width));
                                            page.selSdrLuminance = Math.round(page.sdrLuminanceMin + ratio * (page.sdrLuminanceMax - page.sdrLuminanceMin));
                                        }
                                        onPressed: function(mouse) { setVal(mouse.x); }
                                        onPositionChanged: function(mouse) { if (pressed) setVal(mouse.x); }
                                    }
                                }

                                Text {
                                    text: page.selSdrLuminance + " nits"
                                    color: Theme.primary
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.preferredWidth: 72
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 16

                                Text {
                                    text: "SDR brightness"
                                    color: SettingsPalette.subtext
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.preferredWidth: 130
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 32

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 8
                                        radius: 4
                                        color: Qt.rgba(255, 255, 255, 0.08)

                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(1, (page.selSdrBrightness - 0.5) / 1.5))
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.primary
                                        }
                                    }

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: parent.width * Math.max(0, Math.min(1, (page.selSdrBrightness - 0.5) / 1.5)) - 9
                                        color: Theme.primary
                                        border.color: Qt.lighter(Theme.primary, 1.4)
                                        border.width: 2
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        function setVal(mx) {
                                            var ratio = Math.max(0, Math.min(1, mx / width));
                                            page.selSdrBrightness = Math.round((0.5 + ratio * 1.5) * 10) / 10;
                                        }
                                        onPressed: function(mouse) { setVal(mouse.x); }
                                        onPositionChanged: function(mouse) { if (pressed) setVal(mouse.x); }
                                    }
                                }

                                Text {
                                    text: page.selSdrBrightness.toFixed(1) + "x"
                                    color: Theme.primary
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.preferredWidth: 72
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 16

                                Text {
                                    text: "SDR saturation"
                                    color: SettingsPalette.subtext
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.preferredWidth: 130
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 32

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: 8
                                        radius: 4
                                        color: Qt.rgba(255, 255, 255, 0.08)

                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(1, (page.selSdrSaturation - 0.5) / 1.5))
                                            height: parent.height
                                            radius: parent.radius
                                            color: Theme.primary
                                        }
                                    }

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: parent.width * Math.max(0, Math.min(1, (page.selSdrSaturation - 0.5) / 1.5)) - 9
                                        color: Theme.primary
                                        border.color: Qt.lighter(Theme.primary, 1.4)
                                        border.width: 2
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        function setVal(mx) {
                                            var ratio = Math.max(0, Math.min(1, mx / width));
                                            page.selSdrSaturation = Math.round((0.5 + ratio * 1.5) * 10) / 10;
                                        }
                                        onPressed: function(mouse) { setVal(mouse.x); }
                                        onPositionChanged: function(mouse) { if (pressed) setVal(mouse.x); }
                                    }
                                }

                                Text {
                                    text: page.selSdrSaturation.toFixed(1) + "x"
                                    color: Theme.primary
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.preferredWidth: 72
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: 14
            color: page.cardColor
            border.color: page.cardBorder
            border.width: 1
            implicitHeight: 72

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: pendingChanges() ? "Review your changes before applying them." : "Your current display configuration is saved."
                        color: SettingsPalette.text
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        text: page.selectedOutput
                            ? ("Selected display: " + page.selectedOutput.name + " | Position " + page.selPosX + ", " + page.selPosY)
                            : "No display selected."
                        color: SettingsPalette.subtext
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    radius: 10
                    color: revertArea.enabled
                        ? (revertArea.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.03))
                        : Qt.rgba(255, 255, 255, 0.02)
                    border.color: revertArea.enabled ? page.softBorder : Qt.rgba(255, 255, 255, 0.03)
                    border.width: 1
                    implicitWidth: 90
                    implicitHeight: 40

                    Text {
                        anchors.centerIn: parent
                        text: "Revert"
                        color: revertArea.enabled ? SettingsPalette.text : SettingsPalette.subtext
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        id: revertArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: page.selectedOutput !== null && pendingChanges()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: page.syncSelection()
                    }
                }

                Rectangle {
                    radius: 10
                    color: applyArea.enabled
                        ? (applyArea.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
                        : Qt.rgba(255, 255, 255, 0.08)
                    border.color: applyArea.enabled ? Qt.lighter(Theme.primary, 1.2) : Qt.rgba(255, 255, 255, 0.05)
                    border.width: 1
                    implicitWidth: 118
                    implicitHeight: 40

                    Text {
                        anchors.centerIn: parent
                        text: pendingChanges() ? "Apply" : "Saved"
                        color: applyArea.enabled ? "#11151b" : SettingsPalette.subtext
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: applyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: page.selectedOutput !== null && pendingChanges()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: page.applySettings()
                    }
                }
            }
        }
    }
}
