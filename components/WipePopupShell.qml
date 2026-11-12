// WipePopupShell.qml — Shell genérica de popups
// (SidebarWindow): superficie layer-shell fija abajo + caja de contenido
// que se revela con wipe vertical desde la barra (clip). El shell NUNCA
// se escala: el ConvexPopupShape queda estático y el contenido se descubre.
//
// El host aporta flag, geometría, contenido (hijos directos) y cierre:
//   WipePopupShell {
//       flag: TaskbarState.showLauncher
//       contentWidth: 640; contentHeight: 520; surfaceHeight: 520
//       radius: 16; exclusiveFocus: true
//       onDismissed: TaskbarState._hideLauncher()
//       AppMenuView { ... }   // contenido
//   }
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../state"

PanelWindow {
    id: shell

    // ── API del host ──
    property bool flag: false
    signal dismissed()
    default property alias content: contentSlot.data

    property string position: "center"  // "center" | "left" | "right"
    property real positionX: 0          // solo "left": x de referencia (p. ej. TaskbarState.popupX)
    property real sideMargin: 8         // solo "right": margen al borde
    property int  contentWidth:  640
    property int  contentHeight: 520
    property int  surfaceHeight: 520
    property int  flareOverscan: 32     // 16px por lado para los flares
    property real radius: Style.popup_radius
    property color shapeColor: Style.surface_container_lowest
    // Sin shape (ej. popups con overlays personalizados).
    property bool shapeEnabled: true
    property bool dismissEnabled: true
    property bool exclusiveFocus: false
    property int  openMs:  300
    property int  closeMs: 300
    // Opt-in: el host habilita el wipe (por defecto no anima).
    property bool animated: false

    // ── Estado interno ──
    property bool _animReady: false
    readonly property bool isOpen: _animReady && shell.flag
    Component.onCompleted: Qt.callLater(function() { _animReady = true })

    readonly property real _boxW: shell.contentWidth + shell.flareOverscan
    readonly property real _boxX: {
        if (shell.position === "left")
            return Math.max(8, Math.min(shell.positionX - shell._boxW / 2, shell.width - shell._boxW - 8))
        if (shell.position === "right")
            return Math.max(8, shell.width - shell._boxW - shell.sideMargin)
        return (shell.width - shell._boxW) / 2
    }

    anchors.bottom: true; anchors.left: true; anchors.right: true
    exclusiveZone: -1
    implicitHeight: shell.surfaceHeight
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (shell.isOpen && shell.exclusiveFocus) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.margins.bottom: Config.taskbarHeight
    color: "transparent"

    Region { id: emptyMask }
    // Rect explícito con bindings (patrón LauncherPopup: `item:` congela
    // la geometría al nacer).
    Region {
        id: boxMask
        x: Math.round(shell._boxX)
        y: Math.round(shell.height - shell.contentHeight)
        width: Math.round(shell._boxW)
        height: shell.contentHeight
    }
    mask: shell.isOpen ? boxMask : emptyMask

    DismissOverlay {
        isOpen: shell.isOpen && shell.dismissEnabled
        onDismissed: shell.dismissed()
    }

    // Progreso 0→1: apertura openMs OutCubic, cierre closeMs OutCubic.
    // La dirección se lee de `isOpen` (no de `_hiding`): cuando arranca la
    // animación isOpen ya cambió, así el Behavior captura siempre los
    // parámetros correctos sin depender del orden de evaluación.
    property real openProgress: (shell.isOpen && !shell._hiding) ? 1 : 0
    Behavior on openProgress {
        enabled: shell.animated
        NumberAnimation {
            duration: shell.isOpen ? shell.openMs : shell.closeMs
            easing.type: Easing.OutCubic
        }
    }
    property bool _hiding: false
    Timer { id: hideTimer; interval: shell.closeMs; repeat: false; onTriggered: shell._hiding = false }
    onIsOpenChanged: {
        if (shell.isOpen) { shell._hiding = false; hideTimer.stop() }
        else { shell._hiding = true; hideTimer.restart() }
    }

    // Caja de contenido (posición exacta de la máscara).
    Item {
        id: sizeBox
        x: shell._boxX
        y: shell.height - shell.contentHeight
        width: shell._boxW
        height: shell.contentHeight

        // Wipe con clip: descubre el shell estático desde la barra.
        Item {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: Math.max(parent.height * shell.openProgress, 0.01)
            clip: true

            // El shape acompaña al wipe (alto del contenedor, radio
            // adaptativo): siempre se ve con bordes redondeados, nunca
            // cortado por el clip. Solo el contenido se descubre.
            ConvexPopupShape {
                id: shape
                visible: shell.shapeEnabled
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: shell.contentWidth
                height: parent.height
                radius: shell.radius
                color: shell.shapeColor
            }
            // Contenido a tamaño real, anclado abajo: el wipe lo descubre.
            Item {
                id: contentSlot
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: shell.contentWidth
                height: shell.contentHeight
            }
        }
    }
}
