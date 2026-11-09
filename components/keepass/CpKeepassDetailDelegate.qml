// CpKeepassDetailDelegate.qml — Delegate para acciones de una entry (user/pass/totp)
import QtQuick
import "../../state"
import ".."

Item {
    property var itemData: ({})
    property int itemIndex: 0
    property bool isSelected: false
    property int panelWidth: 640

    signal actionTriggered(string actionId)

    height: 52

    Rectangle {
        anchors { fill: parent; topMargin: 1; bottomMargin: 1 }
        radius: 10
        property bool ph: false
        color: "transparent"

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: Style.surface_container_highest
            opacity: parent.ph && !isSelected ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
            spacing: 10

            PillButton {
                width: 28; height: 28
                icon: itemData.icon ?? Icons.key
                customContainerColor: Qt.alpha(Style.primary, 0.12)
                customTextColor: Style.primary
                iconSize: Config.fontSizeBody
                interactive: false
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 38
                spacing: 1

                Text {
                    width: parent.width
                    text: itemData.label ?? ""
                    font.pixelSize: Config.fontSizeBodySm; font.weight: Config.fontWeightMedium; font.family: Config.uiFont
                    color: isSelected ? Style.on_secondary_container : Style.on_surface
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: itemData.description ?? ""
                    font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                    color: Style.on_surface_variant
                    elide: Text.ElideRight
                }
            }
        }

        HoverHandler { onHoveredChanged: parent.ph = hovered }
        TapHandler { onTapped: actionTriggered(itemData.id ?? "") }
    }
}
