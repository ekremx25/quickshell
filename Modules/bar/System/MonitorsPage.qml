import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "../../../Services"

Item {
    id: page


    // ═══ STATE ═══
    property var outputs: []          // [{name, desc, res, hz, scale, posX, posY, modes: [{res,hz,current}]}]
    property int selectedIdx: 0       // Seçili monitör indexi
    property var selectedOutput: outputs.length > selectedIdx ? outputs[selectedIdx] : null

    // Seçim state (uygula denmeden değişmez)
    property string selRes: ""
    property string selHz: ""
    property real selScale: 1.0

    // HDR state
    property bool selHdr: false
    property int selBitdepth: 10
    property int selVrr: 2
    property int selSdrLuminance: 450
    property real selSdrBrightness: 1.1
    property real selSdrSaturation: 1.3

    // Color Management state
    property string selColorManagement: "srgb"
    property bool colorDropdownOpen: false
    property int selSdrEotf: 1
    property bool eotfDropdownOpen: false

    // Saved config from monitor_config.json (used to restore VRR/HDR etc.)
    property var savedConfig: ({})

    // ═══ Load saved config ═══
    Process {
        id: configLoadProc
        command: ["sh", "-c", "cat ~/.config/quickshell/monitor_config.json 2>/dev/null || echo '{}'"]
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { configLoadProc.buf += data; } }
        onExited: {
            try {
                page.savedConfig = JSON.parse(configLoadProc.buf);
            } catch(e) {
                page.savedConfig = {};
            }
            configLoadProc.buf = "";
            // Now query compositor
            randrProc.buf = "";
            randrProc.running = true;
        }
    }

    // ═══ Outputs PARSE ═══
    Process {
        id: randrProc
        command: CompositorService.isHyprland ? ["hyprctl", "monitors", "all", "-j"] : (CompositorService.isMango ? ["wlr-randr"] : ["niri", "msg", "-j", "outputs"])
        property string buf: ""
        stdout: SplitParser { onRead: (data) => { randrProc.buf += data + "\n"; } }
        onExited: { 
            if (randrProc.buf.trim() !== "") {
                if (CompositorService.isHyprland) {
                    page.parseHyprland(randrProc.buf);
                } else if (CompositorService.isMango) {
                    page.parseMango(randrProc.buf);
                } else {
                    page.parseAll(randrProc.buf); 
                }
            }
            randrProc.buf = ""; 
        }
    }

    // Mango tespiti gecikmeli olabilir — tespit tamamlanınca yeniden yükle
    Connections {
        target: CompositorService
        function onCompositorChanged() {
            if (CompositorService.compositor === "mango") {
                console.log("[MonitorsPage] Mango detected, refreshing monitors...");
                refresh();
            }
        }
    }

    function parseHyprland(text) {
        try {
            var data = JSON.parse(text);
            var outs = [];
            
            for (var i = 0; i < data.length; i++) {
                var info = data[i];
                var outObj = {
                    name: info.name,
                    desc: (info.make || "") + " " + (info.model || ""),
                    res: info.width + "x" + info.height,
                    hz: info.refreshRate ? info.refreshRate.toFixed(3) : "60.000",
                    scale: info.scale ? info.scale.toFixed(2) : "1.00",
                    posX: info.x || 0,
                    posY: info.y || 0,
                    hdr: (info.colorManagementPreset === "hdr" || info.colorManagement === "hdr" || info.cm === "hdr") ? true : false,
                    bitdepth: (info.currentFormat && info.currentFormat.indexOf("2101010") >= 0) ? 10 : (info.bitdepth || 8),
                    vrr: (info.vrr === true) ? 1 : ((info.vrr === false) ? 0 : (info.vrr || 0)),
                    sdrLuminance: info.sdrMaxLuminance || info.sdr_max_luminance || 450,
                    sdrBrightness: info.sdrBrightness || info.sdrbrightness || 1.0,
                    sdrSaturation: info.sdrSaturation || info.sdrsaturation || 1.0,
                    colorManagement: info.colorManagementPreset || info.cm || info.colorManagement || "srgb",
                    sdrEotf: info.sdr_eotf || info.sdreotf || 1,
                    modes: []
                };

                if (info.availableModes) {
                    for (var m = 0; m < info.availableModes.length; m++) {
                        // e.g. "3840x2160@160.00Hz"
                        var modeStr = info.availableModes[m];
                        var parts = modeStr.split("@");
                        if (parts.length === 2) {
                            var r = parts[0];
                            var h = parts[1].replace("Hz", "");
                            var isCur = (r === outObj.res && Math.abs(parseFloat(h) - parseFloat(outObj.hz)) < 1.0);
                            var formattedH = parseFloat(h).toFixed(3);
                            outObj.modes.push({ res: r, hz: formattedH, current: isCur });
                            if (isCur) {
                                outObj.hz = formattedH;
                            }
                        }
                    }
                }

                // Overlay saved config values (VRR, HDR, etc.) since hyprctl doesn't report them accurately
                var saved = page.savedConfig[outObj.name];
                if (saved) {
                    if (saved.vrr !== undefined) outObj.vrr = saved.vrr;
                    if (saved.hdr !== undefined) outObj.hdr = saved.hdr;
                    if (saved.bitdepth !== undefined) outObj.bitdepth = saved.bitdepth;
                    if (saved.sdrLuminance !== undefined) outObj.sdrLuminance = saved.sdrLuminance;
                    if (saved.sdrBrightness !== undefined) outObj.sdrBrightness = saved.sdrBrightness;
                    if (saved.sdrSaturation !== undefined) outObj.sdrSaturation = saved.sdrSaturation;
                    if (saved.colorManagement !== undefined) outObj.colorManagement = saved.colorManagement;
                    if (saved.sdrEotf !== undefined) outObj.sdrEotf = saved.sdrEotf;
                }
                
                outs.push(outObj);
            }

            outputs = outs;
            if (selectedIdx >= outs.length) selectedIdx = 0;
            syncSelection();
        } catch (e) {
            console.log("Hyprland outputs parse error: " + e);
        }
    }

    function parseAll(text) {
        try {
            var data = JSON.parse(text);
            var outs = [];
            
            var keys = Object.keys(data);
            for (var i = 0; i < keys.length; i++) {
                var name = keys[i];
                var info = data[name];
                
                var outObj = {
                    name: name,
                    desc: (info.make || "") + " " + (info.model || ""),
                    res: "",
                    hz: "",
                    scale: "1.0",
                    posX: 0,
                    posY: 0,
                    modes: []
                };

                if (info.logical) {
                    outObj.posX = info.logical.x;
                    outObj.posY = info.logical.y;
                    outObj.scale = info.logical.scale.toFixed(2);
                }

                // Modes
                if (info.modes) {
                    for (var m = 0; m < info.modes.length; m++) {
                        var mode = info.modes[m];
                        var r = mode.width + "x" + mode.height;
                        var h = (mode.refresh_rate / 1000.0).toFixed(3);
                        var isCur = (m === info.current_mode);
                        
                        outObj.modes.push({ res: r, hz: h, current: isCur });
                        
                        if (isCur) {
                            outObj.res = r;
                            outObj.hz = h;
                        }
                    }
                }
                
                outs.push(outObj);
            }

            outputs = outs;
            if (selectedIdx >= outs.length) selectedIdx = 0;
            syncSelection();
        } catch (e) {
            console.log("Niri outputs parse error: " + e);
        }
    }

    // ═══ Mango wlr-randr PARSE ═══
    function parseMango(text) {
        try {
            var outs = [];
            var lines = text.split("\n");
            var current = null;
            var inModes = false;

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];
                var trimmed = line.trim();
                if (trimmed === "") continue;

                // New output: line starts at column 0 (no leading whitespace)
                // e.g. 'DP-2 "ASUSTek COMPUTER INC XG27UCS (DP-2)"'
                if (line.length > 0 && line[0] !== ' ' && line[0] !== '\t') {
                    // Save previous output
                    if (current) outs.push(current);

                    var nameEnd = trimmed.indexOf(' ');
                    var outName = nameEnd > 0 ? trimmed.substring(0, nameEnd) : trimmed;
                    var descPart = nameEnd > 0 ? trimmed.substring(nameEnd + 1) : "";
                    // Remove surrounding quotes
                    descPart = descPart.replace(/^"|"$/g, "").trim();
                    // Remove trailing "(DP-x)" part for cleaner desc
                    descPart = descPart.replace(/\s*\([^)]*\)\s*$/, "").trim();

                    current = {
                        name: outName,
                        desc: descPart || outName,
                        res: "",
                        hz: "",
                        scale: "1.00",
                        posX: 0,
                        posY: 0,
                        modes: []
                    };
                    inModes = false;
                    continue;
                }

                if (!current) continue;

                if (trimmed === "Modes:") {
                    inModes = true;
                    continue;
                }

                // Parse mode lines: "3840x2160 px, 160.000000 Hz (preferred, current)"
                if (inModes && trimmed.indexOf("px,") > 0) {
                    var modeMatch = trimmed.match(/(\d+)x(\d+)\s+px,\s+([\d.]+)\s+Hz(.*)/);
                    if (modeMatch) {
                        var mw = modeMatch[1];
                        var mh = modeMatch[2];
                        var mhz = parseFloat(modeMatch[3]).toFixed(3);
                        var flags = modeMatch[4] || "";
                        var isCurrent = flags.indexOf("current") >= 0;
                        var r = mw + "x" + mh;

                        current.modes.push({ res: r, hz: mhz, current: isCurrent });

                        if (isCurrent) {
                            current.res = r;
                            current.hz = mhz;
                        }
                    }
                    continue;
                }

                // Position: "Position: 0,0"
                if (trimmed.startsWith("Position:")) {
                    inModes = false;
                    var posStr = trimmed.substring("Position:".length).trim();
                    var posParts = posStr.split(",");
                    if (posParts.length >= 2) {
                        current.posX = parseInt(posParts[0]) || 0;
                        current.posY = parseInt(posParts[1]) || 0;
                    }
                    continue;
                }

                // Scale: "Scale: 1.250000"
                if (trimmed.startsWith("Scale:")) {
                    inModes = false;
                    var scaleVal = parseFloat(trimmed.substring("Scale:".length).trim());
                    if (!isNaN(scaleVal)) current.scale = scaleVal.toFixed(2);
                    continue;
                }

                // Other known fields stop mode parsing
                if (trimmed.startsWith("Enabled:") || trimmed.startsWith("Transform:") || trimmed.startsWith("Physical size:")) {
                    inModes = false;
                }
            }

            // Push last output
            if (current) outs.push(current);

            outputs = outs;
            if (selectedIdx >= outs.length) selectedIdx = 0;
            syncSelection();
        } catch (e) {
            console.log("Mango wlr-randr parse error: " + e);
        }
    }

    function syncSelection() {
        if (!selectedOutput) return;
        selRes = selectedOutput.res;
        selHz = selectedOutput.hz;
        selScale = parseFloat(selectedOutput.scale);
        selHdr = selectedOutput.hdr || false;
        selBitdepth = selectedOutput.bitdepth || 10;
        selVrr = (selectedOutput.vrr !== undefined) ? selectedOutput.vrr : 0;
        selSdrLuminance = selectedOutput.sdrLuminance || 450;
        selSdrBrightness = selectedOutput.sdrBrightness || 1.1;
        selSdrSaturation = selectedOutput.sdrSaturation || 1.3;
        selColorManagement = selectedOutput.colorManagement || "srgb";
        selSdrEotf = (selectedOutput.sdrEotf !== undefined) ? selectedOutput.sdrEotf : 1;
    }

    // Tüm monitörlerin pozisyonlarını efektif çözünürlüğe göre yeniden hesapla
    function recalcPositions() {
        if (outputs.length === 0) return;

        // Seçili monitörün scale/res değerlerini güncelle (tüm property'leri koru)
        var updated = [];
        for (var i = 0; i < outputs.length; i++) {
            var isSel = (outputs[i].name === selectedOutput.name);
            var o = {
                name: outputs[i].name,
                desc: outputs[i].desc,
                res: isSel ? selRes : outputs[i].res,
                hz: isSel ? selHz : outputs[i].hz,
                scale: isSel ? selScale : parseFloat(outputs[i].scale),
                posX: outputs[i].posX,
                posY: outputs[i].posY,
                hdr: isSel ? selHdr : (outputs[i].hdr || false),
                bitdepth: isSel ? selBitdepth : (outputs[i].bitdepth || 8),
                vrr: isSel ? selVrr : ((outputs[i].vrr !== undefined) ? outputs[i].vrr : 0),
                sdrLuminance: isSel ? selSdrLuminance : (outputs[i].sdrLuminance || 450),
                sdrBrightness: isSel ? selSdrBrightness : (outputs[i].sdrBrightness || 1.0),
                sdrSaturation: isSel ? selSdrSaturation : (outputs[i].sdrSaturation || 1.0),
                colorManagement: isSel ? selColorManagement : (outputs[i].colorManagement || "srgb"),
                sdrEotf: isSel ? selSdrEotf : ((outputs[i].sdrEotf !== undefined) ? outputs[i].sdrEotf : 1),
                modes: outputs[i].modes
            };
            updated.push(o);
        }

        // posX'e göre sırala (soldan sağa)
        updated.sort(function(a, b) { return a.posX - b.posX; });

        // Pozisyonları yeniden hesapla
        var currentX = 0;
        for (var j = 0; j < updated.length; j++) {
            var parts = updated[j].res.split("x");
            var w = parseInt(parts[0]);
            var sc = parseFloat(updated[j].scale);
            updated[j].posX = currentX;
            updated[j].posY = 0;
            currentX += Math.round(w / sc);
        }

        outputs = updated;
    }

    function getUniqueRes() {
        if (!selectedOutput) return [];
        var seen = {};
        var result = [];
        for (var i = 0; i < selectedOutput.modes.length; i++) {
            if (!seen[selectedOutput.modes[i].res]) {
                seen[selectedOutput.modes[i].res] = true;
                result.push(selectedOutput.modes[i].res);
            }
        }
        return result;
    }

    function getRefreshRates() {
        if (!selectedOutput) return [];
        var rates = [];
        for (var i = 0; i < selectedOutput.modes.length; i++) {
            if (selectedOutput.modes[i].res === selRes) {
                rates.push({ hz: selectedOutput.modes[i].hz, current: selectedOutput.modes[i].current });
            }
        }
        rates.sort(function(a, b) { return parseFloat(b.hz) - parseFloat(a.hz); });
        // Deduplicate
        var unique = [];
        var seen = {};
        for (var j = 0; j < rates.length; j++) {
            var key = parseFloat(rates[j].hz).toFixed(2);
            if (!seen[key]) { seen[key] = true; unique.push(rates[j]); }
        }
        return unique;
    }

    // ═══ APPLY ═══
    Process {
        id: applyProc
        command: []
        running: false
        stdout: SplitParser { onRead: (data) => console.log("[wlr-randr stdout]: " + data) }
        stderr: SplitParser { onRead: (data) => console.log("[wlr-randr stderr]: " + data) }
        onExited: {
            console.log("wlr-randr exited with code: " + exitCode);
            // Give it a moment for the compositor to settle, then refresh
            refreshTimer.start();
        }
    }

    Timer {
        id: refreshTimer
        interval: 500
        repeat: false
        onTriggered: refresh()
    }

    function applySettings() {
        if (!selectedOutput) return;
        
        if (!selRes || !selHz) {
            console.log("Cannot apply: Resolution or Hz missing");
            return;
        }

        // Scale veya çözünürlük değişince pozisyonları yeniden hesapla
        recalcPositions();
        applyProc.running = false;
        var cmds = [];
        var saveCmds = [];

        saveCmds.push("mkdir -p ~/.config/quickshell && ([ -s ~/.config/quickshell/monitor_config.json ] || echo '{}' > ~/.config/quickshell/monitor_config.json)");
        
        for (var i = 0; i < outputs.length; i++) {
            var mon = outputs[i];
            var isSelected = (mon.name === selectedOutput.name);
            var monRes = isSelected ? selRes : mon.res;
            var monHz = isSelected ? parseFloat(selHz).toFixed(2) : parseFloat(mon.hz).toFixed(2);
            var monScaleRaw = isSelected ? selScale : parseFloat(mon.scale);
            var monScale = String(parseFloat(monScaleRaw));
            var monPosX = Math.round(mon.posX);
            var monPosY = Math.round(mon.posY);

            if (CompositorService.isHyprland) {
                var monCmd = "hyprctl keyword monitor " + mon.name + "," + monRes + "@" + monHz + "," + monPosX + "x" + monPosY + "," + monScale;
                // HDR parameters for selected monitor
                var monHdr = isSelected ? page.selHdr : (mon.hdr || false);
                var monBitdepth = isSelected ? page.selBitdepth : (mon.bitdepth || 8);
                var monVrr = isSelected ? page.selVrr : (mon.vrr || 0);
                var monSdrLum = isSelected ? page.selSdrLuminance : (mon.sdrLuminance || 450);
                var monSdrBri = isSelected ? page.selSdrBrightness : (mon.sdrBrightness || 1.0);
                var monSdrSat = isSelected ? page.selSdrSaturation : (mon.sdrSaturation || 1.0);
                var monCm = isSelected ? page.selColorManagement : (mon.colorManagement || "srgb");
                var monEotf = isSelected ? page.selSdrEotf : ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1);
                if (monHdr || monCm === "hdr") {
                    monCmd += ",bitdepth," + monBitdepth + ",vrr," + monVrr + ",cm,hdr,sdrbrightness," + monSdrBri.toFixed(1) + ",sdrsaturation," + monSdrSat.toFixed(1);
                } else if (monCm === "default") {
                    // "default" is not a valid Hyprland cm value; omit cm param to let Hyprland use its built-in default
                    monCmd += ",bitdepth," + monBitdepth + ",vrr," + monVrr;
                } else {
                    // srgb or other valid values
                    monCmd += ",bitdepth," + monBitdepth + ",vrr," + monVrr + ",cm," + monCm;
                }
                cmds.push(monCmd);
            } else if (CompositorService.isMango) {
                // Mango: wlr-randr geçersiz Hz ile çökebiliyor, o yüzden sadece config.conf + reload kullanıyoruz.

                // config.conf'a monitorrule olarak da yaz (kalıcılık)
                var resParts = monRes.split("x");
                var monW = resParts[0];
                var monH = resParts[1];
                var monRefresh = Math.round(parseFloat(monHz));
                var ruleStr = "monitorrule=name:" + mon.name + ",width:" + monW + ",height:" + monH + ",refresh:" + monRefresh + ",x:" + monPosX + ",y:" + monPosY + ",scale:" + monScale;
                // sed ile mevcut monitorrule satırını güncelle veya ekle
                cmds.push("sed -i '/^monitorrule=name:" + mon.name + "/d' ~/.config/mango/config.conf && "
                    + "sed -i '/^# Monitor Rules$/a " + ruleStr + "' ~/.config/mango/config.conf");
            } else {
                var applyHz6 = isSelected ? parseFloat(selHz).toFixed(6) : parseFloat(mon.hz).toFixed(6);
                var niriConf = "$HOME/.config/niri/config.kdl";
                var newMode = monRes + "@" + applyHz6;
                cmds.push("python3 -c \"\n"
                    + "import re, os\n"
                    + "conf = os.path.expanduser('" + niriConf + "')\n"
                    + "with open(conf) as f: text = f.read()\n"
                    + "pattern = r'(output\\\\s+\\\"" + mon.name + "\\\"\\\\s*\\\\{)[^}]*(\\\\})'\n"
                    + "replacement = r'\\\\1\\n    mode \\\"" + newMode + "\\\"\\n    position x=" + monPosX + " y=" + monPosY + "\\n    scale " + monScale + "\\n\\\\2'\n"
                    + "if re.search(pattern, text):\n"
                    + "    new_text = re.sub(pattern, replacement, text, flags=re.DOTALL)\n"
                    + "else:\n"
                    + "    new_text = text.rstrip() + '\\n\\noutput \\\"" + mon.name + "\\\" {\\n    mode \\\"" + newMode + "\\\"\\n    position x=" + monPosX + " y=" + monPosY + "\\n    scale " + monScale + "\\n}\\n'\n"
                    + "with open(conf, 'w') as f: f.write(new_text)\n"
                    + "print('Updated ' + conf)\n"
                    + "\"");
            }

            // Her monitörün config'ini kaydet
            var monHdrSave = isSelected ? page.selHdr : (mon.hdr || false);
            var monBdSave = isSelected ? page.selBitdepth : (mon.bitdepth || 8);
            var monVrrSave = isSelected ? page.selVrr : (mon.vrr || 0);
            var monLumSave = isSelected ? page.selSdrLuminance : (mon.sdrLuminance || 450);
            var monBriSave = isSelected ? page.selSdrBrightness : (mon.sdrBrightness || 1.0);
            var monSatSave = isSelected ? page.selSdrSaturation : (mon.sdrSaturation || 1.0);
            var monCmSave = isSelected ? page.selColorManagement : (mon.colorManagement || "srgb");
            var monEotfSave = isSelected ? page.selSdrEotf : ((mon.sdrEotf !== undefined) ? mon.sdrEotf : 1);
            saveCmds.push("jq '.\"" + mon.name + "\" = {\"res\": \"" + monRes + "\", \"hz\": \"" + monHz + "\", \"scale\": \"" + monScale + "\", \"posX\": \"" + monPosX + "\", \"posY\": \"" + monPosY + "\", \"hdr\": " + (monHdrSave ? "true" : "false") + ", \"bitdepth\": " + monBdSave + ", \"vrr\": " + monVrrSave + ", \"sdrLuminance\": " + monLumSave + ", \"sdrBrightness\": " + monBriSave.toFixed(1) + ", \"sdrSaturation\": " + monSatSave.toFixed(1) + ", \"colorManagement\": \"" + monCmSave + "\", \"sdrEotf\": " + monEotfSave + "}' "
                + "~/.config/quickshell/monitor_config.json > ~/.config/quickshell/monitor_config.tmp && mv ~/.config/quickshell/monitor_config.tmp ~/.config/quickshell/monitor_config.json");
        }

        var fullCmd = cmds.join(" && ") + " && " + saveCmds.join(" && ");

        // Mango için config reload ekle
        if (CompositorService.isMango) {
            fullCmd += " && mmsg -d reload_config";
        }
            
        console.log("Running: " + fullCmd);
        applyProc.command = ["sh", "-c", fullCmd];
        applyProc.running = true;
    }

    Component.onCompleted: configLoadProc.running = true;

    function refresh() { configLoadProc.buf = ""; configLoadProc.running = false; configLoadProc.running = true; }

    onSelectedOutputChanged: syncSelection()

    // ═══ UI ═══
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // ── Başlık ──
        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰍹"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
            Text { text: "Monitor Settings"; font.bold: true; font.pixelSize: 18; color: Theme.text }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 30; height: 30; radius: 8
                color: refreshMA.containsMouse ? Theme.surface : "transparent"
                Text { anchors.centerIn: parent; text: "󰑐"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: Theme.subtext }
                MouseArea { id: refreshMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: refresh() }
            }
        }

        // ══════════════════════════════
        // ── MONITOR ARRANGEMENT AREA ──
        // ══════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            color: Qt.rgba(49/255, 50/255, 68/255, 0.3)
            radius: 12
            border.color: Qt.rgba(255,255,255,0.04)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "󰹑"; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"; color: Theme.subtext }
                    Text { text: "Monitor Layout"; color: Theme.subtext; font.pixelSize: 12; font.bold: true }
                }

                // Monitör kutuları
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Row {
                        anchors.centerIn: parent
                        spacing: 12

                        Repeater {
                            model: page.outputs

                            Rectangle {
                                required property var modelData
                                required property int index

                                // Proportional sizing: en büyük çözünürlüğe göre oranla
                                property var resParts: modelData.res.split("x")
                                property real resW: resParts.length > 0 ? parseInt(resParts[0]) : 1920
                                property real resH: resParts.length > 1 ? parseInt(resParts[1]) : 1080
                                property real ratio: resW / resH
                                property real boxH: 90
                                property real boxW: boxH * ratio

                                width: boxW
                                height: boxH
                                radius: 10
                                color: page.selectedIdx === index
                                    ? Qt.rgba(137/255, 180/255, 250/255, 0.15)
                                    : Qt.rgba(49/255, 50/255, 68/255, 0.6)
                                border.color: page.selectedIdx === index ? Theme.primary : Qt.rgba(255,255,255,0.08)
                                border.width: page.selectedIdx === index ? 2 : 1

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: modelData.name
                                        color: page.selectedIdx === index ? Theme.primary : Theme.text
                                        font.pixelSize: 16
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        text: {
                                            var d = modelData.desc;
                                            // Kısa göster
                                            if (d.length > 30) d = d.substring(0, 30) + "…";
                                            return d;
                                        }
                                        color: Theme.overlay
                                        font.pixelSize: 9
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: parent.parent.width - 16
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { page.selectedIdx = index; }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════
        // ── MONITOR CONFIGURATION ──
        // ══════════════════════════════════
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: configCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: configCol
                width: parent.width
                spacing: 14

                // Seçili monitör bilgisi
                Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    color: Theme.surface
                    radius: 10

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            width: 36; height: 36; radius: 8
                            color: Qt.rgba(137/255, 180/255, 250/255, 0.12)
                            Text { anchors.centerIn: parent; text: "󰍹"; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                        }

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: page.selectedOutput ? (page.selectedOutput.name + "  —  " + page.selectedOutput.desc) : "—"
                                color: Theme.text; font.bold: true; font.pixelSize: 13; elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: page.selectedOutput ? (page.selectedOutput.res + " @ " + parseFloat(page.selectedOutput.hz).toFixed(1) + "Hz • Scale: " + page.selectedOutput.scale + "x") : "—"
                                color: Theme.subtext; font.pixelSize: 11
                            }
                        }
                    }
                }

                // ── Çözünürlük ──
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Resolution"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100 }
                    Item { Layout.fillWidth: true }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        layoutDirection: Qt.RightToLeft

                        Repeater {
                            model: page.getUniqueRes()

                            Rectangle {
                                required property string modelData
                                width: rText.implicitWidth + 20
                                height: 32
                                radius: 8
                                color: page.selRes === modelData
                                    ? Qt.rgba(137/255, 180/255, 250/255, 0.2)
                                    : (rMA.containsMouse ? Theme.surface : Qt.rgba(49/255, 50/255, 68/255, 0.5))
                                border.color: page.selRes === modelData ? Theme.primary : "transparent"
                                border.width: page.selRes === modelData ? 1 : 0
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    id: rText; anchors.centerIn: parent
                                    text: modelData.replace("x", "×")
                                    color: page.selRes === modelData ? Theme.primary : Theme.text
                                    font.pixelSize: 12; font.bold: page.selRes === modelData
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                MouseArea {
                                    id: rMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { 
                                        page.selRes = modelData; 
                                        var rates = page.getRefreshRates();
                                        // Prefer highest Hz (rates are sorted descending)
                                        var safe = rates[0];
                                        page.selHz = safe ? safe.hz : page.selHz;
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Yenileme Hızı ──
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Refresh Rate"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100 }
                    Item { Layout.fillWidth: true }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        layoutDirection: Qt.RightToLeft

                        Repeater {
                            model: page.getRefreshRates()

                            Rectangle {
                                required property var modelData
                                width: hText.implicitWidth + 20
                                height: 32
                                radius: 8
                                color: page.selHz === modelData.hz
                                    ? Qt.rgba(137/255, 180/255, 250/255, 0.2)
                                    : (hMA.containsMouse ? Theme.surface : Qt.rgba(49/255, 50/255, 68/255, 0.5))
                                border.color: page.selHz === modelData.hz ? Theme.primary : "transparent"
                                border.width: page.selHz === modelData.hz ? 1 : 0
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    id: hText; anchors.centerIn: parent
                                    text: parseFloat(modelData.hz).toFixed(1) + " Hz"
                                    color: page.selHz === modelData.hz ? Theme.primary : Theme.text
                                    font.pixelSize: 12; font.bold: page.selHz === modelData.hz
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                MouseArea {
                                    id: hMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: page.selHz = modelData.hz
                                }
                            }
                        }
                    }
                }

                // ── Scale Slider ──
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(255,255,255,0.04) }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Text { text: "Scale"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 50 }

                    // === The real slider ===
                    Item {
                        Layout.fillWidth: true
                        height: 36

                        // Track background
                        Rectangle {
                            id: sliderTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 8
                            radius: 4
                            color: Qt.rgba(49/255, 50/255, 68/255, 0.8)

                            // Fill
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, (page.selScale - 0.5) / 1.5))
                                height: parent.height
                                radius: 4
                                color: Theme.primary
                                Behavior on width { NumberAnimation { duration: 30 } }
                            }
                        }

                        // Handle
                        Rectangle {
                            id: sliderHandle
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width * Math.max(0, Math.min(1, (page.selScale - 0.5) / 1.5)) - 9
                            color: sliderMA.pressed ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
                            border.color: Qt.lighter(Theme.primary, 1.4)
                            border.width: 2

                            Behavior on x { NumberAnimation { duration: 30 } }
                        }

                        MouseArea {
                            id: sliderMA
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function setVal(mx) {
                                var ratio = mx / width;
                                if (ratio < 0) ratio = 0;
                                if (ratio > 1) ratio = 1;
                                var raw = 0.5 + ratio * 1.5;
                                
                                if (CompositorService.isHyprland) {
                                    var allScales = [0.5, 0.75, 0.8, 1.0, 1.2, 1.25, 1.333333, 1.5, 1.6, 1.75, 2.0];
                                    // Seçili çözünürlüğe göre geçerli scale'leri filtrele
                                    var resParts = page.selRes.split("x");
                                    var resW = resParts.length > 0 ? parseInt(resParts[0]) : 1920;
                                    var resH = resParts.length > 1 ? parseInt(resParts[1]) : 1080;
                                    var scales = [];
                                    for (var s = 0; s < allScales.length; s++) {
                                        var effW = resW / allScales[s];
                                        var effH = resH / allScales[s];
                                        if (Math.abs(effW - Math.round(effW)) < 0.01 && Math.abs(effH - Math.round(effH)) < 0.01) {
                                            scales.push(allScales[s]);
                                        }
                                    }
                                    if (scales.length === 0) scales = [1.0]; // Fallback
                                    var best = scales[0];
                                    var minDist = Math.abs(raw - best);
                                    for (var i = 1; i < scales.length; i++) {
                                        var dist = Math.abs(raw - scales[i]);
                                        if (dist < minDist) {
                                            minDist = dist;
                                            best = scales[i];
                                        }
                                    }
                                    page.selScale = best;
                                } else {
                                    // Niri or others handle fine-grained steps (e.g. 1.40) without issues
                                    page.selScale = Math.round(raw * 20) / 20;  // 0.05 step
                                }
                            }
                            onPressed: (mouse) => setVal(mouse.x)
                            onPositionChanged: (mouse) => { if (pressed) setVal(mouse.x); }
                        }
                    }

                    Text {
                        text: page.selScale.toFixed(2) + "x"
                        color: Theme.primary
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                    }

                    Text {
                        property var parts: page.selRes.split("x")
                        property real w: parts.length > 0 ? parseInt(parts[0]) : 0
                        property real h: parts.length > 1 ? parseInt(parts[1]) : 0
                        property real effW: Math.round(w / page.selScale)
                        property real effH: Math.round(h / page.selScale)
                        
                        text: "(~" + effW + "x" + effH + ")"
                        color: Theme.subtext
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }

                // ══════════════════════════════════
                // ── HDR SETTINGS (Hyprland only) ──
                // ══════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(255,255,255,0.04)
                    visible: CompositorService.isHyprland
                }

                // HDR Toggle
                RowLayout {
                    Layout.fillWidth: true
                    visible: CompositorService.isHyprland
                    spacing: 12

                    Text { text: "HDR"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100 }
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 48; height: 26; radius: 13
                        color: page.selHdr ? Theme.primary : Qt.rgba(49/255, 50/255, 68/255, 0.8)
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            x: page.selHdr ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.selHdr = !page.selHdr;
                                // Sync color management when toggling HDR
                                if (page.selHdr) {
                                    page.selColorManagement = "hdr";
                                } else if (page.selColorManagement === "hdr") {
                                    page.selColorManagement = "srgb";
                                }
                            }
                        }
                    }
                }

                // ── Bit Depth (always visible for Hyprland) ──
                RowLayout {
                    Layout.fillWidth: true
                    visible: CompositorService.isHyprland
                    Text { text: "Bit Depth"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100 }
                    Item { Layout.fillWidth: true }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [8, 10]
                            Rectangle {
                                required property int modelData
                                width: 52; height: 32; radius: 8
                                color: page.selBitdepth === modelData
                                    ? Qt.rgba(137/255, 180/255, 250/255, 0.2)
                                    : (bdMA.containsMouse ? Theme.surface : Qt.rgba(49/255, 50/255, 68/255, 0.5))
                                border.color: page.selBitdepth === modelData ? Theme.primary : "transparent"
                                border.width: page.selBitdepth === modelData ? 1 : 0
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "-bit"
                                    color: page.selBitdepth === modelData ? Theme.primary : Theme.text
                                    font.pixelSize: 12; font.bold: page.selBitdepth === modelData
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                MouseArea {
                                    id: bdMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: page.selBitdepth = modelData
                                }
                            }
                        }
                    }
                }

                // ── VRR (always visible for Hyprland) ──
                RowLayout {
                    Layout.fillWidth: true
                    visible: CompositorService.isHyprland
                    Text { text: "VRR"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100 }
                    Item { Layout.fillWidth: true }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { value: 0, label: "Off" },
                                { value: 1, label: "On" },
                                { value: 2, label: "Fullscreen" }
                            ]
                            Rectangle {
                                required property var modelData
                                width: vrrText.implicitWidth + 20; height: 32; radius: 8
                                color: page.selVrr === modelData.value
                                    ? Qt.rgba(137/255, 180/255, 250/255, 0.2)
                                    : (vrrMA.containsMouse ? Theme.surface : Qt.rgba(49/255, 50/255, 68/255, 0.5))
                                border.color: page.selVrr === modelData.value ? Theme.primary : "transparent"
                                border.width: page.selVrr === modelData.value ? 1 : 0
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    id: vrrText; anchors.centerIn: parent
                                    text: modelData.label
                                    color: page.selVrr === modelData.value ? Theme.primary : Theme.text
                                    font.pixelSize: 12; font.bold: page.selVrr === modelData.value
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                MouseArea {
                                    id: vrrMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: page.selVrr = modelData.value
                                }
                            }
                        }
                    }
                }

                // HDR sub-settings (visible when HDR is on)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: CompositorService.isHyprland && page.selHdr

                    // ── SDR Max Luminance ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Text { text: "SDR Luminance"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100 }
                        Item {
                            Layout.fillWidth: true
                            height: 36
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 8; radius: 4
                                color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, (page.selSdrLuminance - 100) / 500.0))
                                    height: parent.height; radius: 4; color: Theme.primary
                                    Behavior on width { NumberAnimation { duration: 30 } }
                                }
                            }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * Math.max(0, Math.min(1, (page.selSdrLuminance - 100) / 500.0)) - 9
                                color: lumMA.pressed ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
                                border.color: Qt.lighter(Theme.primary, 1.4); border.width: 2
                                Behavior on x { NumberAnimation { duration: 30 } }
                            }
                            MouseArea {
                                id: lumMA; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                function setVal(mx) {
                                    var ratio = Math.max(0, Math.min(1, mx / width));
                                    page.selSdrLuminance = Math.round(100 + ratio * 500);
                                }
                                onPressed: (mouse) => setVal(mouse.x)
                                onPositionChanged: (mouse) => { if (pressed) setVal(mouse.x); }
                            }
                        }
                        Text {
                            text: page.selSdrLuminance + " nits"
                            color: Theme.primary; font.pixelSize: 12; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight
                        }
                    }

                    // ── SDR Brightness ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Text { text: "SDR Brightness"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100 }
                        Item {
                            Layout.fillWidth: true
                            height: 36
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 8; radius: 4
                                color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, (page.selSdrBrightness - 0.5) / 1.5))
                                    height: parent.height; radius: 4; color: Theme.primary
                                    Behavior on width { NumberAnimation { duration: 30 } }
                                }
                            }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * Math.max(0, Math.min(1, (page.selSdrBrightness - 0.5) / 1.5)) - 9
                                color: briMA.pressed ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
                                border.color: Qt.lighter(Theme.primary, 1.4); border.width: 2
                                Behavior on x { NumberAnimation { duration: 30 } }
                            }
                            MouseArea {
                                id: briMA; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                function setVal(mx) {
                                    var ratio = Math.max(0, Math.min(1, mx / width));
                                    page.selSdrBrightness = Math.round((0.5 + ratio * 1.5) * 10) / 10;
                                }
                                onPressed: (mouse) => setVal(mouse.x)
                                onPositionChanged: (mouse) => { if (pressed) setVal(mouse.x); }
                            }
                        }
                        Text {
                            text: page.selSdrBrightness.toFixed(1) + "x"
                            color: Theme.primary; font.pixelSize: 12; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight
                        }
                    }

                    // ── SDR Saturation ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        Text { text: "SDR Saturation"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100 }
                        Item {
                            Layout.fillWidth: true
                            height: 36
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 8; radius: 4
                                color: Qt.rgba(49/255, 50/255, 68/255, 0.8)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, (page.selSdrSaturation - 0.5) / 1.5))
                                    height: parent.height; radius: 4; color: Theme.primary
                                    Behavior on width { NumberAnimation { duration: 30 } }
                                }
                            }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width * Math.max(0, Math.min(1, (page.selSdrSaturation - 0.5) / 1.5)) - 9
                                color: satMA.pressed ? Qt.lighter(Theme.primary, 1.2) : Theme.primary
                                border.color: Qt.lighter(Theme.primary, 1.4); border.width: 2
                                Behavior on x { NumberAnimation { duration: 30 } }
                            }
                            MouseArea {
                                id: satMA; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                function setVal(mx) {
                                    var ratio = Math.max(0, Math.min(1, mx / width));
                                    page.selSdrSaturation = Math.round((0.5 + ratio * 1.5) * 10) / 10;
                                }
                                onPressed: (mouse) => setVal(mouse.x)
                                onPositionChanged: (mouse) => { if (pressed) setVal(mouse.x); }
                            }
                        }
                        Text {
                            text: page.selSdrSaturation.toFixed(1) + "x"
                            color: Theme.primary; font.pixelSize: 12; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // ══════════════════════════════════
                // ── COLOR SETTINGS (Hyprland only) ──
                // ══════════════════════════════════
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(255,255,255,0.04)
                    visible: CompositorService.isHyprland
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    visible: CompositorService.isHyprland

                    // Section header
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "󰏘"; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"; color: Theme.primary }
                        Text { text: "Color Settings"; color: Theme.primary; font.pixelSize: 13; font.bold: true }
                    }

                    // Color Management dropdown
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: "Color Management"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 140 }
                        Item { Layout.fillWidth: true }

                        // Dropdown button
                        Rectangle {
                            id: cmDropdown
                            width: 120; height: 34; radius: 8
                            color: cmDropdownMA.containsMouse ? Qt.rgba(69/255, 71/255, 90/255, 0.8) : Qt.rgba(49/255, 50/255, 68/255, 0.6)
                            border.color: page.colorDropdownOpen ? Theme.primary : Qt.rgba(255,255,255,0.08)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 6
                                Text {
                                    text: {
                                        var labels = { "default": "Default", "srgb": "sRGB", "hdr": "HDR" };
                                        return labels[page.selColorManagement] || page.selColorManagement;
                                    }
                                    color: Theme.text; font.pixelSize: 12; font.bold: true
                                    font.family: "JetBrainsMono Nerd Font"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: page.colorDropdownOpen ? "" : ""
                                    color: Theme.subtext; font.pixelSize: 10
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }

                            MouseArea {
                                id: cmDropdownMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.colorDropdownOpen = !page.colorDropdownOpen
                            }
                        }
                    }

                    // Dropdown options
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredWidth: 120
                        Layout.maximumWidth: 200
                        Layout.leftMargin: parent.width - 200
                        implicitHeight: cmOptionsCol.implicitHeight + 8
                        visible: page.colorDropdownOpen
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.95)
                        radius: 10
                        border.color: Qt.rgba(255,255,255,0.08)
                        border.width: 1

                        Column {
                            id: cmOptionsCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: 4
                            spacing: 2

                            Repeater {
                                model: [
                                    { value: "default", label: "Default" },
                                    { value: "srgb",   label: "sRGB" },
                                    { value: "hdr",    label: "HDR" }
                                ]

                                Rectangle {
                                    required property var modelData
                                    width: cmOptionsCol.width - 8; height: 34; radius: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: page.selColorManagement === modelData.value
                                        ? Qt.rgba(137/255, 180/255, 250/255, 0.15)
                                        : (cmOptMA.containsMouse ? Qt.rgba(69/255, 71/255, 90/255, 0.5) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        Text {
                                            text: modelData.label
                                            color: page.selColorManagement === modelData.value ? Theme.primary : Theme.text
                                            font.pixelSize: 12
                                            font.bold: page.selColorManagement === modelData.value
                                            font.family: "JetBrainsMono Nerd Font"
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: page.selColorManagement === modelData.value ? "✓" : ""
                                            color: Theme.primary; font.pixelSize: 12; font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        id: cmOptMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            page.selColorManagement = modelData.value;
                                            // HDR seçilince selHdr'yi de senkronize et
                                            if (modelData.value === "hdr") {
                                                page.selHdr = true;
                                            } else if (page.selHdr && modelData.value !== "hdr") {
                                                page.selHdr = false;
                                            }
                                            page.colorDropdownOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // SDR EOTF dropdown
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text { text: "SDR EOTF"; color: Theme.subtext; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 140 }
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: eotfDropdown
                            width: 160; height: 34; radius: 8
                            color: eotfDropdownMA.containsMouse ? Qt.rgba(69/255, 71/255, 90/255, 0.8) : Qt.rgba(49/255, 50/255, 68/255, 0.6)
                            border.color: page.eotfDropdownOpen ? Theme.primary : Qt.rgba(255,255,255,0.08)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 6
                                Text {
                                    text: {
                                        var labels = { 0: "Default (0)", 1: "Piecewise sRGB (1)", 2: "Gamma 2.2 (2)" };
                                        return labels[page.selSdrEotf] || "Unknown";
                                    }
                                    color: Theme.text; font.pixelSize: 12; font.bold: true
                                    font.family: "JetBrainsMono Nerd Font"
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: page.eotfDropdownOpen ? "" : ""
                                    color: Theme.subtext; font.pixelSize: 10
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }

                            MouseArea {
                                id: eotfDropdownMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { page.eotfDropdownOpen = !page.eotfDropdownOpen; page.colorDropdownOpen = false; }
                            }
                        }
                    }

                    // EOTF Dropdown options
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredWidth: 160
                        Layout.maximumWidth: 220
                        Layout.leftMargin: parent.width - 220
                        implicitHeight: eotfOptionsCol.implicitHeight + 8
                        visible: page.eotfDropdownOpen
                        color: Qt.rgba(49/255, 50/255, 68/255, 0.95)
                        radius: 10
                        border.color: Qt.rgba(255,255,255,0.08)
                        border.width: 1

                        Column {
                            id: eotfOptionsCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: 4
                            spacing: 2

                            Repeater {
                                model: [
                                    { value: 0, label: "Default" },
                                    { value: 1, label: "Piecewise sRGB" },
                                    { value: 2, label: "Gamma 2.2" }
                                ]

                                Rectangle {
                                    required property var modelData
                                    width: eotfOptionsCol.width - 8; height: 34; radius: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: page.selSdrEotf === modelData.value
                                        ? Qt.rgba(137/255, 180/255, 250/255, 0.15)
                                        : (eotfOptMA.containsMouse ? Qt.rgba(69/255, 71/255, 90/255, 0.5) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        Text {
                                            text: modelData.label
                                            color: page.selSdrEotf === modelData.value ? Theme.primary : Theme.text
                                            font.pixelSize: 12
                                            font.bold: page.selSdrEotf === modelData.value
                                            font.family: "JetBrainsMono Nerd Font"
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: page.selSdrEotf === modelData.value ? "✓" : ""
                                            color: Theme.primary; font.pixelSize: 12; font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        id: eotfOptMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            page.selSdrEotf = modelData.value;
                                            page.eotfDropdownOpen = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Uygula ──
                Item { height: 4 }

                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: 10
                    color: applyMA.containsMouse ? Qt.lighter(Theme.primary, 1.15) : Theme.primary
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✓  Apply"
                        color: "#1e1e2e"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    MouseArea {
                        id: applyMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.applySettings()
                    }
                }
            }
        }
    }
}
