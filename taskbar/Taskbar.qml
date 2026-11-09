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

            // IZQ: widget MPRIS a la izquierda + slot fijo espejo del der
            // (centro real de pantalla: las apps de la TaskList no se
            // mueven al aparecer/desaparecer widgets del lado derecho).
            Item {
                Layout.preferredWidth: 280
                Layout.fillHeight: true

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    spacing: 5

                    MprisWidget { height: parent.height }
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

            // DER: slot espejo (mismo ancho que izq → centro real de pantalla).
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
