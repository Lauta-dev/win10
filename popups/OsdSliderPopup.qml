// OsdSliderPopup.qml — OSD único vol/brillo/power: el modo lo pone quien
// dispara (IPC); con el OSD visible, cambiar de modo solo actualiza
// bindings (icono/valor/color/contenido) sin recrear la ventana ni reanimar.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../state"
import "../components"

WipePopupShell {
    id: root
    flag: TaskbarState.showOsd
    readonly property bool isVol: TaskbarState.osdMode === "vol"
    readonly property bool isPower: TaskbarState.osdMode === "power"
    contentWidth: root.isPower ? 520 : 400
    contentHeight: root.isPower ? 72 : 56
    surfaceHeight: 200
    openMs: 250
    closeMs: 250
    animated: true
    // Solo el powermenu cierra con click afuera y toma el teclado;
    // vol/brillo quedan fijos y sin robar foco.
    dismissEnabled: root.isPower
    onDismissed: TaskbarState.showOsd = false
    exclusiveFocus: root.isPower

    // Ejecución delegada a TaskbarState (procesos persistentes: el popup
    // se descarga al cerrar).
    function _runAction(action) {
        TaskbarState.showOsd = false
        TaskbarState.runPower(action)
    }

    // Selección por teclado en modo power: 0 logout, 1 reboot, 2 poweroff.
    // Al entrar o reabrir se selecciona el primero; el hover del mouse la mueve.
    property int _currentIndex: 0
    onIsPowerChanged: { if (root.isPower) root._currentIndex = 0 }
    Connections {
        target: TaskbarState
        function onShowOsdChanged() { if (TaskbarState.showOsd && root.isPower) root._currentIndex = 0 }
    }
    function _activate(i) {
        root._runAction(["logout", "reboot", "off"][i])
    }

    // El salto discreto entre modos pinta directo (TaskbarState.osdSwitching
    // congela las animaciones); los ajustes en vivo por teclas/wheel siguen
    // animando suave.

    Item {
        anchors.fill: parent
        HoverHandler {
            onHoveredChanged: {
                if (hovered) TaskbarState.osdHideTimer.stop()
                else TaskbarState.osdHideTimer.restart()
            }
        }
        // Agarra el teclado solo en modo power (focus bindeado a isPower:
        // al cerrar se suelta solo). ←/→ mueven, Enter activa, Esc cierra.
        Item {
            anchors.fill: parent
            focus: root.isPower
            // Con foco de teclado el OSD no auto-cierra (como con hover);
            // al perderlo vuelve el timer.
            onActiveFocusChanged: {
                if (activeFocus) TaskbarState.osdHideTimer.stop()
                else if (root.isPower && TaskbarState.showOsd) TaskbarState.osdHideTimer.restart()
            }
            Keys.onPressed: (e) => {
                if (!root.isPower) return
                if (e.key === Qt.Key_Escape) {
                    TaskbarState.showOsd = false
                    e.accepted = true
                } else if (e.key === Qt.Key_Left) {
                    root._currentIndex = (root._currentIndex + 2) % 3
                    e.accepted = true
                } else if (e.key === Qt.Key_Right) {
                    root._currentIndex = (root._currentIndex + 1) % 3
                    e.accepted = true
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                    root._activate(root._currentIndex)
                    e.accepted = true
                }
            }
        }
        ValueSlider {
            visible: !root.isPower
            anchors.centerIn: parent
            // Ancho fijo (igual que la caja en modo slider): si siguiera al
            // parent, el cambio 520↔400 dispararía los Behavior de
            // relleno/perilla y el slider "sobresaldría" al cambiar de modo.
            width: 400
            value: root.isVol ? AudioState.volume : BrightState.brightness
            iconChar: root.isVol ? (AudioState.muted ? Icons.volumeMuted : Icons.volume) : Icons.brightness
            iconActive: root.isVol ? !AudioState.muted : true
            activeColor: root.isVol ? Style.primary : Style.secondary
            showIconToggle: false
            onChangeRequested: (v) => { if (root.isVol) AudioState.audioSetVolume(v); else BrightState.setBrightness(v) }
        }
        // (highlight delante de la fila: los botones son opacos y la taparían)
        Row {
            id: powerRow
            visible: root.isPower
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 16; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            PillButton {
                width: (parent.width - parent.spacing * 2) / 3
                icon: Icons.logout
                label: "Cerrar sesión"
                size: 52
                centerContent: true
                forceHover: root._currentIndex === 0
                opacity: root._currentIndex === 0 ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                onHoveredChanged: { if (hovered && !forceHover) root._currentIndex = 0 }
                onClicked: root._runAction("logout")
            }
            PillButton {
                width: (parent.width - parent.spacing * 2) / 3
                icon: Icons.reboot
                label: "Reiniciar"
                size: 52
                centerContent: true
                forceHover: root._currentIndex === 1
                opacity: root._currentIndex === 1 ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                onHoveredChanged: { if (hovered && !forceHover) root._currentIndex = 1 }
                onClicked: root._runAction("reboot")
            }
            PillButton {
                width: (parent.width - parent.spacing * 2) / 3
                icon: Icons.power
                label: "Apagar"
                size: 52
                centerContent: true
                forceHover: root._currentIndex === 2
                opacity: root._currentIndex === 2 ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                onHoveredChanged: { if (hovered && !forceHover) root._currentIndex = 2 }
                customContainerColor: Style.error_container
                customTextColor: Style.on_error_container
                onClicked: root._runAction("off")
            }
        }
        // Highlight deslizante horizontal (patrón AppMenu/PanelList): la
        // selección la dibuja esta píldora, no los botones. Va DELANTE de
        // la fila porque los botones son opacos y la taparían; con alfa
        // 0.1 solo tiñe y al no tener MouseArea no roba clicks.
        Rectangle {
            visible: root.isPower
            width: (powerRow.width - powerRow.spacing * 2) / 3
            height: 52
            x: powerRow.x + root._currentIndex * (width + powerRow.spacing)
            y: powerRow.y
            radius: Style.button_radius_lg
            color: Qt.alpha(Style.primary, 0.1)
        }
    }
}
