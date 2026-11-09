// CpMpdFilterDelegate.qml — Delegate for artist/album filter results in MPD mode.

import QtQuick
import "../../state"

Item {
    property var  itemData:  ({})
    property int  itemIndex: 0
    property bool isSelected: false
    property int  panelWidth: 520
    // Acento derivado del cover (default: tema global)
    property color accent: Style.primary
    property color textAccent: Style.primary
    property color hoverColor: Style.surface_container_highest

    signal itemActivated(string query)

    height: 48

    Rectangle {
        anchors { fill: parent; topMargin: 1; bottomMargin: 1 }
        radius: 10
        property bool ph: false
        color: "transparent"

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: hoverColor
            opacity: parent.ph ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 12 }
            spacing: 10

            Item {
                width: 30; height: 30
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent; radius: 8
                    color: accent
                    opacity: 0.16
                }
                Text {
                    anchors.centerIn: parent
                    text: Icons.musicNote
                    font.pixelSize: Config.fontSizeBody; font.family: Icons.font
                    color: textAccent
                }
            }

            Text {
                width: parent.width - 40
                anchors.verticalCenter: parent.verticalCenter
                text: itemData.name ?? ""
                font { pixelSize: Config.fontSizeBody; weight: Font.Medium; family: Config.uiFont }
                color: isSelected ? textAccent : Style.on_surface
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        HoverHandler { onHoveredChanged: parent.ph = hovered }
        TapHandler   { onTapped: itemActivated(itemData.query ?? "") }
    }
}
