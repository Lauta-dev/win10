// CpKeepassDelegate.qml — Delegate para entries de KeePassXC con 5 botones laterales.
import QtQuick
import "../../state"
import ".."

Item {
    property var itemData: ({})
    property int itemIndex: 0
    property bool isSelected: false
    property int panelWidth: 640

    signal entryActivated(var entry)
    signal copyRequested(string kind, var entry) // kind: KeePassState.kindUser/kindPassword/kindTotp
    signal editRequested(var entry)
    signal delRequested(var entry)

    height: 56

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
            // Encima del bgMouse (hermano posterior): si no, los clicks
            // en botones caen primero al fondo de la fila.
            z: 1

            PillButton {
                width: 28; height: 28
                icon: Icons.lock
                customContainerColor: Qt.alpha(Style.primary, 0.12)
                customTextColor: Style.primary
                iconSize: Config.fontSizeBody
                interactive: false
            }

            Column {
                id: textCol
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 38 - btnRow.width - 12
                spacing: 1

                Text {
                    width: parent.width
                    text: itemData.title ?? itemData.path ?? ""
                    font.pixelSize: Config.fontSizeBodySm; font.weight: Config.fontWeightMedium; font.family: Config.uiFont
                    color: isSelected ? Style.on_secondary_container : Style.on_surface
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: itemData.username ?? ""
                    font.pixelSize: Config.fontSizeLabelSm; font.family: Config.uiFont
                    color: Style.on_surface_variant
                    elide: Text.ElideRight
                    visible: (itemData.username ?? "") !== ""
                }
            }

            Row {
                id: btnRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                z: 1
                opacity: isSelected || parent.parent.ph ? 1.0 : 0.45
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                PillButton {
                    id: userBtn
                    size: 28; iconSize: 14
                    icon: Icons.account
                    customContainerColor: Qt.alpha(Style.outline_variant, 0.18)
                    customTextColor: Style.on_surface
                    customRadius: 8
                    onClicked: copyRequested(KeePassState.kindUser, itemData)
                }
                PillButton {
                    id: passBtn
                    size: 28; iconSize: 14
                    icon: Icons.key
                    customContainerColor: Qt.alpha(Style.primary, 0.14)
                    customTextColor: Style.primary
                    customRadius: 8
                    onClicked: copyRequested(KeePassState.kindPassword, itemData)
                }
                PillButton {
                    id: totpBtn
                    visible: (itemData.hasTotp === undefined) ? true : itemData.hasTotp
                    size: 28; iconSize: 14
                    icon: Icons.timer
                    customContainerColor: Qt.alpha(Style.outline_variant, 0.18)
                    customTextColor: Style.on_surface
                    customRadius: 8
                    onClicked: copyRequested(KeePassState.kindTotp, itemData)
                }
                PillButton {
                    id: editBtn
                    size: 28; iconSize: 14
                    icon: Icons.keyVariant
                    customContainerColor: Qt.alpha(Style.outline_variant, 0.18)
                    customTextColor: Style.on_surface
                    customRadius: 8
                    onClicked: editRequested(itemData)
                }
                PillButton {
                    id: delBtn
                    size: 28; iconSize: 14
                    icon: Icons.trash
                    customContainerColor: Qt.alpha(Style.error, 0.14)
                    customTextColor: Style.error
                    customRadius: 8
                    onClicked: delRequested(itemData)
                }
            }
        }

        HoverHandler { onHoveredChanged: parent.ph = hovered }
        MouseArea {
            id: bgMouse
            anchors.fill: parent
            hoverEnabled: false
            z: 0 // debajo de btnRow (z:1): los botones reciben primero
            onClicked: entryActivated(itemData)
        }
    }
}
