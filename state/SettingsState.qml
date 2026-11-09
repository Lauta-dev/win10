// SettingsState.qml — Coordinador central de persistencia unificada
// La UI nunca escribe archivos — SettingsState es el único punto de I/O.
// ThemeState y WallpaperState son los service providers; SettingsState
// hidrata sus propiedades desde el JSON y las serializa al guardar.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {

    // ── Apps pineadas en la taskbar ────────────────────────────────
    property var pinnedApps: []

    // ── Apariencia — color y tema ──────────────────────────────────
    property bool   _jsonLoaded: false
    property int    taskbarHeight: 40

    // ── Notas — ancho del sidebar ────────────────────────────────
    property int  notesPanelW:    500
    property int  notesFontSize:  16

    property string radiusPreset: "medium"
    property var    radiusCustom: ({ taskbar: "medium", popups: "medium", buttons: "medium" })

    // ── Resoluciones preferidas por output ─────────────────────────
    property var outputModes: ({ "eDP-1": "1366x768", "HDMI-A-1": "1360x768" })

    // ── Apps recientes (máx 5) ────────────────────────────────────
    property var recentApps: []

    function addRecentApp(exec, name) {
        var arr = recentApps.slice()
        for (var i = arr.length - 1; i >= 0; i--) {
            if (arr[i].exec === exec) { arr.splice(i, 1); break }
        }
        arr.unshift({ exec: exec, name: name })
        if (arr.length > 5) arr = arr.slice(0, 5)
        recentApps = arr
        markDirty()
    }

    // ── Persistencia ──────────────────────────────────────────────
    function markDirty() { saveTimer.restart() }

    signal loaded()

    // ── FileView — I/O nativo ─────────────────────────────────────
    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.config/qs-settings.json"
        atomicWrites: true

        onLoaded: {
            var raw = store.text()
            if (raw === "") { _finishInit(); return }
            try {
                var obj = JSON.parse(raw)
                if (obj.darkMode !== undefined) {
                    TaskbarState.darkMode = obj.darkMode
                    ThemeState.darkModePersisted = obj.darkMode
                }
                if (obj.nightMode !== undefined) TaskbarState.nightMode = obj.nightMode
                if (obj.wallpaper)         WallpaperState.wallpaper     = obj.wallpaper
                // Pines de la taskbar (legacy: los perfiles guardaban acá
                // los pines del perfil activo).
                if (Array.isArray(obj.pinnedApps)) pinnedApps = obj.pinnedApps.slice()
                if (obj.wallpaperDir)          WallpaperState.wallpaperDir = obj.wallpaperDir
                // Legacy: la versión multi-carpeta guardaba un array.
                else if (Array.isArray(obj.wallpaperDirs) && obj.wallpaperDirs.length > 0)
                    WallpaperState.wallpaperDir = obj.wallpaperDirs[0]
                if (obj.gtkTheme)          ThemeState.gtkTheme  = obj.gtkTheme
                if (obj.iconTheme)         ThemeState.iconTheme = obj.iconTheme
                if (obj.outputModes && typeof obj.outputModes === "object")
                    outputModes = obj.outputModes
                if (obj.matugenSchemeType) WallpaperState.matugenSchemeType = obj.matugenSchemeType
                if (obj.accentDark  !== undefined) ThemeState.accentDark  = obj.accentDark  || ""
                if (obj.accentLight !== undefined) ThemeState.accentLight = obj.accentLight || ""
                // Legacy "default" = ChromeOS, el default actual.
                if (obj.colorTheme)        ThemeState.colorTheme = obj.colorTheme === "default" ? "chromeos" : obj.colorTheme
                if (obj.taskbarHeight)     taskbarHeight  = obj.taskbarHeight
                if (obj.notesPanelW !== undefined && obj.notesPanelW > 0) notesPanelW = obj.notesPanelW
                if (obj.notesFontSize !== undefined && obj.notesFontSize >= 10 && obj.notesFontSize <= 28) notesFontSize = obj.notesFontSize
                if (obj.iconMap && typeof obj.iconMap === "object")
                    ThemeState.iconMap = obj.iconMap
                if (obj.radiusPreset && ["none","small","medium","large","full"].indexOf(obj.radiusPreset) >= 0)
                    radiusPreset = obj.radiusPreset
                if (obj.radiusCustom && typeof obj.radiusCustom === "object")
                    radiusCustom = obj.radiusCustom
                if (Array.isArray(obj.recentApps)) recentApps = obj.recentApps.slice(0, 5)
            } catch(e) {}
            _finishInit()
        }

        onLoadFailed: {
            _finishInit()
        }
    }

    function _finishInit() {
        // Síncrono y barato primero: la barra pinta ya con datos en memoria
        // (pinnedApps/darkMode se hidrataron arriba). Solo swaybg va un tick
        // después (no sobrevive al logout); gtk/iconos persisten en disco y
        // night se reaplica al togglear. iconMap va en idle (solo 1ra vez).
        TaskbarState.pinnedApps = pinnedApps.slice()
        ThemeState._themeLoaded = true
        SettingsState.loaded()
        _jsonLoaded = true
        TaskbarState.ready = true
        Qt.callLater(function() {
            if (WallpaperState.wallpaper && WallpaperState.wallpaper !== "")
                WallpaperState.wallpaperRestoreProc.restore(WallpaperState.wallpaper)
            Config.warmupPins(pinnedApps)
            iconIdleTimer.restart()
        })
    }

    // iconMap (binario resolve-icons, solo 1ra vez): fuera del arranque.
    Timer {
        id: iconIdleTimer
        interval: 2000; repeat: false
        onTriggered: { if (Object.keys(ThemeState.iconMap).length === 0) ThemeState.iconMapProc.run() }
    }

    // ── Timer debounce — escribe todo el estado en un solo JSON ────
    Timer {
        id: saveTimer
        interval: 300; repeat: false
        onTriggered: {
            var data = JSON.stringify({
                darkMode:       TaskbarState.darkMode,
                nightMode:      TaskbarState.nightMode,
                pinnedApps:     pinnedApps,
                wallpaper:      WallpaperState.wallpaper,
                wallpaperDir:   WallpaperState.wallpaperDir,
                gtkTheme:       ThemeState.gtkTheme,
                iconTheme:      ThemeState.iconTheme,
                outputModes:    outputModes,
                matugenSchemeType: WallpaperState.matugenSchemeType,
                accentDark:     ThemeState.accentDark,
                accentLight:    ThemeState.accentLight,
                colorTheme:     ThemeState.colorTheme,
                taskbarHeight:      taskbarHeight,
                notesPanelW:        notesPanelW,
                notesFontSize:      notesFontSize,
                iconMap:            ThemeState.iconMap,
                radiusPreset:       radiusPreset,
                radiusCustom:       radiusCustom,
                recentApps:         recentApps
            })
            store.setText(data)
        }
    }

    // wallpaperRestoreProc movido a WallpaperState
}
