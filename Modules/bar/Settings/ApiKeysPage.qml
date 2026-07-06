import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "SettingsPalette.js" as SettingsPalette
import "ApiKeysProviders.js" as Providers
import "../../../Widgets"
import "../../../Services/core" as Core

// ─────────────────────────────────────────────────────────────────────────
// API Keys — UI for configuring the AI reranker used by SmartComplete
// (Fcitx5 keyboard addon).
//
// Writes ~/.config/linuxcomplete/api_keys.json with chmod 600.
// SmartComplete picks up the file on fcitx5 restart (we auto-restart).
//
// This file owns:
//   - the form state (selectedProviderId, apiKey, model, apiBase, etc.)
//   - the persistence (TextDataStore) and the test/save processes
//   - the outer layout
// The provider card, local panel and remote panel are separate files.
// ─────────────────────────────────────────────────────────────────────────
Item {
    id: page

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string keyFilePath: homeDir + "/.config/linuxcomplete/api_keys.json"

    readonly property var providers: Providers.providers

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

    readonly property var currentProvider: Providers.byId(selectedProviderId)

    function selectProvider(id) {
        selectedProviderId = id;
        const p = Providers.byId(id);
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
                        font.family: Theme.fontFamily
                        text: "API Keys"
                        color: SettingsPalette.text
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Text {
                        font.family: Theme.fontFamily
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
                font.family: Theme.fontFamily
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
                    delegate: ApiKeysProviderCard {
                        required property var modelData
                        providerData: modelData
                        selected: page.selectedProviderId === modelData.id
                        onSelectRequested: page.selectProvider(modelData.id)
                    }
                }
            }

            // ── LOCAL ONLY info panel (shown when "Local only" selected) ──
            ApiKeysLocalPanel {
                visible: page.selectedProviderId === "local"
                saveStatus: page.saveStatus
                saveMessage: page.saveMessage
                onActivateRequested: page.saveConfig()
            }

            // ── Provider details panel (hidden for Local only) ─────────────
            ApiKeysRemotePanel {
                visible: page.selectedProviderId !== "local"
                Layout.fillWidth: true

                selectedProviderId: page.selectedProviderId
                currentProvider: page.currentProvider

                apiBase: page.apiBase
                modelValue: page.model
                apiKey: page.apiKey
                keyVisible: page.keyVisible

                testStatus: page.testStatus
                testMessage: page.testMessage
                saveStatus: page.saveStatus
                saveMessage: page.saveMessage

                onApiBaseEdited: (v) => { page.apiBase = v; }
                onModelEdited: (v) => { page.model = v; }
                onApiKeyEdited: (v) => { page.apiKey = v; }
                onKeyVisibilityToggled: page.keyVisible = !page.keyVisible
                onTestRequested: page.testConnection()
                onSaveRequested: page.saveConfig()
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
                        font.family: Theme.fontFamily
                        text: "ℹ  How it works"
                        color: SettingsPalette.subtext
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        font.family: Theme.fontFamily
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
