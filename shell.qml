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
    Taskbar        { visible: TaskbarState.ready }
    PanelPopupHost {}
    MpdIpc         {}
    BrightIpc      {}
    VolumeIpc      {}
    PowerIpc       {}
    AppMenuIpc     {}
    CalcIpc        {}
    ClipboardIpc   {}
    NotesIpc       {}

    
    AutoLazyLoader {
        condition: TaskbarState.activePopup === "settings"
        source: Component { SettingsPopup {} }
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

    AutoLazyLoader {
        condition: TaskbarState.showOsd
        sticky: false
        unloadDelay: 250
        source: Component { OsdSliderPopup {} }
    }

}
