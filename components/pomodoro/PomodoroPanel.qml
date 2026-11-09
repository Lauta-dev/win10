import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../state"
import "../../components"

Item {
    id: root

    property bool showSettings: false
    // Progreso 0..1 del drawer de ajustes (sube desde el borde inferior).
    property real drawerProgress: showSettings ? 1 : 0
    Behavior on drawerProgress {
        NumberAnimation { duration: showSettings ? 240 : 200; easing.type: Easing.OutCubic }
    }
    // Activo cuando el host lo muestra: habilita
    // animaciones y repintados del anillo. Default true para uso simple.
    property bool active: true
    onActiveChanged: {
        if (active) PomodoroState._resetDaily()
        else showSettings = false
    }

    readonly property string _phase: PomodoroState.timerState
    readonly property color _phaseColor:
        _phase === "shortBreak" ? Style.tertiary
        : _phase === "longBreak" ? Style.secondary
        : Style.primary
    readonly property string _phaseLabel:
        _phase === "shortBreak" ? "Descanso corto"
        : _phase === "longBreak" ? "Descanso largo"
        : "Enfoque"

    readonly property int _cycleProgress: {
        if (_phase === "longBreak") return 4
        return PomodoroState.sessionsCompleted % 4
    }

    implicitWidth: contentCol.implicitWidth
    implicitHeight: contentCol.implicitHeight

    ColumnLayout {
        id: contentCol
        anchors.centerIn: parent
        spacing: 0

        // ── Anilla + controles (al lado derecho) ──────
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 24

            // ── Anilla: tiempo + dots de sesiones ─────
            Item {
                implicitWidth: 206
                implicitHeight: 206

                Canvas {
                    id: ringCanvas
                    anchors.fill: parent

                    readonly property real ringWidth: 13
                    readonly property color ringColor: root._phaseColor
                    readonly property real ringProgress: PomodoroState.progress

                    readonly property bool _canvasActive: root.active
                    onRingColorChanged: { if (_canvasActive) requestPaint() }
                    onRingProgressChanged: { if (_canvasActive) requestPaint() }
                    onVisibleChanged: { if (visible) requestPaint() }
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        var w = width
                        var h = height
                        var cx = w / 2
                        var cy = h / 2
                        var radius = w / 2 - ringWidth / 2 - 1

                        ctx.clearRect(0, 0, w, h)

                        var startAngle = -Math.PI / 2
                        var endAngle = startAngle + ringProgress * Math.PI * 2

                        if (ringProgress <= 0.005) {
                            // Sin progreso: track completo, sin huecos,
                            // y nada de arco (evita la pastillita en el tope).
                            ctx.beginPath()
                            ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                            ctx.strokeStyle = Qt.alpha(Style.on_surface, 0.10)
                            ctx.lineWidth = ringWidth
                            ctx.stroke()
                        } else {
                            // Track con hueco chico en el extremo del progreso.
                            var gap = 0.04
                            var trackStart = endAngle + gap
                            var trackEnd = startAngle + Math.PI * 2 - gap

                            if (trackEnd - trackStart > 0.02) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, radius, trackStart, trackEnd)
                                ctx.strokeStyle = Qt.alpha(Style.on_surface, 0.10)
                                ctx.lineWidth = ringWidth
                                ctx.stroke()
                            }

                            ctx.beginPath()
                            ctx.arc(cx, cy, radius, startAngle, endAngle)
                            ctx.strokeStyle = ringColor
                            ctx.lineWidth = ringWidth
                            ctx.stroke()
                        }
                    }
                }

                // Fase + tiempo + dots de sesiones (adentro de la anilla)
                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root._phaseLabel
                        font.pixelSize: Config.fontSizeCaption
                        font.weight: Config.fontWeightMedium
                        font.family: Config.uiFont
                        color: root._phaseColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            var t = PomodoroState.timeRemaining
                            var m = Math.floor(t / 60)
                            var s = t % 60
                            return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                        }
                        font.pixelSize: 56
                        font.family: Config.uiFont
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                        color: Style.on_surface
                        lineHeight: 1.0
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Repeater {
                            model: 4

                            Rectangle {
                                width: 8; height: 8
                                radius: 4
                                border.width: index < root._cycleProgress ? 0 : 1
                                border.color: Qt.alpha(root._phaseColor, 0.4)
                                color: index < root._cycleProgress ? root._phaseColor : "transparent"
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: PomodoroState.sessionsCompleted + " hoy"
                            + (PomodoroState.totalSessions > 0
                                ? " · " + PomodoroState.totalSessions + " total" : "")
                        font.pixelSize: Config.fontSizeCaption
                        font.family: Config.uiFont
                        color: Style.on_surface_variant
                    }
                }
            }

            // ── Controles ─────────────────────────────
            // Mismo estilo que el MprisControl del player: pastilla
            // (surface_container_highest) con botones circulares;
            // play = primary lleno, resto ghost con hover.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: ctrlCol.implicitHeight + 8
                radius: width / 2
                color: Style.surface_container_highest

                Column {
                    id: ctrlCol
                    anchors.centerIn: parent
                    spacing: 6

                    // Play / Pause
                    PillButton {
                        width: 36; height: 36
                        customRadius: height / 2
                        iconSize: Config.fontSizeIcon
                        icon: PomodoroState.isRunning ? Icons.musicPause : Icons.musicPlay
                        customContainerColor: Style.primary
                        customTextColor: Style.on_primary
                        customHoverColor: Qt.darker(Style.primary, 1.2)
                        onClicked: {
                            if (PomodoroState.isRunning) PomodoroState.pause()
                            else PomodoroState.start()
                        }
                    }

                    // Reset
                    PillButton {
                        width: 36; height: 36
                        customRadius: height / 2
                        iconSize: Config.fontSizeIcon
                        icon: Icons.refreshAlt
                        customContainerColor: "transparent"
                        customTextColor: Style.on_surface_variant
                        customHoverColor: Style.interactive_bg
                        onClicked: PomodoroState.reset()
                    }

                    // Skip
                    PillButton {
                        width: 36; height: 36
                        customRadius: height / 2
                        iconSize: Config.fontSizeIcon
                        icon: Icons.chevronRight
                        customContainerColor: "transparent"
                        customTextColor: Style.on_surface_variant
                        customHoverColor: Style.interactive_bg
                        onClicked: PomodoroState.skipPhase()
                    }

                    // Settings (activo: secondary_container)
                    PillButton {
                        width: 36; height: 36
                        customRadius: height / 2
                        iconSize: Config.fontSizeIcon
                        icon: Icons.settings
                        customContainerColor: root.showSettings ? Style.secondary_container : "transparent"
                        customTextColor: root.showSettings ? Style.on_secondary_container : Style.on_surface_variant
                        customHoverColor: root.showSettings ? Style.secondary_container : Style.interactive_bg
                        onClicked: root.showSettings = !root.showSettings
                    }
                }
            }
        }

    }

    // ── Ajustes de duración: drawer inferior ──────────
    // Scrim de cierre (clic fuera).
    MouseArea {
        anchors.fill: parent
        z: 5
        visible: root.drawerProgress > 0.01
        opacity: root.drawerProgress * 0.45
        onClicked: root.showSettings = false

        Rectangle {
            anchors.fill: parent
            color: Style.scrim_solid
        }
    }

    Rectangle {
        id: drawer
        z: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: drawerCol.implicitHeight + 36
        y: root.height - height * root.drawerProgress
        topLeftRadius: Style.popup_radius
        topRightRadius: Style.popup_radius
        color: Style.surface_container_high
        border.width: Style.border_width
        border.color: Style.outline_variant
        enabled: root.drawerProgress > 0.99

        // Consume clics vacíos: sin esto el press llega al scrim y cierra.
        MouseArea { anchors.fill: parent; z: -1 }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 8
            width: 32; height: 4; radius: 2
            color: Style.outline_variant
        }

        Column {
            id: drawerCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24
            spacing: 10

            PomodoroDurationRow {
                label: "Enfoque"
                value: PomodoroState.workDuration / 60
                onDecrementRequested: PomodoroState.setWorkDuration(PomodoroState.workDuration / 60 - 1)
                onIncrementRequested: PomodoroState.setWorkDuration(PomodoroState.workDuration / 60 + 1)
            }
            PomodoroDurationRow {
                label: "Descanso"
                value: PomodoroState.shortBreakDuration / 60
                onDecrementRequested: PomodoroState.setShortBreakDuration(PomodoroState.shortBreakDuration / 60 - 1)
                onIncrementRequested: PomodoroState.setShortBreakDuration(PomodoroState.shortBreakDuration / 60 + 1)
            }
            PomodoroDurationRow {
                label: "Descanso largo"
                value: PomodoroState.longBreakDuration / 60
                onDecrementRequested: PomodoroState.setLongBreakDuration(PomodoroState.longBreakDuration / 60 - 1)
                onIncrementRequested: PomodoroState.setLongBreakDuration(PomodoroState.longBreakDuration / 60 + 1)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: PomodoroState.isRunning
                text: "Se aplica a la próxima sesión"
                font.pixelSize: Config.fontSizeBodySm
                font.family: Config.uiFont
                color: Style.on_surface_variant
            }
        }
    }
}
