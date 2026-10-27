import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../Widgets"
import "../../Services" as S

PanelWindow {
    PopupEntrance {}
    id: root

    property string sourceMode: "local"
    property int selectedIndex: 0
    readonly property var sourceItems: sourceMode === "wallhaven"
        ? S.WallpaperDeckService.wallhavenItems
        : sourceMode === "favorites"
            ? S.WallpaperDeckService.localItems.filter(function(item) {
                return S.WallpaperDeckService.isFavorite(item.id);
            }).concat(S.WallpaperDeckService.favoriteWallhavenItems)
            : S.WallpaperDeckService.localItems
    readonly property var selectedItem: sourceItems.length > 0 && selectedIndex >= 0 && selectedIndex < sourceItems.length
        ? sourceItems[selectedIndex]
        : null
    readonly property color accent: SettingsPalette.readableAccent(Theme.primary)

    visible: false
    color: "transparent"
    implicitWidth: Math.min(1440, Math.max(900, screen ? screen.width * 0.82 : 1200))
    implicitHeight: Math.min(860, Math.max(620, screen ? screen.height * 0.82 : 760))
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:wallpaper-deck"

    onVisibleChanged: if (visible) root.prepareOpen()
    Component.onCompleted: S.WallpaperDeckService.deckWindow = root
    Component.onDestruction: {
        if (S.WallpaperDeckService.deckWindow === root)
            S.WallpaperDeckService.deckWindow = null;
    }

    function prepareOpen() {
        root.sourceMode = "local";
        root.selectedIndex = 0;
        S.WallpaperDeckService.reloadLocal();
        Qt.callLater(function() { deckSurface.forceActiveFocus(); });
    }

    function open() {
        if (root.visible) root.prepareOpen();
        else root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    function selectMode(mode) {
        root.sourceMode = mode;
        root.selectedIndex = 0;
        deck.positionViewAtBeginning();
        if (mode === "wallhaven" && S.WallpaperDeckService.wallhavenItems.length === 0)
            S.WallpaperDeckService.searchWallhaven(1);
    }

    function selectRelative(delta) {
        if (!root.sourceItems.length) return;
        root.selectedIndex = Math.max(0, Math.min(root.sourceItems.length - 1, root.selectedIndex + delta));
        deck.positionViewAtIndex(root.selectedIndex, GridView.Contain);
    }

    Connections {
        target: S.WallpaperDeckService
        function onOpenRequested() { root.open(); }
        function onWallpaperApplied(path) { root.close(); }
    }

    IpcHandler {
        target: "wallpaperDeck"
        function toggle(): void { root.visible ? root.close() : root.open(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function favorite(id: string): string {
            S.WallpaperDeckService.toggleFavorite(id);
            return S.WallpaperDeckService.isFavorite(id) ? "favorite" : "not-favorite";
        }
        function favoriteSelected(): string {
            if (!root.selectedItem) return "no-selection";
            S.WallpaperDeckService.toggleFavorite(root.selectedItem);
            return S.WallpaperDeckService.isFavorite(root.selectedItem.id) ? "favorite" : "not-favorite";
        }
        function status(): string {
            return JSON.stringify({
                visible: root.visible,
                source: root.sourceMode,
                query: S.WallpaperDeckService.query,
                submittedQuery: S.WallpaperDeckService.submittedQuery,
                resultQuery: S.WallpaperDeckService.resultQuery,
                selectedIndex: root.selectedIndex,
                localCount: S.WallpaperDeckService.localItems.length,
                wallhavenCount: S.WallpaperDeckService.wallhavenItems.length,
                favoriteCount: S.WallpaperDeckService.favorites.length,
                searchBusy: S.WallpaperDeckService.searchBusy,
                error: S.WallpaperDeckService.errorMessage
            });
        }
        function search(query: string): void {
            root.open();
            S.WallpaperDeckService.query = query;
            root.sourceMode = "wallhaven";
            root.selectedIndex = 0;
            deck.positionViewAtBeginning();
            S.WallpaperDeckService.searchWallhaven(1);
        }
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: root.visible
        onActivated: root.close()
    }
    Shortcut { sequence: "Left"; enabled: root.visible; onActivated: root.selectRelative(-2) }
    Shortcut { sequence: "Right"; enabled: root.visible; onActivated: root.selectRelative(2) }
    Shortcut { sequence: "Up"; enabled: root.visible; onActivated: root.selectRelative(-1) }
    Shortcut { sequence: "Down"; enabled: root.visible; onActivated: root.selectRelative(1) }
    Shortcut {
        sequence: "Return"
        enabled: root.visible && root.selectedItem !== null
        onActivated: S.WallpaperDeckService.applyItem(root.selectedItem)
    }

    Rectangle {
        id: deckSurface
        anchors.fill: parent
        radius: 24
        clip: true
        focus: root.visible
        Keys.onEscapePressed: function(event) {
            event.accepted = true;
            root.close();
        }
        color: Theme.withAlpha(Theme.background, 0.96)
        border.width: 1
        border.color: Theme.withAlpha(Theme.text, 0.14)

        Image {
            id: backdrop
            anchors.fill: parent
            source: root.selectedItem ? root.selectedItem.preview : ""
            fillMode: Image.PreserveAspectCrop
            // Blurred anyway; decoding 4K originals here costs ~33 MB per image.
            sourceSize.width: 960
            asynchronous: true
            cache: false
            opacity: status === Image.Ready ? 0.32 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animMedium } }
            layer.enabled: visible
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: 0.75; saturation: 0.45 }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.withAlpha(Theme.background, 0.72) }
                GradientStop { position: 0.48; color: Theme.withAlpha(Theme.background, 0.50) }
                GradientStop { position: 1.0; color: Theme.withAlpha(Theme.background, 0.94) }
            }
        }

        MouseArea { anchors.fill: parent; onClicked: function(mouse) { mouse.accepted = true; } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Wallpaper Deck"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 25
                        font.bold: true
                    }
                    Text {
                        text: "Wallpaper first. Material You follows."
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Repeater {
                    model: [
                        { id: "local", label: "Local" },
                        { id: "favorites", label: "Favorites" },
                        { id: "wallhaven", label: "Wallhaven" }
                    ]
                    DeckButton {
                        required property var modelData
                        text: modelData.label
                        prominent: root.sourceMode === modelData.id
                        onClicked: root.selectMode(modelData.id)
                    }
                }

                DeckButton { text: "Close"; onClicked: root.close() }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.sourceMode === "wallhaven"
                spacing: 10

                Controls.TextField {
                    id: searchField
                    Layout.fillWidth: true
                    implicitHeight: 42
                    placeholderText: "Search Wallhaven — mountains, cyberpunk, anime…"
                    text: S.WallpaperDeckService.query
                    color: Theme.text
                    placeholderTextColor: Theme.subtext
                    font.family: Theme.fontFamily
                    selectByMouse: true
                    background: Rectangle {
                        color: Theme.withAlpha(Theme.panelSurface, 0.88)
                        radius: 12
                        border.width: searchField.activeFocus ? 2 : 1
                        border.color: searchField.activeFocus ? root.accent : Theme.borderSoft
                    }
                    onTextEdited: S.WallpaperDeckService.query = text
                    onAccepted: S.WallpaperDeckService.searchWallhaven(1)
                }
                DeckButton {
                    text: S.WallpaperDeckService.searchBusy ? "Searching…" : "Search"
                    prominent: true
                    enabled: !S.WallpaperDeckService.searchBusy
                    onClicked: S.WallpaperDeckService.searchWallhaven(1)
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, 520)
                    visible: root.sourceItems.length === 0
                    spacing: 12
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: S.WallpaperDeckService.localBusy || S.WallpaperDeckService.searchBusy ? "󰔟" : "󰸉"
                        color: root.accent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: 42
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: S.WallpaperDeckService.localBusy || S.WallpaperDeckService.searchBusy
                            ? "Loading wallpapers…"
                            : root.sourceMode === "favorites"
                                ? "No favorites yet. Use the heart on any card."
                                : root.sourceMode === "wallhaven"
                                    ? "Search Wallhaven to fill the deck."
                                    : "No supported images in " + S.WallpaperDeckService.wallpaperDir
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                    }
                }

                GridView {
                    id: deck
                    anchors.fill: parent
                    visible: root.sourceItems.length > 0
                    model: root.sourceItems
                    flow: GridView.FlowTopToBottom
                    layoutDirection: Qt.LeftToRight
                    cellWidth: 236
                    cellHeight: Math.max(190, (height - 16) / 2)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: Theme.animMedium
                    leftMargin: 16
                    rightMargin: 16
                    topMargin: 8
                    bottomMargin: 8

                    function loadMoreNearEnd() {
                        if (root.visible && root.sourceMode === "wallhaven"
                                && contentX > originX
                                && contentX + width >= originX + contentWidth - cellWidth
                                && !S.WallpaperDeckService.searchBusy
                                && !S.WallpaperDeckService.errorMessage.length)
                            S.WallpaperDeckService.loadNextPage();
                    }
                    onContentXChanged: loadMoreNearEnd()
                    onMovementEnded: {
                        if (root.visible && root.sourceMode === "wallhaven"
                                && contentX > originX && atXEnd
                                && !S.WallpaperDeckService.errorMessage.length)
                            S.WallpaperDeckService.loadNextPage();
                    }

                    delegate: Item {
                        id: cardSlot
                        required property var modelData
                        required property int index
                        width: deck.cellWidth
                        height: deck.cellHeight

                        Rectangle {
                            id: card
                            anchors.centerIn: parent
                            width: parent.width - 14
                            height: parent.height - 14
                            radius: 16
                            color: Theme.withAlpha(Theme.panelSurface, cardSlot.index === root.selectedIndex ? 0.98 : 0.86)
                            border.width: cardSlot.index === root.selectedIndex ? 2 : 1
                            border.color: cardSlot.index === root.selectedIndex ? root.accent : Theme.borderSoft
                            scale: cardSlot.index === root.selectedIndex ? 1.035 : 1.0
                            z: cardSlot.index === root.selectedIndex ? 2 : 1
                            clip: true
                            Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

                            readonly property color overlayText: Theme.foregroundFor(Theme.background)

                            Image {
                                anchors.fill: parent
                                source: cardSlot.modelData.preview
                                fillMode: Image.PreserveAspectCrop
                                // Decode at card size (with HiDPI headroom), not the full wallpaper.
                                sourceSize.height: 640
                                asynchronous: true
                                cache: cardSlot.modelData.source === "local"
                            }

                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.36; color: "transparent" }
                                    GradientStop { position: 0.70; color: Theme.withAlpha(Theme.background, 0.24) }
                                    GradientStop { position: 1.0; color: Theme.withAlpha(Theme.background, 0.94) }
                                }
                            }

                            Controls.AbstractButton {
                                id: favoriteButton
                                anchors { top: parent.top; right: parent.right; margins: 10 }
                                width: 36; height: 36
                                hoverEnabled: true
                                focusPolicy: Qt.StrongFocus
                                Accessible.name: S.WallpaperDeckService.isFavorite(cardSlot.modelData.id)
                                    ? "Remove " + cardSlot.modelData.name + " from favorites"
                                    : "Add " + cardSlot.modelData.name + " to favorites"
                                onClicked: S.WallpaperDeckService.toggleFavorite(cardSlot.modelData)
                                background: Rectangle {
                                    radius: 18
                                    color: favoriteButton.hovered
                                        ? Theme.withAlpha(Theme.background, 0.94)
                                        : Theme.withAlpha(Theme.background, 0.68)
                                    border.width: favoriteButton.activeFocus ? 2 : 1
                                    border.color: favoriteButton.activeFocus ? root.accent : Theme.withAlpha(card.overlayText, 0.16)
                                }
                                contentItem: Text {
                                    text: S.WallpaperDeckService.isFavorite(cardSlot.modelData.id) ? "♥" : "♡"
                                    color: S.WallpaperDeckService.isFavorite(cardSlot.modelData.id) ? Theme.powerColor : card.overlayText
                                    font.pixelSize: 18
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            ColumnLayout {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
                                spacing: 5
                                Text {
                                    Layout.fillWidth: true
                                    text: cardSlot.modelData.name
                                    color: card.overlayText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideMiddle
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        Layout.fillWidth: true
                                        text: cardSlot.modelData.resolution || (cardSlot.modelData.source === "local" ? "Local" : "Wallhaven")
                                        color: Theme.withAlpha(card.overlayText, 0.72)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        visible: cardSlot.modelData.source === "wallhaven" && cardSlot.modelData.category
                                        text: cardSlot.modelData.category || ""
                                        color: Theme.withAlpha(card.overlayText, 0.72)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Repeater {
                                        model: cardSlot.modelData.colors && cardSlot.modelData.colors.length
                                            ? cardSlot.modelData.colors
                                            : [Theme.launcherColor, Theme.mediaColor, Theme.calendarColor, Theme.weatherColor]
                                        Rectangle {
                                            required property color modelData
                                            Layout.fillWidth: true
                                            height: 6
                                            radius: 3
                                            color: modelData
                                        }
                                    }
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    root.selectedIndex = cardSlot.index;
                                    deck.positionViewAtIndex(cardSlot.index, GridView.Contain);
                                }
                                onDoubleTapped: S.WallpaperDeckService.applyItem(cardSlot.modelData)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: S.WallpaperDeckService.errorMessage.length
                        ? S.WallpaperDeckService.errorMessage
                        : S.WallpaperDeckService.statusMessage
                    color: S.WallpaperDeckService.errorMessage.length ? Theme.powerColor : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                DeckButton {
                    visible: root.sourceMode === "wallhaven" && S.WallpaperDeckService.currentPage < S.WallpaperDeckService.lastPage
                    text: S.WallpaperDeckService.searchBusy ? "Loading…" : "More"
                    enabled: !S.WallpaperDeckService.searchBusy
                    onClicked: S.WallpaperDeckService.loadNextPage()
                }
                DeckButton {
                    text: root.selectedItem && root.selectedItem.source === "wallhaven" ? "Download & Apply" : "Apply wallpaper"
                    prominent: true
                    enabled: root.selectedItem !== null && !S.WallpaperDeckService.applyBusy && !S.WallpaperDeckService.downloadBusy
                    onClicked: S.WallpaperDeckService.applyItem(root.selectedItem)
                }
            }
        }
    }

    component DeckButton: Controls.AbstractButton {
        id: button
        property bool prominent: false
        implicitHeight: 38
        implicitWidth: Math.max(88, contentText.implicitWidth + 28)
        padding: 10
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        background: Rectangle {
            radius: 11
            color: button.prominent
                ? root.accent
                : button.hovered
                    ? Theme.surfaceTintHigh
                    : Theme.withAlpha(Theme.panelSurface, 0.86)
            border.width: button.activeFocus ? 2 : 1
            border.color: button.activeFocus ? Theme.text : button.prominent ? root.accent : Theme.borderSoft
        }
        contentItem: Text {
            id: contentText
            text: button.text
            color: button.prominent ? SettingsPalette.foregroundFor(root.accent) : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.bold: button.prominent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
