//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import QtQuick
import "./state"
import "./components"
import "./taskbar"
import "./ipc"


import "./popups"
import "./tray"
import "./widgets"

ShellRoot {
    // darkMode y resto de config se aplican desde SettingsState al leer qs-settings.json
    // PanelPopupHost: superficie global de paneles (ver components/PanelPopupHost.qml).

    // ─ Siempre en memoria ───────────────────────────────────────────────
    Taskbar        { visible: TaskbarState.ready }
    // Superficie global de paneles (Launcher/JumpList/Music/ControlCenter):
    // siempre viva; los contenidos cargan lazy adentro. OSD y superposiciones
    // conservan su propia superficie (se superponen a los paneles).
    PanelPopupHost {}
    MpdIpc         {}
    BrightIpc      {}
    VolumeIpc      {}
    PowerIpc       {}
    AppMenuIpc     {}
    ClipboardIpc   {}
    NotesIpc       {}



    // ── Carga diferida: se instancian la primera vez que se abren ────────
    // Siempre en memoria para que el IpcHandler esté disponible desde el inicio
    // Hub/Settings también descargan: Hub re-corre enter() al reabrir y
    // Settings ya reseteaba su tab al cerrar (resetTabTimer); unloadDelay
    // cubre sus animaciones de salida (Hub 450ms, resto 400ms).
    // Quedan sticky a propósito: AppMenu/Clipboard (cursor preservado) y
    // ControlCenterNew (popup más usado, evita recreación).
    AutoLazyLoader {
        condition: TaskbarState.activePopup === "settings"
        sticky: false
        source: Component { SettingsPopup {} }
    }
    AutoLazyLoader {
        condition: TaskbarState.activePopup === "hub"
        sticky: false
        unloadDelay: 550
        source: Component { HubPopup {} }
    }

    AutoLazyLoader {
        condition: PolkitState.isActive
        sticky: false
        source: Component { PolkitPopup {} }
    }

    AutoLazyLoader {
        condition: TaskbarState.showNotesSidebar
        sticky: false
        source: Component { NotesSidebar {} }
    }

    

    // OSD único (vol/brillo/power por modo): una ventana; cambiar de modo con el
    // OSD visible solo actualiza contenido, sin reabrirse.
    AutoLazyLoader {
        condition: TaskbarState.showOsd
        sticky: false
        unloadDelay: 250
        source: Component { OsdSliderPopup {} }
    }

}
