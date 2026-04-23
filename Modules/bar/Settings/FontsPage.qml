import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../Widgets"
import "SettingsPalette.js" as SettingsPalette

Item {
    id: fontsPage

    property var installedFonts: []
    property string generalFontFamily: "Noto Sans"
    property int generalFontSize: 10
    property string fixedFontFamily: "JetBrains Mono"
    property int fixedFontSize: 10
    property bool loadingConfig: true
    property bool loadingCatalog: false
    property bool saveInProgress: false
    property string statusMessage: ""
    property bool statusError: false
    property string openDropdown: ""
    property string generalSearchText: ""
    property string fixedSearchText: ""
    property int pendingReads: 0

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string qtPlatformTheme: Quickshell.env("QT_QPA_PLATFORMTHEME") || ""
    readonly property bool qt6ctActive: qtPlatformTheme === "qt6ct"
    readonly property string backendLabel: qt6ctActive ? "qt6ct" : "kdeglobals"
    readonly property string qt6ctConfigPath: homeDir + "/.config/qt6ct/qt6ct.conf"
    readonly property string dolphinConfigPath: homeDir + "/.config/dolphinrc"
    readonly property string fontScanCommand: "fc-list : family | awk -F, '{print $1}' | sort -fu"

    readonly property var generalSuggestions: [
        "Noto Sans", "Inter", "Roboto", "DejaVu Sans", "Fira Sans"
    ]
    readonly property var monoSuggestions: [
        "JetBrains Mono", "Fira Code", "Iosevka", "Cascadia Code", "DejaVu Sans Mono"
    ]
    readonly property var fallbackFonts: generalSuggestions.concat(monoSuggestions)
    readonly property int fontCount: installedFonts.length
    readonly property string generalPreviewText: generalFontFamily + "  " + generalFontSize + "pt"
    readonly property string fixedPreviewText: fixedFontFamily + "  " + fixedFontSize + "pt"
    readonly property var generalFilteredFonts: filteredFonts(generalSearchText, installedFonts)
    readonly property var fixedFilteredFonts: filteredFonts(fixedSearchText, installedFonts)

    component SectionCard: Rectangle {
        id: card
        default property alias contentData: contentColumn.data
        property string title: ""
        property string description: ""

        Layout.fillWidth: true
        radius: 12
        color: SettingsPalette.surface
        border.color: Qt.rgba(255, 255, 255, 0.05)
        border.width: 1
        implicitHeight: contentColumn.implicitHeight + 28

        ColumnLayout {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Text {
                font.family: Theme.fontFamily
                visible: card.title.length > 0
                text: card.title
                color: SettingsPalette.text
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                font.family: Theme.fontFamily
                visible: card.description.length > 0
                text: card.description
                color: SettingsPalette.subtext
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    component SummaryTile: Rectangle {
        id: tile
        property string iconText: ""
        property color accentColor: Theme.primary
        property string heading: ""
        property string summary: ""
        property string helper: ""
        property string previewFamily: ""

        radius: 12
        implicitHeight: 98
        color: Qt.rgba(tile.accentColor.r, tile.accentColor.g, tile.accentColor.b, 0.10)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: tile.iconText
                color: tile.accentColor
                font.family: tile.previewFamily.length > 0 ? tile.previewFamily : "JetBrainsMono Nerd Font"
                font.pixelSize: 24
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                font.family: Theme.fontFamily
                text: tile.heading
                color: SettingsPalette.text
                font.pixelSize: 13
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                font.family: Theme.fontFamily
                text: tile.summary
                color: SettingsPalette.subtext
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                font.family: Theme.fontFamily
                visible: tile.helper.length > 0
                text: tile.helper
                color: tile.accentColor
                font.pixelSize: 10
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    component SuggestionChip: Rectangle {
        id: chip
        property string label: ""
        property bool selected: false
        property color accentColor: Theme.primary
        signal clicked()

        radius: 8
        color: chip.selected
            ? Qt.rgba(chip.accentColor.r, chip.accentColor.g, chip.accentColor.b, 0.14)
            : Qt.rgba(255, 255, 255, 0.04)
        border.color: chip.selected ? chip.accentColor : Qt.rgba(255, 255, 255, 0.06)
        border.width: 1
        implicitWidth: chipLabel.implicitWidth + 20
        implicitHeight: 32

        Text {
            font.family: Theme.fontFamily
            id: chipLabel
            anchors.centerIn: parent
            text: chip.label
            color: chip.selected ? chip.accentColor : SettingsPalette.text
            font.pixelSize: 11
            font.bold: chip.selected
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property color fillColor: Theme.primary
        property color labelColor: "#1e1e2e"
        property bool enabled: true
        signal clicked()

        radius: 10
        color: button.enabled
            ? (buttonArea.containsMouse ? Qt.lighter(button.fillColor, 1.15) : button.fillColor)
            : Qt.rgba(button.fillColor.r, button.fillColor.g, button.fillColor.b, 0.45)
        implicitWidth: 124
        implicitHeight: 40
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            font.family: Theme.fontFamily
            anchors.centerIn: parent
            text: button.label
            color: button.labelColor
            font.pixelSize: 12
            font.bold: true
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }

    function parseFontValue(value, fallbackFamily, fallbackSize) {
        var text = (value || "").trim();
        if (text.length >= 2 && text.charAt(0) === "\"" && text.charAt(text.length - 1) === "\"") {
            text = text.slice(1, -1);
        }
        if (!text.length) return { family: fallbackFamily, size: fallbackSize };

        var parts = text.split(",");
        var family = (parts.length > 0 ? parts[0].trim() : "") || fallbackFamily;
        var size = parseInt(parts.length > 1 ? parts[1].trim() : "", 10);
        if (!isFinite(size) || size <= 0) size = fallbackSize;
        return { family: family, size: size };
    }

    function buildFontValue(family, size) {
        var safeFamily = (family || "").trim();
        if (!safeFamily.length) return "";
        return safeFamily + "," + Math.round(size) + ",-1,5,50,0,0,0,0,0";
    }

    function buildQt6ctFontValue(family, size) {
        var safeFamily = (family || "").trim();
        if (!safeFamily.length) return "";
        return "\"" + safeFamily + "," + Math.round(size) + ",-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0\"";
    }

    function loadCurrentValues() {
        loadingConfig = true;
        pendingReads = 2;
        statusMessage = "";
        openDropdown = "";
        generalSearchText = "";
        fixedSearchText = "";
        readGeneral.refresh();
        readFixed.refresh();
    }

    function finishRead() {
        pendingReads = Math.max(0, pendingReads - 1);
        if (pendingReads === 0) loadingConfig = false;
    }

    function ensureFontCatalog() {
        if (installedFonts.length > 0 || loadingCatalog || fontScanProc.running) return;
        loadingCatalog = true;
        fontScanProc.buffer = "";
        fontScanProc.running = true;
    }

    function parseInstalledFonts(rawText) {
        var lines = (rawText || "").split(/\r?\n/);
        var seen = ({});
        var output = [];

        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim();
            if (!line.length) continue;

            var family = line.split(",")[0].trim();
            if (!family.length || seen[family]) continue;
            seen[family] = true;
            output.push(family);
        }

        output.sort(function(a, b) { return a.localeCompare(b); });
        if (output.length === 0) output = fallbackFonts.slice();
        installedFonts = output;
    }

    function filteredFonts(query, source) {
        var list = source || installedFonts;
        var text = (query || "").trim().toLowerCase();
        if (!text.length) return list;

        var output = [];
        for (var i = 0; i < list.length; ++i) {
            var family = list[i];
            if (family.toLowerCase().indexOf(text) !== -1) output.push(family);
        }
        return output;
    }

    function toggleDropdown(name) {
        openDropdown = openDropdown === name ? "" : name;
        if (openDropdown !== "general") generalSearchText = "";
        if (openDropdown !== "fixed") fixedSearchText = "";
        if (openDropdown.length > 0) ensureFontCatalog();
    }

    function selectFont(target, family) {
        if (target === "general") {
            generalFontFamily = family;
            generalSearchText = "";
        } else {
            fixedFontFamily = family;
            fixedSearchText = "";
        }
        openDropdown = "";
    }

    function applySettings() {
        var generalValue = buildFontValue(generalFontFamily, generalFontSize);
        var fixedValue = buildFontValue(fixedFontFamily, fixedFontSize);
        var qt6GeneralValue = buildQt6ctFontValue(generalFontFamily, generalFontSize);
        var qt6FixedValue = buildQt6ctFontValue(fixedFontFamily, fixedFontSize);

        if (!generalValue.length || !fixedValue.length) {
            statusError = true;
            statusMessage = "Font family can't be empty.";
            return;
        }

        openDropdown = "";
        statusMessage = "";
        statusError = false;
        saveInProgress = true;

        saveProc.command = [
            "/bin/bash", "-lc",
            "set -e\n"
            + "kwriteconfig6 --file kdeglobals --group General --key font \"$1\"\n"
            + "kwriteconfig6 --file kdeglobals --group General --key fixed \"$2\"\n"
            + "if [ \"$3\" = \"1\" ]; then\n"
            + "  kwriteconfig6 --file \"$4\" --group Fonts --key general \"$5\"\n"
            + "  kwriteconfig6 --file \"$4\" --group Fonts --key fixed \"$6\"\n"
            + "fi\n"
            + "kwriteconfig6 --file \"$7\" --group DetailsMode --key UseSystemFont true\n",
            "--",
            generalValue,
            fixedValue,
            qt6ctActive ? "1" : "0",
            qt6ctConfigPath,
            qt6GeneralValue,
            qt6FixedValue,
            dolphinConfigPath
        ];
        saveProc.running = true;
    }

    onGeneralFontFamilyChanged: {
        if (generalInput.text !== generalFontFamily) generalInput.text = generalFontFamily;
    }

    onFixedFontFamilyChanged: {
        if (fixedInput.text !== fixedFontFamily) fixedInput.text = fixedFontFamily;
    }

    Component.onCompleted: loadCurrentValues()

    CommandValue {
        id: readGeneral
        command: fontsPage.qt6ctActive
            ? ["kreadconfig6", "--file", fontsPage.qt6ctConfigPath, "--group", "Fonts", "--key", "general"]
            : ["kreadconfig6", "--file", "kdeglobals", "--group", "General", "--key", "font"]
        fallback: ""
        onLoaded: value => {
            var parsed = fontsPage.parseFontValue(value, fontsPage.generalFontFamily, fontsPage.generalFontSize);
            fontsPage.generalFontFamily = parsed.family;
            fontsPage.generalFontSize = parsed.size;
            fontsPage.finishRead();
        }
    }

    CommandValue {
        id: readFixed
        command: fontsPage.qt6ctActive
            ? ["kreadconfig6", "--file", fontsPage.qt6ctConfigPath, "--group", "Fonts", "--key", "fixed"]
            : ["kreadconfig6", "--file", "kdeglobals", "--group", "General", "--key", "fixed"]
        fallback: ""
        onLoaded: value => {
            var parsed = fontsPage.parseFontValue(value, fontsPage.fixedFontFamily, fontsPage.fixedFontSize);
            fontsPage.fixedFontFamily = parsed.family;
            fontsPage.fixedFontSize = parsed.size;
            fontsPage.finishRead();
        }
    }

    Process {
        id: fontScanProc
        command: ["/bin/bash", "-lc", fontsPage.fontScanCommand]
        running: false
        property string buffer: ""

        stdout: SplitParser {
            onRead: data => {
                if (data.length > 0) fontScanProc.buffer += data + "\n";
            }
        }

        onExited: {
            fontsPage.loadingCatalog = false;
            fontsPage.parseInstalledFonts(fontScanProc.buffer);
            fontScanProc.buffer = "";
        }
    }

    Process {
        id: saveProc
        command: []
        running: false
        onExited: exitCode => {
            fontsPage.saveInProgress = false;
            fontsPage.statusError = exitCode !== 0;
            fontsPage.statusMessage = exitCode === 0
                ? "Fonts saved. Reopen Dolphin for the changes to fully apply."
                : "Failed to save font settings.";
            if (exitCode === 0) {
                fontsPage.loadCurrentValues();
                if (typeof Theme !== "undefined" && Theme.reloadSystemFonts) Theme.reloadSystemFonts();
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn
            width: parent.width
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 20
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰛖"
                    font.pixelSize: 20
                    font.family: "JetBrainsMono Nerd Font"
                    color: Theme.primary
                }

                Text {
                    font.family: Theme.fontFamily
                    text: "Fonts"
                    font.bold: true
                    font.pixelSize: 18
                    color: SettingsPalette.text
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    radius: 8
                    color: saveInProgress
                        ? Qt.rgba(249/255, 226/255, 175/255, 0.14)
                        : Qt.rgba(166/255, 227/255, 161/255, 0.14)
                    implicitWidth: backendRow.implicitWidth + 16
                    implicitHeight: 28

                    RowLayout {
                        id: backendRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            font.family: Theme.fontFamily
                            text: "●"
                            color: saveInProgress ? "#f9e2af" : Theme.green
                            font.pixelSize: 11
                        }

                        Text {
                            font.family: Theme.fontFamily
                            text: saveInProgress ? "Saving" : ("Backend: " + backendLabel)
                            color: SettingsPalette.text
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }

            SectionCard {
                RowLayout {
                    id: overviewRow
                    Layout.fillWidth: true
                    spacing: 14

                    SummaryTile {
                        Layout.preferredWidth: 170
                        iconText: "Aa"
                        accentColor: Theme.primary
                        heading: "General"
                        summary: fontsPage.generalPreviewText
                        previewFamily: fontsPage.generalFontFamily
                    }

                    SummaryTile {
                        Layout.preferredWidth: 170
                        iconText: "</>"
                        accentColor: "#cba6f7"
                        heading: "Monospace"
                        summary: fontsPage.fixedPreviewText
                        previewFamily: fontsPage.fixedFontFamily
                    }

                    SummaryTile {
                        Layout.fillWidth: true
                        iconText: "󰉋"
                        accentColor: "#a6e3a1"
                        heading: "Catalog"
                        summary: fontsPage.fontCount > 0
                            ? (fontsPage.fontCount + " families")
                            : (fontsPage.loadingCatalog ? "Scanning" : "Not ready")
                        helper: "/usr/share/fonts"
                    }
                }
            }

            SectionCard {
                title: "Preview"
                description: "Changes preview here first, then Apply writes them to the active backend."

                Rectangle {
                    Layout.fillWidth: true
                    radius: 12
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.05)
                    border.width: 1
                    implicitHeight: previewColumn.implicitHeight + 24

                    ColumnLayout {
                        id: previewColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "Dolphin Preview"
                            color: SettingsPalette.text
                            font.family: fontsPage.generalFontFamily
                            font.pointSize: fontsPage.generalFontSize + 1
                            font.bold: true
                        }

                        Text {
                            text: "Documents   Downloads   Pictures   Music"
                            color: SettingsPalette.subtext
                            font.family: fontsPage.generalFontFamily
                            font.pointSize: fontsPage.generalFontSize
                        }

                        Text {
                            text: "example-file.txt    18 KB    Today"
                            color: Theme.primary
                            font.family: fontsPage.generalFontFamily
                            font.pointSize: fontsPage.generalFontSize
                        }

                        Text {
                            text: "Monospace preview: const path = \"/home/Eko/Documents\";"
                            color: SettingsPalette.text
                            font.family: fontsPage.fixedFontFamily
                            font.pointSize: fontsPage.fixedFontSize
                        }
                    }
                }
            }

            SectionCard {
                title: "General Font"
                description: "The main typeface used by Dolphin and Qt applications."

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        font.family: Theme.fontFamily
                        text: fontsPage.generalFontFamily
                        color: Theme.primary
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        font.family: Theme.fontFamily
                        text: fontsPage.generalFontSize + " pt"
                        color: Theme.primary
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: generalDropArea.containsMouse ? Qt.rgba(69/255, 71/255, 90/255, 0.8) : Qt.rgba(49/255, 50/255, 68/255, 0.6)
                    border.color: openDropdown === "general" ? Theme.primary : Qt.rgba(255,255,255,0.08)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "Aa"
                            color: Theme.primary
                            font.family: fontsPage.generalFontFamily
                            font.pixelSize: 16
                            font.bold: true
                        }

                        Text {
                            font.family: Theme.fontFamily
                            text: fontsPage.generalFontFamily
                            color: SettingsPalette.text
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            font.family: Theme.fontFamily
                            text: openDropdown === "general" ? "▴" : "▾"
                            color: SettingsPalette.subtext
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: generalDropArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fontsPage.toggleDropdown("general")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: openDropdown === "general"
                    implicitHeight: Math.min(generalDropdownColumn.implicitHeight + 8, 260)
                    color: Qt.rgba(49/255, 50/255, 68/255, 0.95)
                    radius: 10
                    border.color: Qt.rgba(255,255,255,0.08)
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        id: generalDropdownColumn
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 8
                            color: Qt.rgba(255,255,255,0.05)
                            border.color: generalSearchInput.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.08)
                            border.width: 1

                            TextInput {
                                id: generalSearchInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: fontsPage.generalSearchText
                                color: SettingsPalette.text
                                font.pixelSize: 12
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                onTextChanged: fontsPage.generalSearchText = text
                            }

                            Text {
                                font.family: Theme.fontFamily
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: "Search font..."
                                color: SettingsPalette.overlay
                                font.pixelSize: 12
                                visible: generalSearchInput.text.length === 0 && !generalSearchInput.activeFocus
                            }
                        }

                        Text {
                            font.family: Theme.fontFamily
                            Layout.fillWidth: true
                            text: fontsPage.loadingCatalog
                                ? "Building font list..."
                                : (fontsPage.generalFilteredFonts.length > 0
                                    ? fontsPage.generalFilteredFonts.length + " results"
                                    : "No matching fonts")
                            color: SettingsPalette.subtext
                            font.pixelSize: 10
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 206
                            contentHeight: generalFontOptions.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: generalFontOptions
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: fontsPage.generalFilteredFonts

                                    Rectangle {
                                        required property string modelData
                                        width: parent.width
                                        height: 36
                                        radius: 8
                                        color: generalOptionArea.containsMouse || fontsPage.generalFontFamily === modelData
                                            ? Qt.rgba(137/255, 180/255, 250/255, 0.14)
                                            : "transparent"
                                        border.color: fontsPage.generalFontFamily === modelData ? Theme.primary : "transparent"
                                        border.width: fontsPage.generalFontFamily === modelData ? 1 : 0

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            Text {
                                                text: "Aa"
                                                color: fontsPage.generalFontFamily === modelData ? Theme.primary : SettingsPalette.subtext
                                                font.family: modelData
                                                font.pixelSize: 14
                                                font.bold: true
                                            }

                                            Text {
                                                font.family: Theme.fontFamily
                                                text: modelData
                                                color: SettingsPalette.text
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: generalOptionArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: fontsPage.selectFont("general", modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: Qt.rgba(49/255, 50/255, 68/255, 0.6)
                    border.color: generalInput.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.08)
                    border.width: 1

                    TextInput {
                        id: generalInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        text: fontsPage.generalFontFamily
                        color: SettingsPalette.text
                        font.pixelSize: 13
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        onTextChanged: fontsPage.generalFontFamily = text
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: fontsPage.generalSuggestions
                        delegate: SuggestionChip {
                            label: modelData
                            selected: fontsPage.generalFontFamily === modelData
                            accentColor: Theme.primary
                            onClicked: fontsPage.generalFontFamily = modelData
                        }
                    }
                }

                Slider {
                    Layout.fillWidth: true
                    from: 8
                    to: 22
                    stepSize: 1
                    value: fontsPage.generalFontSize
                    onMoved: fontsPage.generalFontSize = Math.round(value)
                }
            }

            SectionCard {
                title: "Monospace Font"
                description: "For code, terminals, and fixed-width content."

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        font.family: Theme.fontFamily
                        text: fontsPage.fixedFontFamily
                        color: "#cba6f7"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        font.family: Theme.fontFamily
                        text: fontsPage.fixedFontSize + " pt"
                        color: "#cba6f7"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: fixedDropArea.containsMouse ? Qt.rgba(69/255, 71/255, 90/255, 0.8) : Qt.rgba(49/255, 50/255, 68/255, 0.6)
                    border.color: openDropdown === "fixed" ? Theme.primary : Qt.rgba(255,255,255,0.08)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "</>"
                            color: "#cba6f7"
                            font.family: fontsPage.fixedFontFamily
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            font.family: Theme.fontFamily
                            text: fontsPage.fixedFontFamily
                            color: SettingsPalette.text
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            font.family: Theme.fontFamily
                            text: openDropdown === "fixed" ? "▴" : "▾"
                            color: SettingsPalette.subtext
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: fixedDropArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fontsPage.toggleDropdown("fixed")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: openDropdown === "fixed"
                    implicitHeight: Math.min(fixedDropdownColumn.implicitHeight + 8, 260)
                    color: Qt.rgba(49/255, 50/255, 68/255, 0.95)
                    radius: 10
                    border.color: Qt.rgba(255,255,255,0.08)
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        id: fixedDropdownColumn
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 8
                            color: Qt.rgba(255,255,255,0.05)
                            border.color: fixedSearchInput.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.08)
                            border.width: 1

                            TextInput {
                                id: fixedSearchInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: fontsPage.fixedSearchText
                                color: SettingsPalette.text
                                font.pixelSize: 12
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                onTextChanged: fontsPage.fixedSearchText = text
                            }

                            Text {
                                font.family: Theme.fontFamily
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                text: "Search font..."
                                color: SettingsPalette.overlay
                                font.pixelSize: 12
                                visible: fixedSearchInput.text.length === 0 && !fixedSearchInput.activeFocus
                            }
                        }

                        Text {
                            font.family: Theme.fontFamily
                            Layout.fillWidth: true
                            text: fontsPage.loadingCatalog
                                ? "Building font list..."
                                : (fontsPage.fixedFilteredFonts.length > 0
                                    ? fontsPage.fixedFilteredFonts.length + " results"
                                    : "No matching fonts")
                            color: SettingsPalette.subtext
                            font.pixelSize: 10
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 206
                            contentHeight: fixedFontOptions.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: fixedFontOptions
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: fontsPage.fixedFilteredFonts

                                    Rectangle {
                                        required property string modelData
                                        width: parent.width
                                        height: 36
                                        radius: 8
                                        color: fixedOptionArea.containsMouse || fontsPage.fixedFontFamily === modelData
                                            ? Qt.rgba(203/255, 166/255, 247/255, 0.14)
                                            : "transparent"
                                        border.color: fontsPage.fixedFontFamily === modelData ? "#cba6f7" : "transparent"
                                        border.width: fontsPage.fixedFontFamily === modelData ? 1 : 0

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            Text {
                                                text: "</>"
                                                color: fontsPage.fixedFontFamily === modelData ? "#cba6f7" : SettingsPalette.subtext
                                                font.family: modelData
                                                font.pixelSize: 13
                                                font.bold: true
                                            }

                                            Text {
                                                font.family: Theme.fontFamily
                                                text: modelData
                                                color: SettingsPalette.text
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: fixedOptionArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: fontsPage.selectFont("fixed", modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: Qt.rgba(49/255, 50/255, 68/255, 0.6)
                    border.color: fixedInput.activeFocus ? Theme.primary : Qt.rgba(255,255,255,0.08)
                    border.width: 1

                    TextInput {
                        id: fixedInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        text: fontsPage.fixedFontFamily
                        color: SettingsPalette.text
                        font.pixelSize: 13
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        onTextChanged: fontsPage.fixedFontFamily = text
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: fontsPage.monoSuggestions
                        delegate: SuggestionChip {
                            label: modelData
                            selected: fontsPage.fixedFontFamily === modelData
                            accentColor: "#cba6f7"
                            onClicked: fontsPage.fixedFontFamily = modelData
                        }
                    }
                }

                Slider {
                    Layout.fillWidth: true
                    from: 8
                    to: 22
                    stepSize: 1
                    value: fontsPage.fixedFontSize
                    onMoved: fontsPage.fixedFontSize = Math.round(value)
                }
            }

            SectionCard {
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ActionButton {
                        label: fontsPage.saveInProgress ? "Saving..." : "Apply"
                        enabled: !fontsPage.saveInProgress && !fontsPage.loadingConfig
                        onClicked: fontsPage.applySettings()
                    }

                    ActionButton {
                        label: "Reload"
                        fillColor: Qt.rgba(255,255,255,0.08)
                        labelColor: SettingsPalette.text
                        enabled: !fontsPage.saveInProgress
                        onClicked: fontsPage.loadCurrentValues()
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: fontsPage.statusMessage.length > 0
                    color: fontsPage.statusError ? Qt.rgba(243/255, 139/255, 168/255, 0.12) : Qt.rgba(166/255, 227/255, 161/255, 0.12)
                    border.color: fontsPage.statusError ? Qt.rgba(243/255, 139/255, 168/255, 0.24) : Qt.rgba(166/255, 227/255, 161/255, 0.24)
                    border.width: 1
                    radius: 10
                    implicitHeight: statusRow.implicitHeight + 16

                    RowLayout {
                        id: statusRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: fontsPage.statusError ? "󰅙" : "󰄬"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            color: fontsPage.statusError ? Theme.red : Theme.green
                        }

                        Text {
                            font.family: Theme.fontFamily
                            text: fontsPage.statusMessage
                            color: fontsPage.statusError ? Theme.red : Theme.green
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
