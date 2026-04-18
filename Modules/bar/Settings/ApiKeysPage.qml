import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "SettingsPalette.js" as SettingsPalette
import "../../../Widgets"
import "../../../Services/core" as Core

// ─────────────────────────────────────────────────────────────────────────
// API Keys — UI for configuring the AI reranker used by SmartComplete
// (Fcitx5 keyboard addon).
//
// Writes ~/.config/linuxcomplete/api_keys.json with chmod 600.
// SmartComplete picks up the file on fcitx5 restart (we auto-restart).
// ─────────────────────────────────────────────────────────────────────────
Item {
    id: page

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string keyFilePath: homeDir + "/.config/linuxcomplete/api_keys.json"

    // ── Provider presets ──────────────────────────────────────────────────
    readonly property var providers: [
        {
            id: "local",
            name: "Local only",
            description: "100% offline — no network, no key needed",
            api_base: "",
            key_prefix: "",
            key_example: "",
            models: [],
            signup_url: "",
            native: true,
            is_local: true
        },
        {
            id: "openai",
            name: "OpenAI",
            description: "ChatGPT API (paid)",
            api_base: "https://api.openai.com/v1",
            key_prefix: "sk-",
            key_example: "sk-...",
            models: ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"],
            signup_url: "https://platform.openai.com/api-keys",
            native: true
        },
        {
            id: "groq",
            name: "Groq",
            description: "Free, fast LLaMA inference",
            api_base: "https://api.groq.com/openai/v1",
            key_prefix: "gsk_",
            key_example: "gsk_...",
            models: ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768"],
            signup_url: "https://console.groq.com/keys",
            native: true
        },
        {
            id: "gemini",
            name: "Google Gemini",
            description: "Free tier (1500 req/day) — via OpenRouter recommended",
            api_base: "https://openrouter.ai/api/v1",
            key_prefix: "sk-or-",
            key_example: "sk-or-...",
            models: ["google/gemini-2.0-flash-exp:free", "google/gemini-flash-1.5"],
            signup_url: "https://openrouter.ai/keys",
            native: false,
            via: "OpenRouter"
        },
        {
            id: "claude",
            name: "Anthropic Claude",
            description: "Via OpenRouter (native API in Phase 2)",
            api_base: "https://openrouter.ai/api/v1",
            key_prefix: "sk-or-",
            key_example: "sk-or-...",
            models: ["anthropic/claude-3-5-haiku", "anthropic/claude-3-5-sonnet"],
            signup_url: "https://openrouter.ai/keys",
            native: false,
            via: "OpenRouter"
        },
        {
            id: "ollama",
            name: "Ollama",
            description: "100% local — private, free, offline",
            api_base: "http://localhost:11434/v1",
            key_prefix: "",
            key_example: "(any value, not used)",
            models: ["llama3.2:3b", "llama3.1:8b", "phi3:mini", "qwen2.5:3b", "mistral:7b"],
            signup_url: "https://ollama.com",
            native: true
        },
        {
            id: "openrouter",
            name: "OpenRouter",
            description: "Gateway to 200+ models (mix of free + paid)",
            api_base: "https://openrouter.ai/api/v1",
            key_prefix: "sk-or-",
            key_example: "sk-or-...",
            models: ["meta-llama/llama-3.1-8b-instruct:free", "google/gemini-2.0-flash-exp:free", "anthropic/claude-3-5-haiku", "openai/gpt-4o-mini"],
            signup_url: "https://openrouter.ai/keys",
            native: true
        },
        {
            id: "custom",
            name: "Custom",
            description: "Any OpenAI-compatible endpoint",
            api_base: "",
            key_prefix: "",
            key_example: "your key here",
            models: [],
            signup_url: "",
            native: true
        }
    ]

    // ── Current selection + form state ────────────────────────────────────
    property string selectedProviderId: "groq"
    property string apiKey: ""
    property string model: ""
    property string apiBase: ""
    property bool keyVisible: false

    property string testStatus: ""  // "", "testing", "success", "error"
    property string testMessage: ""
    property int testLatencyMs: 0

    property string saveStatus: ""  // "", "saving", "saved", "error"
    property string saveMessage: ""

    // Helper: find provider by id.
    function providerById(id) {
        for (let i = 0; i < providers.length; i++) {
            if (providers[i].id === id) return providers[i];
        }
        return providers[0];
    }

    readonly property var currentProvider: providerById(selectedProviderId)

    function selectProvider(id) {
        selectedProviderId = id;
        const p = providerById(id);
        apiBase = p.api_base;
        if (p.models.length > 0 && !p.models.includes(model)) {
            model = p.models[0];
        }
        testStatus = "";
        testMessage = "";
        saveStatus = "";
        saveMessage = "";
    }

    // ── Load existing config on mount ─────────────────────────────────────
    Core.TextDataStore {
        id: keyStore
        path: page.keyFilePath
        onLoaded: text => {
            if (!text || text.trim() === "") return; // empty / missing file → keep defaults
            try {
                const parsed = JSON.parse(text);
                if (parsed.provider) page.selectedProviderId = parsed.provider;
                if (parsed.api_base) page.apiBase = parsed.api_base;
                if (parsed.model) page.model = parsed.model;
                if (parsed.api_key) page.apiKey = parsed.api_key;
            } catch (e) {
                // Invalid JSON — keep defaults.
            }
        }
    }

    Component.onCompleted: {
        // Start with sensible defaults for the initially-selected provider,
        // THEN let the file (if present) override anything it specifies.
        const p = page.currentProvider;
        page.apiBase = p.api_base;
        if (p.models.length > 0) page.model = p.models[0];
        keyStore.read();
    }

    // ── Test connection process ───────────────────────────────────────────
    property int _testStartTime: 0
    Process {
        id: testProc
        running: false
        property string buffer: ""
        stdout: SplitParser { onRead: data => { testProc.buffer += data; } }
        onExited: exitCode => {
            page.testLatencyMs = Date.now() - page._testStartTime;
            try {
                const resp = JSON.parse(testProc.buffer);
                if (resp.error) {
                    page.testStatus = "error";
                    page.testMessage = (resp.error.message || "API error").substring(0, 80);
                } else if (resp.choices && resp.choices.length > 0) {
                    page.testStatus = "success";
                    page.testMessage = "Pong received (" + page.testLatencyMs + "ms)";
                } else {
                    page.testStatus = "error";
                    page.testMessage = "Unexpected response shape";
                }
            } catch (e) {
                page.testStatus = "error";
                page.testMessage = "Network error or invalid JSON (exit " + exitCode + ")";
            }
            testProc.buffer = "";
        }
    }

    function testConnection() {
        if (!page.apiKey || page.apiKey.trim() === "") {
            page.testStatus = "error";
            page.testMessage = "API key is empty";
            return;
        }
        if (!page.apiBase || page.apiBase.trim() === "") {
            page.testStatus = "error";
            page.testMessage = "API base URL is empty";
            return;
        }
        page.testStatus = "testing";
        page.testMessage = "Contacting " + page.apiBase + "...";
        page._testStartTime = Date.now();

        let base = page.apiBase;
        while (base.length > 0 && base.charAt(base.length - 1) === "/") base = base.slice(0, -1);
        const endpoint = base + "/chat/completions";
        const payload = JSON.stringify({
            model: page.model,
            messages: [{ role: "user", content: "pong" }],
            max_tokens: 5
        });

        testProc.command = [
            "curl", "-sS", "--max-time", "10",
            endpoint,
            "-H", "Authorization: Bearer " + page.apiKey,
            "-H", "Content-Type: application/json",
            "-d", payload
        ];
        testProc.buffer = "";
        testProc.running = true;
    }

    // ── Save config + restart fcitx5 ──────────────────────────────────────
    Process {
        id: saveProc
        running: false
        property string buffer: ""
        stderr: SplitParser { onRead: data => { saveProc.buffer += data; } }
        onExited: exitCode => {
            if (exitCode === 0) {
                page.saveStatus = "saved";
                page.saveMessage = "Saved and fcitx5 restarted — new key is active";
            } else {
                page.saveStatus = "error";
                page.saveMessage = "Save failed (exit " + exitCode + "): " + saveProc.buffer.substring(0, 80);
            }
            saveProc.buffer = "";
        }
    }

    function saveConfig() {
        const isLocal = page.selectedProviderId === "local";

        if (!isLocal && (!page.apiKey || page.apiKey.trim() === "")) {
            page.saveStatus = "error";
            page.saveMessage = "API key cannot be empty";
            return;
        }
        page.saveStatus = "saving";
        page.saveMessage = isLocal
            ? "Activating local-only mode..."
            : "Writing file and restarting fcitx5...";

        // Local mode writes a minimal marker — SmartComplete short-circuits
        // on "provider": "local" and never calls any API.
        const config = isLocal
            ? { provider: "local", ai_enabled: false }
            : {
                provider: page.selectedProviderId,
                api_base: page.apiBase,
                model: page.model,
                api_key: page.apiKey
            };
        const payload = JSON.stringify(config, null, 2);

        const script =
            'dir="$HOME/.config/linuxcomplete"; ' +
            'mkdir -p "$dir"; ' +
            'tmp=$(mktemp "$dir/.XXXXXX") || exit 1; ' +
            'printf "%s" "$1" > "$tmp" && ' +
            'chmod 600 "$tmp" && ' +
            'mv -- "$tmp" "$dir/api_keys.json" || { rm -f "$tmp"; exit 1; }; ' +
            '(killall fcitx5 2>/dev/null; sleep 0.8; setsid nohup fcitx5 -d >/dev/null 2>&1 &) ' +
            '|| true';

        saveProc.command = ["sh", "-c", script, "--", payload];
        saveProc.buffer = "";
        saveProc.running = true;
    }

    // ─────────────────────────────────────────────────────────────────────
    // UI
    // ─────────────────────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentWidth: width
        contentHeight: layout.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: layout
            width: parent.width
            spacing: 16

            // ── Header ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 12
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "󰌆"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "API Keys"
                        color: SettingsPalette.text
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Text {
                        text: "Configure the AI provider used by SmartComplete keyboard prediction"
                        color: SettingsPalette.subtext
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            // ── Provider picker (card grid) ────────────────────────────
            Text {
                text: "Provider"
                color: SettingsPalette.text
                font.pixelSize: 14
                font.bold: true
                Layout.topMargin: 4
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: page.providers
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool selected: page.selectedProviderId === modelData.id

                        width: 180
                        height: 72
                        radius: 10
                        color: selected
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            : Qt.rgba(255, 255, 255, 0.03)
                        border.color: selected
                            ? Theme.primary
                            : Qt.rgba(255, 255, 255, 0.08)
                        border.width: selected ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: modelData.name
                                    color: SettingsPalette.text
                                    font.pixelSize: 13
                                    font.bold: true
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: parent.parent.parent.selected
                                    text: "✓"
                                    color: Theme.primary
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            Text {
                                text: modelData.description
                                color: SettingsPalette.subtext
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                maximumLineCount: 2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.selectProvider(modelData.id)
                        }
                    }
                }
            }

            // ── LOCAL ONLY info panel (shown when "Local only" selected) ──
            Rectangle {
                visible: page.selectedProviderId === "local"
                Layout.fillWidth: true
                Layout.preferredHeight: localCol.implicitHeight + 32
                radius: 12
                color: Qt.rgba(166/255, 227/255, 161/255, 0.08)
                border.color: Qt.rgba(166/255, 227/255, 161/255, 0.3)
                border.width: 1

                ColumnLayout {
                    id: localCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 10
                            color: Qt.rgba(166/255, 227/255, 161/255, 0.15)
                            border.color: Qt.rgba(166/255, 227/255, 161/255, 0.4)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "󰒘"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                                color: "#a6e3a1"
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: "100% Local Mode"
                                color: "#a6e3a1"
                                font.pixelSize: 15
                                font.bold: true
                            }
                            Text {
                                text: "No network, no API key, no data leaves your machine"
                                color: SettingsPalette.subtext
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(166/255, 227/255, 161/255, 0.2)
                    }

                    Text {
                        text: "SmartComplete will use only the built-in data on your system:"
                        color: SettingsPalette.text
                        font.pixelSize: 12
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        spacing: 4

                        Repeater {
                            model: [
                                { icon: "󰂺", label: "Dictionary", detail: "74,000+ English words" },
                                { icon: "󰨸", label: "Grammar rules", detail: "25,000+ pair and triple patterns" },
                                { icon: "󰒡", label: "N-grams + phrases", detail: "48,000 bigrams, 787 phrase completions" },
                                { icon: "󰈸", label: "Emoji shortcodes", detail: "303 entries (:smile → 😊)" },
                                { icon: "󰔠", label: "Your learned words", detail: "Saved to ~/.local/share/linuxcomplete/" }
                            ]
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: modelData.icon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: "#a6e3a1"
                                    Layout.preferredWidth: 20
                                }
                                Text {
                                    text: modelData.label
                                    color: SettingsPalette.text
                                    font.pixelSize: 11
                                    font.bold: true
                                    Layout.preferredWidth: 150
                                }
                                Text {
                                    text: modelData.detail
                                    color: SettingsPalette.subtext
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 36
                            radius: 8
                            color: localSaveArea.containsMouse
                                ? Qt.rgba(166/255, 227/255, 161/255, 0.25)
                                : Qt.rgba(166/255, 227/255, 161/255, 0.15)
                            border.color: "#a6e3a1"
                            border.width: 1
                            enabled: page.saveStatus !== "saving"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰒘"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: "#a6e3a1"
                                }
                                Text {
                                    text: page.saveStatus === "saving" ? "Saving..." : "Activate Local-Only Mode"
                                    color: "#a6e3a1"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: localSaveArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (parent.enabled) page.saveConfig()
                            }
                        }
                    }

                    // Status message for local mode save
                    Rectangle {
                        visible: page.saveStatus !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: localStatusText.implicitHeight + 16
                        radius: 6
                        color: Qt.rgba(0, 0, 0, 0.2)
                        border.color: page.saveStatus === "saved"
                            ? Qt.rgba(166/255, 227/255, 161/255, 0.4)
                            : Qt.rgba(243/255, 139/255, 168/255, 0.4)
                        border.width: 1
                        Text {
                            id: localStatusText
                            anchors.fill: parent
                            anchors.margins: 8
                            text: "💾 " + (page.saveStatus === "saved" ? "✓ " : (page.saveStatus === "error" ? "✗ " : "… ")) + page.saveMessage
                            color: {
                                if (page.saveStatus === "saved") return "#a6e3a1";
                                if (page.saveStatus === "error") return "#f38ba8";
                                return SettingsPalette.text;
                            }
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ── Provider details panel (hidden for Local only) ─────────────
            Rectangle {
                visible: page.selectedProviderId !== "local"
                Layout.fillWidth: true
                Layout.preferredHeight: detailsColumn.implicitHeight + 32
                radius: 12
                color: Qt.rgba(255, 255, 255, 0.025)
                border.color: Qt.rgba(255, 255, 255, 0.06)
                border.width: 1

                ColumnLayout {
                    id: detailsColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Get API key link
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: page.currentProvider.signup_url.length > 0

                        Text {
                            text: "Get an API key: "
                            color: SettingsPalette.subtext
                            font.pixelSize: 12
                        }
                        Rectangle {
                            Layout.preferredWidth: linkText.implicitWidth + 16
                            Layout.preferredHeight: 24
                            radius: 6
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                            border.width: 1
                            Text {
                                id: linkText
                                anchors.centerIn: parent
                                text: page.currentProvider.signup_url
                                color: Theme.primary
                                font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally(page.currentProvider.signup_url)
                            }
                        }
                    }

                    // Model picker
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Model"
                            color: SettingsPalette.subtext
                            font.pixelSize: 12
                            Layout.preferredWidth: 80
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: page.currentProvider.models.length > 0

                            Repeater {
                                model: page.currentProvider.models
                                delegate: Rectangle {
                                    required property string modelData
                                    readonly property bool selected: page.model === modelData
                                    implicitWidth: modelLabel.implicitWidth + 20
                                    implicitHeight: 28
                                    radius: 6
                                    color: selected
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                                        : Qt.rgba(255, 255, 255, 0.04)
                                    border.color: selected
                                        ? Theme.primary
                                        : Qt.rgba(255, 255, 255, 0.08)
                                    border.width: 1

                                    Text {
                                        id: modelLabel
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: selected ? Theme.primary : SettingsPalette.text
                                        font.pixelSize: 11
                                        font.bold: selected
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.model = modelData
                                    }
                                }
                            }
                        }

                        // For custom provider: editable model field
                        Rectangle {
                            visible: page.selectedProviderId === "custom"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.color: Qt.rgba(255, 255, 255, 0.1)
                            border.width: 1

                            TextInput {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: SettingsPalette.text
                                font.pixelSize: 12
                                text: page.model
                                selectByMouse: true
                                onTextChanged: page.model = text
                            }
                        }
                    }

                    // API Base URL (editable for custom)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "API Base"
                            color: SettingsPalette.subtext
                            font.pixelSize: 12
                            Layout.preferredWidth: 80
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: page.selectedProviderId === "custom"
                                ? Qt.rgba(255, 255, 255, 0.04)
                                : Qt.rgba(255, 255, 255, 0.02)
                            border.color: Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1

                            TextInput {
                                id: baseInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: SettingsPalette.text
                                font.pixelSize: 11
                                font.family: "JetBrainsMono Nerd Font"
                                text: page.apiBase
                                selectByMouse: true
                                readOnly: page.selectedProviderId !== "custom"
                                onTextChanged: if (!readOnly) page.apiBase = text
                            }
                        }
                    }

                    // API Key input
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "API Key"
                            color: SettingsPalette.subtext
                            font.pixelSize: 12
                            Layout.preferredWidth: 80
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: Qt.rgba(255, 255, 255, 0.04)
                            border.color: keyInput.activeFocus
                                ? Theme.primary
                                : Qt.rgba(255, 255, 255, 0.1)
                            border.width: 1

                            TextInput {
                                id: keyInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: SettingsPalette.text
                                font.pixelSize: 11
                                font.family: "JetBrainsMono Nerd Font"
                                text: page.apiKey
                                selectByMouse: true
                                echoMode: page.keyVisible ? TextInput.Normal : TextInput.Password
                                onTextChanged: page.apiKey = text
                                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: keyInput.text.length === 0 && !keyInput.activeFocus
                                    text: page.currentProvider.key_example
                                    color: SettingsPalette.overlay2
                                    font: keyInput.font
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 6
                            color: page.keyVisible
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                : Qt.rgba(255, 255, 255, 0.04)
                            border.color: Qt.rgba(255, 255, 255, 0.1)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: page.keyVisible ? "󰈈" : "󰈉"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: page.keyVisible ? Theme.primary : SettingsPalette.subtext
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.keyVisible = !page.keyVisible
                            }
                        }
                    }

                    // Action buttons
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 8

                        // Test connection
                        Rectangle {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 36
                            radius: 8
                            color: testArea.containsMouse
                                ? Qt.rgba(255, 255, 255, 0.08)
                                : Qt.rgba(255, 255, 255, 0.04)
                            border.color: Qt.rgba(255, 255, 255, 0.12)
                            border.width: 1
                            enabled: page.testStatus !== "testing"
                            opacity: enabled ? 1 : 0.5

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: page.testStatus === "testing" ? "󰑮" : "🧪"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: SettingsPalette.text
                                    RotationAnimation on rotation {
                                        running: page.testStatus === "testing"
                                        from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                                    }
                                }
                                Text {
                                    text: page.testStatus === "testing" ? "Testing..." : "Test connection"
                                    color: SettingsPalette.text
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: testArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (parent.enabled) page.testConnection()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Save & activate
                        Rectangle {
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 36
                            radius: 8
                            color: saveArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            border.color: Theme.primary
                            border.width: 1
                            enabled: page.saveStatus !== "saving" && page.apiKey.length > 0

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "💾"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: Theme.primary
                                }
                                Text {
                                    text: page.saveStatus === "saving" ? "Saving..." : "Save & Activate"
                                    color: Theme.primary
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: saveArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (parent.enabled) page.saveConfig()
                            }
                        }
                    }

                    // Status messages
                    Rectangle {
                        visible: page.testStatus !== "" || page.saveStatus !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: statusCol.implicitHeight + 20
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.2)
                        border.color: {
                            if (page.testStatus === "success" || page.saveStatus === "saved") {
                                return Qt.rgba(166/255, 227/255, 161/255, 0.4);
                            }
                            if (page.testStatus === "error" || page.saveStatus === "error") {
                                return Qt.rgba(243/255, 139/255, 168/255, 0.4);
                            }
                            return Qt.rgba(255, 255, 255, 0.08);
                        }
                        border.width: 1

                        ColumnLayout {
                            id: statusCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            Text {
                                visible: page.testStatus !== ""
                                text: "🧪 " + (page.testStatus === "success" ? "✓ " : (page.testStatus === "error" ? "✗ " : "… ")) + page.testMessage
                                color: {
                                    if (page.testStatus === "success") return "#a6e3a1";
                                    if (page.testStatus === "error") return "#f38ba8";
                                    return SettingsPalette.text;
                                }
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: page.saveStatus !== ""
                                text: "💾 " + (page.saveStatus === "saved" ? "✓ " : (page.saveStatus === "error" ? "✗ " : "… ")) + page.saveMessage
                                color: {
                                    if (page.saveStatus === "saved") return "#a6e3a1";
                                    if (page.saveStatus === "error") return "#f38ba8";
                                    return SettingsPalette.text;
                                }
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // ── Footer info ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: footerCol.implicitHeight + 20
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.02)
                border.color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1

                ColumnLayout {
                    id: footerCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text: "ℹ  How it works"
                        color: SettingsPalette.subtext
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        text: "Your key is saved to ~/.config/linuxcomplete/api_keys.json (chmod 600 — user-readable only). SmartComplete reads this file on every AI rerank, so switching providers is instant after clicking Save (fcitx5 restarts automatically). Core prediction works without AI — if the network fails, local ranking stays."
                        color: SettingsPalette.subtext
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
