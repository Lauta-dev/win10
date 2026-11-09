// DismissOverlay.qml — Overlay reutilizable para cerrar un popup al click externo
// Uso: instanciar dentro de cualquier PanelWindow popup con isOpen y onDismiss
//
// Ejemplo:
//   DismissOverlay {
//       isOpen: root.isOpen
//       excludeTaskbar: true
//       onDismissed: TaskbarState.activePopup = ""
//   }

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../state"
import "../../components"

PanelWindow {
    id: root

    // ── API pública ───────────────────────────────────────────────────────
    property bool isOpen: false
    property bool excludeTaskbar: true   // excluye la zona del taskbar del mask
    signal dismissed

    // ── Ventana fullscreen invisible ──────────────────────────────────────
    anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    visible: root.isOpen

    Region {
        id: activeMask
        item: Rectangle {
            x: 0; y: 0
            width: root.width
            height: excludeTaskbar ? root.height - Config.taskbarHeight : root.height
            visible: false
        }
    }
    mask: activeMask

    Mouse {
        cursorShape: Qt.ArrowCursor
        x: 0; y: 0
        width: parent.width
        height: excludeTaskbar ? parent.height - Config.taskbarHeight : parent.height
        enabled: root.isOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: root.dismissed()
    }
}
