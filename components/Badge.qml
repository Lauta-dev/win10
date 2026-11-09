// Badge.qml — Pill reutilizable para labels inline (Reciente, Activo, All, etc.)
import QtQuick
import "../state"

Rectangle {
    id: root

    property string text: ""
    property bool   active: false

    signal clicked()

    width: label.implicitWidth + 16
    height: 16
    radius: Style.radius_pill
    color: active ? Style.surface_container : Qt.alpha(Style.surface_container_low, 0.02)

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Config.fontSizeBadge
        font.weight: Config.fontWeightMedium
        font.family: Config.uiFont
        color: active ? Style.on_surface : Style.on_surface
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
