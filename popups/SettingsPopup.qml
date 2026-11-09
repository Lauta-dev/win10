import QtQuick
import Quickshell
import "../state"

import "../components"
import "../components/settings"

PopupShell {
    id: root

    flag: TaskbarState.activePopup === "settings"
    onDismissed: TaskbarState.activePopup = ""
    panelW: Math.min(screen.width - 2 * root.surfaceMargin, root.maxPanelW)
    panelH: Math.min(screen.height - Config.taskbarHeight - 2 * root.surfaceMargin, root.maxPanelH)
    drawerSections: [
        { header: "", titles: ["Apariencia"], icons: [Icons.palette] },
        { header: "", titles: ["Monitores"], icons: [Icons.monitor] }
    ]
    drawerCompact: true
    onTabSelected: index => root.activeTab = index

    // ── Variables primero (sin magic strings abajo) ──────
    // activeTab vive en el shell (heredado); arranca en 0.
    readonly property int surfaceMargin: 24
    readonly property int maxPanelW: 1000
    readonly property int maxPanelH: 620

    // Monitores (lo lee SettingsTabMonitors vía root.root.monitors)
    readonly property var monitors: MonitorState._monitors

    // ── Estado de tabs (activeTab heredado del shell) ───────────────
    property bool _monLoaded: false

    onIsOpenChanged: {
        if (isOpen) {
            activeTab = TaskbarState.settingsTab
            TaskbarState.settingsTab = 0
            if (activeTab === 0 && !WallpaperState._wpLoaded)  { if (WallpaperState.wallpaperDir !== "") WallpaperState.wallpapersProc.load(WallpaperState.wallpaperDir); WallpaperState._wpLoaded = true }
            if (activeTab === 1 && !_monLoaded) { MonitorState.monitorsProc.load(); _monLoaded = true }
        } else {
            WallpaperState._wpLoaded = false
            resetTabTimer.start()
        }
    }
    Timer {
        id: resetTabTimer
        interval: 220
        repeat: false
        onTriggered: activeTab = 0
    }

    onActiveTabChanged: {
        if (!isOpen) return
        if (activeTab === 0 && !WallpaperState._wpLoaded)  { if (WallpaperState.wallpaperDir !== "") WallpaperState.wallpapersProc.load(WallpaperState.wallpaperDir); WallpaperState._wpLoaded = true }
        else if (activeTab !== 0) { WallpaperState._wpLoaded = false }
        if (activeTab === 1 && !_monLoaded) { MonitorState.monitorsProc.load(); _monLoaded = true }
    }

    // ── Páginas (hijas directas → slot del shell) ──

    TabTransition { index: 0; activeTab: root.activeTab
        SettingsTabAppearance { anchors.fill: parent; clip: true }
    }

    TabTransition { index: 1; activeTab: root.activeTab
        SettingsTabMonitors { anchors.fill: parent; clip: true; root: root }
    }
}
