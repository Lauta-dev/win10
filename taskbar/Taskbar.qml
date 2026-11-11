// Taskbar.qml — Barra completa de ancho total
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../state"

import "../tray"
import "../widgets"

PanelWindow {
    id: taskbar

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Config.taskbarHeight
    exclusiveZone: Config.taskbarHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Style.surface_container_lowest

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin:   4
            anchors.rightMargin:  4
            anchors.topMargin:    2
            anchors.bottomMargin: 2
            spacing: 5

            // IZQ: widget MPRIS. Reveal con slide horizontal + fade: sin
            // track colapsa a 0 y la TaskList central se re-centra
            // acompañando. clip: el contenido es de ancho fijo y desborda
            // durante el slide (contenedor chico, wipe válido).
            MprisWidget {
                id: mpris
                readonly property bool shown: mpris.hasTrack
                property real slide: shown ? 1 : 0

                clip: true
                opacity: slide
                Layout.preferredWidth: Math.round(mpris.slide * mpris.implicitWidth)
                Layout.fillHeight: true

                Behavior on slide {
                    NumberAnimation {
                        duration: mpris.shown ? 250 : 200
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // CENTRO: apps (el contenido se centra solo, ver TaskList).
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                TaskList {
                    anchors.fill: parent
                }
            }

            // DER: volumen + tray en slot fijo (el centro no reacciona a
            // cambios del lado derecho).
            Item {
                Layout.preferredWidth: 280
                Layout.fillHeight: true

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    spacing: 5

                    VolumeWidget   { height: parent.height }
                    SystemTrayArea { height: parent.height; panelWindow: taskbar }
                }
            }
        }
    }
}
