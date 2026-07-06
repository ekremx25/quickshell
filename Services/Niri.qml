pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "./core/Log.js" as Log

// Integration with the Niri compositor's workspace event stream.
// If the event stream closes unexpectedly (compositor restart,
// IPC failure, etc.) the service waits 2 seconds and reconnects automatically.
Singleton {
    // Setting _reconnect to false stops the process; setting it back to true
    // re-evaluates the binding and restarts the process.
    property bool _reconnect: true

    property ListModel workspaces: ListModel {}

    // ------------------------------------------------------------------
    // Refresh the workspace list
    // ------------------------------------------------------------------
    function updateWorkspaces(workspacesEvent) {
        const workspaceList = workspacesEvent.workspaces;

        // Sort by index
        workspaceList.sort((a, b) => a.idx - b.idx);

        workspaces.clear();
        for (const workspace of workspaceList) {
            workspaces.append({
                // Cast ID to string to avoid JS number precision loss.
                wsId: String(workspace.id),
                idx: workspace.idx,
                isActive: workspace.is_active,
                // Fall back to empty string when name is null — avoids ListModel crashes.
                name: workspace.name || "",
                output: workspace.output || ""
            });
        }
    }

    // ------------------------------------------------------------------
    // Update the active workspace
    // ------------------------------------------------------------------
    function activateWorkspace(workspacesEvent) {
        // String comparison — safe against numeric-conversion surprises.
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
    // Reconnect timer
    // When the process exits, waits 2 seconds and sets _reconnect = true,
    // which retriggers the binding and restarts the process.
    // ------------------------------------------------------------------
    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (CompositorService.isNiri) {
                Log.info("Niri", "Reconnecting to event stream...");
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
                    Log.warn("Niri", "Event parse error: " + e);
                }
            }
        }

        // On an unexpected exit (crash, IPC drop, restart), reconnect after a
        // short delay.
        onExited: exitCode => {
            if (CompositorService.isNiri) {
                Log.warn("Niri", "Event stream closed (code: " + exitCode + "), reconnecting in 2s");
                _reconnect = false;
                reconnectTimer.restart();
            }
        }
    }
}
