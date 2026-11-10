// WallpaperState.qml — Fondos de pantalla, swaybg
// Service provider: la UI consume estas propiedades y llama funciones.
// La persistencia la maneja SettingsState (FileView + saveTimer).
//
// Galería: sin procesos. El listado lo hace FolderListModel (Qt nativo)
// en SettingsTabAppearance, con watchChanges: true (QFileSystemWatcher).
// acá quedan sólo los procesos de wallpaper (swaybg + matugen).
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {

    property string wallpaper:      ""
    property string wallpaperDir:   Quickshell.env("HOME") + "/Imágenes/wallpaper"
    property string matugenSchemeType: "scheme-tonal-spot"

    // ── Exposición de procesos hijos ─────────────────────────────
    property alias wallpaperRestoreProc: wallpaperRestoreProc
    property alias wallpaperProc:        wallpaperProc

    // ── Restaurar wallpaper al inicio ──────────────────────────────
    Process {
        id: wallpaperRestoreProc
        property string _cmd: "true"
        command: ["sh", "-c", _cmd]
        running: false
        function restore(path) {
            _cmd = "pkill swaybg 2>/dev/null; swaybg -i '" + path.replace(/'/g, "'\\''") + "' -m fill >/dev/null 2>&1 &"
            running = true
        }
    }

    // ── Proceso unificado de wallpaper — swaybg + matugen ────────────
    Process {
        id: wallpaperProc
        property string _cmd: "true"
        command: ["sh", "-c", wallpaperProc._cmd]
        running: false
        function apply(path) {
            var esc = path.replace(/'/g, "'\\''")
            var matugenCmd = ""
            if (ThemeState.colorTheme === "matugen") {
                var script = Qt.resolvedUrl("../bin/matugen-apply").toString().replace("file://", "")
                var themeMode = TaskbarState.darkMode ? "dark" : "light"
                matugenCmd = "'" + script + "' '" + esc + "' --type " + WallpaperState.matugenSchemeType + " --mode " + themeMode + " & "
            }
            _cmd = matugenCmd + "pkill swaybg 2>/dev/null; swaybg -i '" + esc + "' -m fill >/dev/null 2>&1 &"
            running = true
            WallpaperState.wallpaper     = path
            SettingsState.markDirty()
        }
    }

    // ── Esquema de matugen ───────────────────────────────────────

    readonly property var schemeTypes: [
        { id: "scheme-tonal-spot",    label: "Tonal Spot"    },
        { id: "scheme-content",       label: "Content"       },
        { id: "scheme-expressive",    label: "Expressive"    },
        { id: "scheme-fidelity",      label: "Fidelity"      },
        { id: "scheme-fruit-salad",   label: "Fruit Salad"   },
        { id: "scheme-monochrome",    label: "Monochrome"    },
        { id: "scheme-neutral",       label: "Neutral"       },
        { id: "scheme-rainbow",       label: "Rainbow"       },
        { id: "scheme-vibrant",       label: "Vibrant"       },
    ]

    function schemeTypeIndex(id) {
        for (var i = 0; i < WallpaperState.schemeTypes.length; i++)
            if (WallpaperState.schemeTypes[i].id === id) return i
        return 0
    }

    // Dirigir la galería: fijar el directorio (el modelo del tab lo lista).
    function saveDir(dir) {
        var clean = (dir || "").trim()
        wallpaperDir = clean
        SettingsState.markDirty()
    }
}
