// PanelPopupHost.qml — Superficie global única para los paneles grandes
// (Launcher, JumpList, Music, ControlCenter).
//
// Es una instancia de WipePopupShell: hereda wipe, máscara, DismissOverlay
// y keyboardFocus, así que los 4 paneles comparten UNA ventana layer-shell
// y UN overlay de cierre (antes: 4 de cada uno).
//
// TaskbarState.panel guarda el panel activo; exclusividad last-wins: al
// abrir uno, el anterior se limpia al instante. Con la superficie ya
// abierta, cambiar de panel cambia el contenido en seco (sin re-wipe).
//
// Los paneles son componentes que viven adentro (AutoLazyLoader con el
// sticky/unloadDelay propio de cada uno) y declaran la API de vista:
//   viewWidth / viewHeight → tamaño del box (fijo o dinámico)
//   viewX                  → positionX para position "left" (0 si no aplica)
//   viewExclusiveFocus     → teclado exclusivo opcional
//   viewOpen               → proxy de isOpen (para timers/lógica interna)
//
// Los statics por panel van en _CONFIGS. Durante el wipe de salida el
// panel queda "retenido" (_lastPanel, CLOSE_HOLD) para que box/config no
// cambien a mitad de la animación.
import QtQuick
import QtQuick.Window
import "../state"
import "../popups"
import "../taskbar/jumplist"

WipePopupShell {
    id: shell

    // ── Statics por panel ──
    readonly property var _CONFIGS: ({
        "launcher":      { position: "center", sideMargin: 8,  width: 640, height: 520, radius: 16, openMs: 320, closeMs: 240 },
        "jumplist":      { position: "left",   sideMargin: 8,  width: 240, height: 320, radius: Style.popup_radius, openMs: 300, closeMs: 300 },
        "music":         { position: "left",   sideMargin: 8,  width: 396, height: 346, radius: Style.popup_radius, openMs: 240, closeMs: 200 },
        "controlcenter": { position: "right",  sideMargin: 10, width: 420, height: 560, radius: Style.popup_radius, openMs: 320, closeMs: 240 }
    })

    // Retención del panel en cierre: darle al wipe de salida el mismo box
    // y config que tenía el panel que se cierra (≥ closeMs + margen).
    property string _lastPanel: ""
    readonly property string _active: TaskbarState.panel !== "" ? TaskbarState.panel : shell._lastPanel
    readonly property var _cfg: shell._CONFIGS[shell._active] || shell._CONFIGS["launcher"]

    Timer {
        id: closeHold
        interval: 500
        repeat: false
        onTriggered: shell._lastPanel = ""
    }
    Connections {
        target: TaskbarState
        function onPanelChanged() {
            if (TaskbarState.panel !== "") {
                shell._lastPanel = TaskbarState.panel
                closeHold.stop()
            } else {
                closeHold.restart()
            }
        }
    }

    // Vista activa: la del panel abierto o, en cierre, la del panel
    // retenido (el item sigue vivo durante su grace de descarga).
    readonly property var _v: shell._active === "launcher" ? lLauncher.item
                            : shell._active === "jumplist" ? lJumplist.item
                            : shell._active === "music" ? lMusic.item
                            : shell._active === "controlcenter" ? lCC.item
                            : null

    // ── Shell ──
    flag: TaskbarState.panel !== ""
    // Wipe de apertura/cierre para los 4 paneles (los tiempos por panel van
    // en openMs/closeMs de _CONFIGS).
    animated: true
    // Superficie fija al máximo que puede ocupar un panel (el truco del
    // JumpList/CC): la máscara recorta el input al box real.
    surfaceHeight: Screen.height - Config.taskbarHeight - 20
    position: shell._cfg.position
    sideMargin: shell._cfg.sideMargin
    contentWidth: shell._v ? shell._v.viewWidth : shell._cfg.width
    contentHeight: shell._v ? shell._v.viewHeight : shell._cfg.height
    positionX: shell._v ? shell._v.viewX : 0
    radius: shell._cfg.radius
    openMs: shell._cfg.openMs
    closeMs: shell._cfg.closeMs
    exclusiveFocus: shell._v ? (shell._v.viewExclusiveFocus === true) : false
    onDismissed: TaskbarState.closePanel()

    // Alto del box: el JumpList anima cambios con el popup abierto. Mismo
    // gate de siempre: no anima en la apertura (el cache se sincroniza al
    // abrir y ese salto tiene que pintar directo).
    Behavior on contentHeight {
        enabled: TaskbarState.panel === "jumplist" && shell.openProgress > 0.99
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // ── Paneles (carga diferida por panel) ──
    // visible usa _active (panel abierto o retenido), no panel: durante el
    // wipe de salida el contenido tiene que seguir viéndose, y al hacer
    // swap los sticky no deben quedarse pintados detrás del nuevo.
    AutoLazyLoader {
        id: lLauncher
        condition: TaskbarState.panel === "launcher"
        visible: shell._active === "launcher"
        source: Component { LauncherPopup {} }
    }
    AutoLazyLoader {
        id: lJumplist
        condition: TaskbarState.panel === "jumplist"
        sticky: false
        visible: shell._active === "jumplist"
        source: Component { JumpList {} }
    }
    AutoLazyLoader {
        id: lMusic
        condition: TaskbarState.panel === "music"
        visible: shell._active === "music"
        source: Component { MusicPopup {} }
    }
    AutoLazyLoader {
        id: lCC
        condition: TaskbarState.panel === "controlcenter"
        visible: shell._active === "controlcenter"
        source: Component { ControlCenterNew {} }
    }
}
