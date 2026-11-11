pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

import Quickshell.Services.Pipewire
Singleton {
    // ── Tema listo (esperar antes de mostrar UI) ──────────────────────────
    property bool ready: false

    // ── Tooltip de ventanas ───────────────────────────────────────────────
    property bool   showTooltip: false
    property real   tooltipX:    0
    property string tooltipText: ""

    function showTip(text, x) {
        tooltipHideTimer.stop()
        tooltipText = text
        tooltipX    = x
        showTooltip = true
    }
    function hideTip() {
        tooltipHideTimer.restart()
    }

    Timer {
        id: tooltipHideTimer
        interval: 200
        repeat: false
        onTriggered: {
            TaskbarState.showTooltip = false
        }
    }

    // ── Slider inline de volumen: se revela con hover (espacio reservado,
    // sin cambios de layout). Cierra con delay al salir.
    property bool volumeSliderOpen: false
    function requestVolumeSlider(open) {
        if (open) { volumeSliderTimer.stop(); volumeSliderOpen = true }
        else volumeSliderTimer.restart()
    }
    Timer {
        id: volumeSliderTimer
        interval: 250
        repeat: false
        onTriggered: TaskbarState.volumeSliderOpen = false
    }

    // ── Superficie global de paneles (PanelPopupHost) ─────────────────────
    // Un solo slot para los paneles grandes: exclusividad last-wins — al
    // abrir uno, el anterior se limpia al instante (sin wipe de salida).
    // Cambiar entre paneles con la superficie abierta cambia el contenido
    // en seco (sin re-animar). "" | "launcher" | "jumplist" | "music" | "controlcenter" | "mpd"
    property string panel: ""
    function openPanel(name: string)  { panel = name }
    function closePanel(name) {
        if (name === undefined || name === "" || panel === name) panel = ""
    }

    // ── Lanzador único (AppMenu / Clipboard por modo) ──────────────
    // Cambiar de modo con el popup visible solo actualiza contenido.
    property string launcherMode: "app"   // "app" | "clip"
    readonly property bool showLauncher: panel === "launcher"
    readonly property bool appOpen:  showLauncher && launcherMode === "app"
    readonly property bool clipOpen: showLauncher && launcherMode === "clip"
    function _showLauncher(mode) { launcherMode = mode; openPanel("launcher") }
    function _hideLauncher()     { closePanel("launcher") }

    // ── Notes Sidebar ────────────────────────────────────────────────────
    property bool showNotesSidebar: false

    // ── Debug ─────────────────────────────────────────────────────────────
    property bool showDebugOutput: false


    // ── Popup activo en el tray ───────────────────────────────────────────
    property string activePopup: ""
    property real   popupX:      0
    property int    settingsTab: 0

    // ── Hub (Música/Calc/Claves): tab activo ────────────────
    property int hubTab: 0
    readonly property int hubTabMpd: 0
    readonly property int hubTabCalc: 1


    // ── JumpList: popup único compartido por todos los ítems de la tasklist ─
    // activeJumpList conserva el appId al cerrar para que el contenido no
    // desaparezca durante el wipe de salida (se reemplaza al abrir otra app).
    property string activeJumpList: ""
    readonly property bool jumpListOpen: panel === "jumplist"
    property real   jumpListX: 0
    property bool   jumpListByHover: false
    property bool   jumpListPanelHovered: false
    property string jumpListHoveredApp: ""

    function openJumpList(appId, x, byHover) {
        jumpListX = x
        if (jumpListOpen && activeJumpList === appId) return
        jumpListByHover = byHover
        activeJumpList = appId
        openPanel("jumplist")
    }

    function closeJumpList() {
        closePanel("jumplist")
        jumpListHoveredApp = ""
        jumpListPanelHovered = false
    }

    // Gracia al salir del botón/panel: cierra solo si el popup se abrió por
    // hover y el mouse no terminó en el botón dueño ni en el panel.
    function notifyJumpListHover() {
        if (jumpListPanelHovered || jumpListHoveredApp === activeJumpList)
            jumpListCloseTimer.stop()
        else if (jumpListOpen && jumpListByHover)
            jumpListCloseTimer.restart()
    }

    Timer {
        id: jumpListCloseTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (TaskbarState.jumpListOpen && TaskbarState.jumpListByHover
                    && !TaskbarState.jumpListPanelHovered
                    && TaskbarState.jumpListHoveredApp !== TaskbarState.activeJumpList)
                TaskbarState.closeJumpList()
        }
    }

    // ── Apps pineadas ─────────────────────────────────────────────────────
    property var pinnedApps: []


    // Drag & drop de pines en la TaskList (suprime hover/clicks durante el arrastre)
    property bool taskDragActive: false
    property int   dragSourceIndex: -1
    property string dragSourceAppId: ""
    property int   dragTargetIndex: -1
    property bool  dragJustEnded: false

    // Pin que tiene el click izquierdo presionado (origen de un posible
    // reorden). Se usa para iniciar el drag solo al cruzar hacia otro botón
    // pin, evitando false-positives en clics normales.
    property string pressedPinAppId: ""
    property int   pressedPinIndex: -1

    function isPinned(appId) {
        for (var i = 0; i < pinnedApps.length; i++)
            if (pinnedApps[i] === appId) return true
        return false
    }

    function pin(appId) {
        if (isPinned(appId)) return
        var arr = pinnedApps.slice()
        arr.push(appId)
        pinnedApps = arr
        _savePins()
    }

    function unpin(appId) {
        var arr = pinnedApps.filter(function(a){ return a !== appId })
        pinnedApps = arr
        _savePins()
    }

    function togglePin(appId) {
        if (isPinned(appId)) unpin(appId)
        else pin(appId)
    }

    // Reordena un pin: from/to son índices finales dentro de pinnedApps.
    function movePin(from, to) {
        if (from === to) return
        if (from < 0 || from >= pinnedApps.length) return
        if (to < 0 || to >= pinnedApps.length) return
        var arr = pinnedApps.slice()
        var app = arr.splice(from, 1)[0]
        arr.splice(to, 0, app)
        pinnedApps = arr
        _savePins()
    }

    // ── Ciclo de arrastre de un pin ──────────────────────────────────────
    function startDrag(appId, sourceIndex, targetIndex) {
        if (targetIndex === undefined) targetIndex = sourceIndex
        dragSourceAppId = appId
        dragSourceIndex = sourceIndex
        dragTargetIndex = targetIndex
        taskDragActive = true
    }

    function updateDragTarget(index) {
        if (!taskDragActive) return
        dragTargetIndex = index
    }

    function endDrag() {
        if (!taskDragActive) return
        if (dragSourceIndex >= 0 && dragTargetIndex >= 0
                && dragSourceIndex !== dragTargetIndex) {
            movePin(dragSourceIndex, dragTargetIndex)
        }
        dragJustEnded = true
        dragEndTimer.restart()
    }

    // Cancela un drag en curso sin aplicar reorden.
    function cancelDrag() {
        dragSourceIndex = -1
        dragSourceAppId = ""
        dragTargetIndex = -1
        taskDragActive = false
        dragJustEnded = true
        dragEndTimer.restart()
    }

    Timer {
        id: dragEndTimer
        interval: 60
        repeat: false
        onTriggered: {
            dragSourceIndex = -1
            dragSourceAppId = ""
            dragTargetIndex = -1
            taskDragActive = false
            dragJustEnded = false
            pressedPinAppId = ""
            pressedPinIndex = -1
        }
    }

    // ── Pin fuzzy (para el app menu) ────────────────────────────────────
    // El id .desktop puede diferir del appId Wayland; se usa el mismo
    // match fuzzy del agrupado para no duplicar pines.
    function isPinnedFuzzy(appId) {
        if (!appId || appId === "") return false
        if (isPinned(appId)) return true
        for (var i = 0; i < pinnedApps.length; i++)
            if (AppLaunchState._matches(pinnedApps[i], appId)) return true
        return false
    }

    function _pinnedMatch(appId) {
        for (var i = 0; i < pinnedApps.length; i++)
            if (AppLaunchState._matches(pinnedApps[i], appId)) return pinnedApps[i]
        return ""
    }

    function togglePinSmart(appId) {
        if (!appId || appId === "") return
        if (isPinned(appId)) { unpin(appId); return }
        var m = _pinnedMatch(appId)
        if (m !== "") unpin(m)
        else pin(appId)
    }

    function _savePins() {
        SettingsState.pinnedApps = pinnedApps
        SettingsState.markDirty()
    }

    // ── Control Center: panel del slot global (ver PanelPopupHost) ────────
    readonly property bool showControlCenterNew: panel === "controlcenter"

    // ── Modo oscuro / nocturno ────────────────────────────────────────────
    property bool   darkMode:    false
    property bool   nightMode:   false
    onNightModeChanged: SettingsState.markDirty()

    // Proceso de modo nocturno (gammastep/redshift). Vive en el singleton
    // para que la UI no acceda al sistema directamente.
    Process {
        id: nightModeProc
        property bool starting: TaskbarState.nightMode
        command: starting
            ? ["sh", "-c", "pkill -x gammastep;pkill -x redshift;(gammastep -O 3500 &) 2>/dev/null || (redshift -O 3500 &) 2>/dev/null || true"]
            : ["sh", "-c", "pkill -x gammastep;pkill -x redshift;(gammastep -x &) 2>/dev/null || (redshift -x &) 2>/dev/null || true"]
        running: false
    }
    function applyNightMode() {
        nightModeProc.running = true
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ── MÚSICA — MPRIS nativo + Timer polling para posición ──────────────
    // ═══════════════════════════════════════════════════════════════════════

    // Override manual: cuando el usuario elige un player específico
    

    // ── Controles de audio — vía Pipewire nativo ──────────────────────────
    function applyDarkMode(dark) {
        darkMode = dark

        var mode = dark ? "dark" : "light"
        if (ThemeState.colorTheme === "matugen" && WallpaperState.wallpaper) {
            var script = Qt.resolvedUrl("../bin/matugen-apply").toString().replace("file://", "")
            var wp = WallpaperState.wallpaper.replace(/'/g, "'\\''")
            _darkModeProc._cmd = "'" + script + "' '" + wp + "' --type " + WallpaperState.matugenSchemeType + " --mode " + mode
        } else {
            // Sin matugen: seguir la variante de la familia (auto) para gtk e iconos.
            // Qt va por plataforma gtk3: lo cubre gtk-apply, sin qt5ct/qt6ct.
            var gtkScript = Qt.resolvedUrl("../bin/gtk-apply").toString().replace("file://", "")
            _darkModeProc._cmd = "'" + gtkScript + "' --gtk auto --icons auto --mode " + mode
        }
        _darkModeProc.running = false
        _darkModeProc.running = true
    }

    Process {
        id: _darkModeProc
        property string _cmd: ""
        command: ["sh", "-c", _cmd]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                // Solo aceptar el marcador explícito: el resto del stdout es log
                var t = line.trim()
                if (t.indexOf("__GTK_THEME__=") === 0) ThemeState.gtkTheme = t.substring(14)
            }
        }
    }

    // ── OSD único (vol/brillo/power por modo): cambiar de modo con el OSD
    // visible solo actualiza bindings, sin recrear ventana ni reanimar.
    property string osdMode: "vol"   // "vol" | "bright" | "power"
    property bool showOsd: false
    // En alto durante un cambio de modo: el slider congela sus animaciones
    // para que el salto discreto pinte directo. Se prende ANTES de cambiar
    // osdMode (orden de asignación en _showOsd), así no depende del orden
    // de evaluación de bindings en el frame del cambio.
    property bool osdSwitching: false
    function _showOsd(mode) {
      // También al (re)abrir: el highlight de power debe pintar directo
      // en su posición inicial, sin deslizar desde la anterior.
      if (!showOsd || osdMode !== mode) {
        osdSwitching = true
        osdSwitchTimer.restart()
      }
      osdMode = mode
      showOsd = true
      osdHideTimer.restart()
    }
    // El powermenu necesita más tiempo de lectura que un slider.
    function togglePowerMenu(): bool {
      if (showOsd && osdMode === "power") showOsd = false
      else _showOsd("power")
      return showOsd
    }

    Timer {
        id: osdHideTimer
        interval: osdMode === "power" ? 4000 : 1500
        repeat:   false
        onTriggered: showOsd = false
    }
    property alias osdHideTimer: osdHideTimer

    Timer {
        id: osdSwitchTimer
        interval: 150
        repeat:   false
        onTriggered: osdSwitching = false
    }

    // ── Acciones power/shot persistentes: los Process viven acá (singleton)
    // y NO en el popup, porque el OSD se descarga 250ms tras cerrar y
    // mataría a slurp en plena selección de región.
    Process { id: logoutProc; command: ["labwc", "-e"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: poweroffProc; command: ["systemctl", "poweroff"] }
    function runPower(action): string {
        if (action === "logout") logoutProc.running = true
        else if (action === "reboot") rebootProc.running = true
        else if (action === "off") poweroffProc.running = true
        else return "unknown action"
        return action
    }

    // Abre un archivo o URL con xdg-open, centralizando el acceso al sistema.
    function openExternal(target) {
        if (!target || target === "") return
        Quickshell.execDetached(["xdg-open", target])
    }
}
