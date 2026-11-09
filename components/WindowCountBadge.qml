// WindowCountBadge.qml — Badge circular con número de ventanas.
// Uso: WindowCountBadge { count: windows.length; active: anyActive }
import QtQuick
import "../state"

Rectangle {
    id: root
    property int  count:  0
    property bool active: false

    width: 14; height: 14; radius: 7
    color: active ? Style.primary : Style.surface_container_highest

    Text {
        anchors.centerIn: parent
        text:  root.count
        font.pixelSize: Config.fontSizeBadge; font.bold: true
        font.family: Config.uiFont
        color: active ? Style.on_primary : Style.on_surface
    }
}
