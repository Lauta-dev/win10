// SystemTrayArea.qml — Bandeja del sistema M3
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../state"
import "../widgets"
import "../components"

Row {
    id: root
    Layout.fillHeight: true
    spacing: 2
    property var panelWindow: null

    // Tray icons
    Repeater {
        model: SystemTray.items
        delegate: TrayIconPill {
            required property SystemTrayItem modelData
            height: root.height
            trayItem: modelData
            panelWindow: root.panelWindow
        }
    }

    DashWidget  { height: parent.height }

}
