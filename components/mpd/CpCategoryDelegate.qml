// CpCategoryDelegate.qml — Delegate para categorías (ICON | ITEM).
import QtQuick
import "../../state"
import ".."

Item {
    property var  itemData:  ({})
    property int  itemIndex: 0
    property bool isSelected: false
    // Acento derivado del cover en modo mpd (default: tema global).
    // useAccent solo lo activa el palette en modo mpd; el resto de modos
    // conserva el look original (Style.primary / Style.on_primary).
    property color accent: Style.primary
    property bool useAccent: false
    property color textAccent: Style.primary
    property color hoverColor: Style.surface_container_highest

    signal categorySelected(string category)

    height: 56

    Rectangle {
        anchors { fill: parent; topMargin: 2; bottomMargin: 2 }
        radius: 10
        property bool ph: false
        color: "transparent"

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: useAccent ? hoverColor : Style.surface_container_highest
            opacity: parent.ph && !isSelected ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
            spacing: 12

            PillButton {
                width: 32; height: 32
                icon: itemData.icon ?? Icons.folder
                active: isSelected
                iconSize: Config.fontSizeTitle
                interactive: false
                customContainerColor: (isSelected && useAccent) ? accent : ""
                customTextColor: (isSelected && useAccent) ? Config._contrastOn(accent) : ""
                scale: isSelected ? 1.15 : 1.0
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: itemData.name ?? ""
                    font.pixelSize: Config.fontSizeBody; font.weight: Config.fontWeightMedium; font.family: Config.uiFont
                    color: isSelected ? (useAccent ? textAccent : Style.on_secondary_container) : Style.on_surface
                }
                Text {
                    text: itemData.description ?? ""
                    font.pixelSize: Config.fontSizeLabel; font.family: Config.uiFont
                    color: (isSelected && !useAccent) ? Style.on_secondary_container : Style.on_surface_variant
                    opacity: (isSelected && !useAccent) ? 0.8 : 1.0
                }
            }
        }

        HoverHandler { onHoveredChanged: parent.ph = hovered }
        TapHandler   { onTapped: {
            if (itemData.category) {
                categorySelected(itemData.category)
            }
        }}
    }
}
