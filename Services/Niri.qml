pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    property ListModel workspaces: ListModel {}

    function updateWorkspaces(workspacesEvent) {
        const workspaceList = workspacesEvent.workspaces;
        
        // 1. 排序
        workspaceList.sort((a, b) => a.idx - b.idx);
        
        workspaces.clear();
        for (const workspace of workspaceList) {
            workspaces.append({
                // 【修复1】 强制转为字符串，防止 JS 数字精度丢失导致 ID 错乱
                wsId: String(workspace.id), 
                
                idx: workspace.idx,
                isActive: workspace.is_active,
                
                // 【修复2】 这里的 || "" 是关键！
                // 如果 name 是 null，就用空字符串代替，防止 ListModel 崩溃
                name: workspace.name || "", 
                output: workspace.output || ""
            });
        }
    }

    function activateWorkspace(workspacesEvent) {
        // ID 也要转成字符串来对比
        const activeId = String(workspacesEvent.id);

        for (let i = 0; i < workspaces.count; i++) {
            const item = workspaces.get(i);
            
            // 字符串对比，绝对安全
            const isNowActive = (item.wsId === activeId);

            if (item.isActive !== isNowActive) {
                workspaces.setProperty(i, "isActive", isNowActive);
            }
        }
    }

    Process {
        id: niriEvents
        running: CompositorService.isNiri
        // 监听事件
        command: ["niri", "msg", "--json", "event-stream"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const event = JSON.parse(data.trim());
                    
                    if (event.WorkspacesChanged) {
                        updateWorkspaces(event.WorkspacesChanged);
                    } 
                    else if (event.WorkspaceActivated) {
                        activateWorkspace(event.WorkspaceActivated);
                    }
                } catch (e) {
                    console.log("Niri Event Error:", e);
                }
            }
        }
    }
}
