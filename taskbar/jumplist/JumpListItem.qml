// JumpListItem.qml — Ítem de JumpList

import QtQuick
import "../../state"

Item {
    id: root

    required property string icon
    required property string label
    property bool danger: false

    signal activated()

    implicitHeight: 30

    property bool hovered: false

    Rectangle {
        anchors.fill: parent; radius: Style.radius_md
        color: root.danger ? Config.withAlpha(Style.danger, 0.15) : Style.surface_container_highest
        opacity: root.hovered ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: 10
        spacing: 8

        Text {
            text: root.icon
            font.family: Icons.font; font.pixelSize: Config.fontSizeBodySm
            color: root.danger ? Style.danger : Style.on_surface
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.label
            font.family: Config.uiFont; font.pixelSize: Config.fontSizeLabel
            font.weight: Config.fontWeightMedium
            color: root.danger ? Style.danger : Style.on_surface
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler { onHoveredChanged: root.hovered = hovered }
    TapHandler   { onTapped: root.activated() }
}
