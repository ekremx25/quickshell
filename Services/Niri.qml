pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "./core/Log.js" as Log

// Niri compositor workspace event stream entegrasyonu.
// Event stream beklenmedik şekilde kapanırsa (compositor yeniden başlama,
// IPC hatası vb.) 2 saniye bekleyip otomatik yeniden bağlanır.
Singleton {
    // _reconnect: false yapılırsa process durur, timer true'ya getirince
    // binding yeniden değerlendirilerek process otomatik başlar.
    property bool _reconnect: true

    property ListModel workspaces: ListModel {}

    // ------------------------------------------------------------------
    // Workspace listesini güncelle
    // ------------------------------------------------------------------
    function updateWorkspaces(workspacesEvent) {
        const workspaceList = workspacesEvent.workspaces;

        // İndekse göre sırala
        workspaceList.sort((a, b) => a.idx - b.idx);

        workspaces.clear();
        for (const workspace of workspaceList) {
            workspaces.append({
                // ID'yi string'e çevir: JS sayı hassasiyeti kaybını önler
                wsId: String(workspace.id),
                idx: workspace.idx,
                isActive: workspace.is_active,
                // name null ise boş string kullan: ListModel çökmesini önler
                name: workspace.name || "",
                output: workspace.output || ""
            });
        }
    }

    // ------------------------------------------------------------------
    // Aktif workspace'i güncelle
    // ------------------------------------------------------------------
    function activateWorkspace(workspacesEvent) {
        // String karşılaştırması: sayı dönüşüm hatalarına karşı güvenli
        const activeId = String(workspacesEvent.id);

        for (let i = 0; i < workspaces.count; i++) {
            const item = workspaces.get(i);
            const isNowActive = (item.wsId === activeId);

            if (item.isActive !== isNowActive) {
                workspaces.setProperty(i, "isActive", isNowActive);
            }
        }
    }

    // ------------------------------------------------------------------
    // Yeniden bağlanma zamanlayıcısı
    // Process kapandığında 2 saniye bekleyip _reconnect = true yapar;
    // bu binding'i tetikleyerek process'i yeniden başlatır.
    // ------------------------------------------------------------------
    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (CompositorService.isNiri) {
                Log.info("Niri", "Event stream'e yeniden bağlanılıyor...");
                _reconnect = true;
            }
        }
    }

    // ------------------------------------------------------------------
    // Niri event stream process
    // ------------------------------------------------------------------
    Process {
        id: niriEvents
        running: CompositorService.isNiri && _reconnect
        command: ["niri", "msg", "--json", "event-stream"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim());

                    if (event.WorkspacesChanged) {
                        updateWorkspaces(event.WorkspacesChanged);
                    } else if (event.WorkspaceActivated) {
                        activateWorkspace(event.WorkspaceActivated);
                    }
                } catch (e) {
                    Log.warn("Niri", "Event parse hatası: " + e);
                }
            }
        }

        // Beklenmedik çıkışlarda (crash, IPC kopması, yeniden başlama)
        // kısa bir bekleme süresi sonra otomatik yeniden bağlan.
        onExited: exitCode => {
            if (CompositorService.isNiri) {
                Log.warn("Niri", "Event stream kapandı (kod: " + exitCode + "), 2s sonra yeniden bağlanılıyor");
                _reconnect = false;
                reconnectTimer.restart();
            }
        }
    }
}
