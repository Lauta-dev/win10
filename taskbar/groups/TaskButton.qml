// TaskButton.qml — Botón unificado estilo Windows 10
// Pineado sin ventana = launcher. Pineado con ventana = activo+launcher. No pineado = solo ventana.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../state"
import "../../components"

Item {
    id: root

    required property string appId
    required property bool   isPinned

    readonly property var toplevels: (function() {
        if (!OpenAppsState.toplevelsFor) return []
        var key = (OpenAppsState._norm ? OpenAppsState._norm(appId) : appId)
        return OpenAppsState.toplevelsFor[key] || []
    })()

    readonly property var _appData: OpenAppsState.appDataFor ? OpenAppsState.appDataFor[appId] : null
    readonly property int  winCount:     _appData ? _appData.winCount : 0
    readonly property bool hasWindows:   winCount > 0
    readonly property bool grouped:      winCount > 1
    readonly property var  primary:      hasWindows ? toplevels[0] : null

    readonly property bool anyActive:    _appData ? _appData.anyActive : false
    readonly property bool allMinimized: false

    readonly property bool isPopupOpen: TaskbarState.jumpListOpen
                                        && TaskbarState.activeJumpList === root.appId
    readonly property string iconSrc:   Config.resolveIcon(appId)
    readonly property var    entry:     Config._resolveEntry(appId)
    readonly property string label:     entry ? (entry.name ?? appId) : appId
    readonly property bool   isLaunching: AppLaunchState.launching.indexOf(root.appId) >= 0

    width: 46
    height: parent ? parent.height : 48

    property bool hovered:  false
    property bool pressed:  false
    property bool dragJustEnded: false
    property real pressX: 0
    property real pressY: 0
    readonly property int dragThreshold: 8

    // Feedback visual mientras este ítem es el que se arrastra
    readonly property bool isDragging: TaskbarState.taskDragActive
                                      && TaskbarState.dragSourceAppId === root.appId
    opacity: isDragging ? 0.45 : 1.0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    // ── Fondo: pill accent estilo volumen ──────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 4
        height: Config.taskbarHeight - 8
        radius: Style.button_radius
        color: Qt.alpha(Style.primary, root.pressed ? 0.18
                        : (root.hovered || root.isPopupOpen) ? 0.10 : 0.0)
        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } enabled: root.hovered }
    }

    // Overlay de lanzamiento: bg propio hasta que abre, con respiración suave.
    Rectangle {
        id: launchBg
        anchors.centerIn: parent
        width: parent.width - 4
        height: Config.taskbarHeight - 8
        radius: Style.button_radius
        color: Style.primary_container
        opacity: root.isLaunching && !root.hasWindows ? 0.7 : 0.0
    }

    // ── Ícono ─────────────────────────────────────────────────────────────
    Item {
        anchors.left: parent.left
        anchors.leftMargin: (46 - (Config.iconSize + 2)) / 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
        width: Config.iconSize + 2; height: Config.iconSize + 2
        opacity: root.allMinimized ? 0.45 : 1.0

        AppIcon {
            anchors.fill: parent
            source: root.iconSrc
            appId:  root.appId
            size:   Config.iconSize + 2
        }

        WindowCountBadge {
            visible: root.grouped
            anchors.right:  parent.right;  anchors.rightMargin:  -3
            anchors.bottom: parent.bottom; anchors.bottomMargin: -3
            count:  root.winCount
            active: root.anyActive
        }
    }

    // ── Dot indicator (estilo Win10: barra abajo) ─────────────────────────
    Rectangle {
        id: dotBar
        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: {
            if (root.anyActive)    return parent.width - 16
            if (root.hasWindows)   return root.hovered ? 8 : 4
            if (root.isLaunching)  return 8
            if (root.isPinned)     return root.hovered ? 6 : 0
            return 0
        }
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        height: 3; radius: 1.5
        color: root.anyActive ? Style.primary
              : root.hasWindows
                ? Style.on_surface
                : (root.isLaunching ? Style.primary : Config.withAlpha(Style.primary, 0.4))
        opacity: 1.0
    }

    // ── Timers ────────────────────────────────────────────────────────────
    Timer {
        id: jumpListShowTimer; interval: 300; running: false; repeat: false
        onTriggered: {
            if (TaskbarState.taskDragActive) return
            if (root.hovered && root.grouped && !root.isPopupOpen)
                TaskbarState.openJumpList(root.appId,
                                          root.mapToItem(null, root.width / 2, 0).x,
                                          true)
        }
    }

    // ── Interacción ───────────────────────────────────────────────────────
    Mouse {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: {
            // Iniciar arrastre de un pin: al cruzar con el click izquierdo
            // presionado desde un pin presionado hacia otro botón pin.
            if (!TaskbarState.taskDragActive
                    && TaskbarState.pressedPinAppId !== ""
                    && TaskbarState.pressedPinAppId !== root.appId
                    && root.isPinned) {
                TaskbarState.startDrag(TaskbarState.pressedPinAppId,
                                       TaskbarState.pressedPinIndex, root.index)
                root.hovered = false
                return
            }
            if (TaskbarState.taskDragActive) {
                // Volver al origen cancela el arrastre (click normal al soltar).
                if (root.index === TaskbarState.dragSourceIndex) {
                    TaskbarState.cancelDrag()
                    return
                }
                // Candidato a recibir el dropped (índice destino de inserción).
                if (root.isPinned)
                    TaskbarState.updateDragTarget(root.index)
                return
            }
            root.hovered = true
            TaskbarState.jumpListHoveredApp = root.appId
            TaskbarState.notifyJumpListHover()
            if (root.grouped && !root.isPopupOpen) jumpListShowTimer.restart()
        }
        onExited: {
            if (TaskbarState.taskDragActive) return
            root.hovered = false; root.pressed = false
            if (TaskbarState.jumpListHoveredApp === root.appId)
                TaskbarState.jumpListHoveredApp = ""
            TaskbarState.notifyJumpListHover()
            jumpListShowTimer.stop()
            TaskbarState.hideTip()
        }
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.pressed = true
                root.pressX = mouse.x
                root.pressY = mouse.y
                if (root.isPinned) {
                    TaskbarState.pressedPinAppId = root.appId
                    TaskbarState.pressedPinIndex = root.index
                } else {
                    TaskbarState.pressedPinAppId = ""
                    TaskbarState.pressedPinIndex = -1
                }
            }
        }
        onReleased: (mouse) => {
            root.pressed = false
            if (TaskbarState.pressedPinAppId === root.appId) {
                TaskbarState.pressedPinAppId = ""
                TaskbarState.pressedPinIndex = -1
            }
            if (mouse.button === Qt.LeftButton && TaskbarState.taskDragActive) {
                TaskbarState.endDrag()
                root.dragJustEnded = true
                dragEndTimer.restart()
                return
            }
        }
        onCanceled: () => {
            root.pressed = false
            if (TaskbarState.pressedPinAppId === root.appId) {
                TaskbarState.pressedPinAppId = ""
                TaskbarState.pressedPinIndex = -1
            }
            if (TaskbarState.taskDragActive) {
                TaskbarState.cancelDrag()
                root.dragJustEnded = true
                dragEndTimer.restart()
            }
        }

        onPositionChanged: (mouse) => {
            if (!root.pressed) return
            if (!root.isPinned) return
            if (TaskbarState.taskDragActive) {
                // Índice destino por desplazamiento horizontal (slot = botón + spacing).
                var slotW = root.width + 2
                var dx = mouse.x - root.pressX
                var offset = Math.round(dx / slotW)
                var target = root.index + offset
                var maxPin = TaskbarState.pinnedApps.length - 1
                if (target < 0) target = 0
                if (target > maxPin) target = maxPin
                TaskbarState.updateDragTarget(target)
                return
            }
            var dx = mouse.x - root.pressX
            var dy = mouse.y - root.pressY
            if (dx * dx + dy * dy > root.dragThreshold * root.dragThreshold) {
                root.hovered = false
                TaskbarState.startDrag(root.appId, root.index, root.index)
            }
        }

        onClicked: (mouse) => {
            if (TaskbarState.taskDragActive || root.dragJustEnded) return
            TaskbarState.hideTip()

            if (mouse.button === Qt.RightButton) {
                if (root.isPopupOpen) {
                    TaskbarState.closeJumpList()
                } else {
                    TaskbarState.openJumpList(root.appId,
                                              root.mapToItem(null, root.width / 2, 0).x,
                                              false)
                }

            } else if (mouse.button === Qt.LeftButton) {
                if (root.isPopupOpen) { TaskbarState.closeJumpList(); return }

                if (root.grouped) {
                    TaskbarState.openJumpList(root.appId,
                                              root.mapToItem(null, root.width / 2, 0).x,
                                              false)
                } else if (root.hasWindows) {
                    var tl = root.primary
                    if (tl) {
                        if (tl.activated && !tl.minimized) tl.minimized = true
                        else { tl.minimized = false; tl.activate() }
                    } else {
                        AppLaunchState.launch(root.appId)
                    }
                } else {
                    AppLaunchState.launch(root.appId)
                }
            }
        }
    }

    // Indicador de inserción: línea en el borde izquierdo del ítem destino
    // (se muestra cuando este ítem está bajo el cursor durante un arrastre).
    Rectangle {
        id: insertMark
        anchors.left: parent.left
        width: 2
        height: parent.height
        color: Style.primary
        visible: TaskbarState.taskDragActive
                 && TaskbarState.dragTargetIndex === root.index
                 && TaskbarState.dragSourceAppId !== root.appId
        opacity: 0.9
    }

    Timer {
        id: dragEndTimer
        interval: 60
        repeat: false
        onTriggered: root.dragJustEnded = false
    }
}
