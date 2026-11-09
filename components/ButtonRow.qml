import QtQuick
import QtQuick.Layouts
import "../state"

RowLayout {
    id: root
    spacing: 8
    width: parent.width

    property var model: []
    property string selectedId: ""

    signal itemClicked(string id)

    Repeater {
        model: root.model

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: 72
            radius: Style.button_radius_lg
            color: root.selectedId === modelData.id ? Style.primary : "transparent"
            border.width: 0

            Rectangle {
                anchors.fill: parent
                radius: Style.button_radius_lg
                color: Style.surface_container_highest
                opacity: root.selectedId !== modelData.id && _ma.containsMouse ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.icon
                    font.pixelSize: Config.fontSizeIcon
                    font.family: Icons.font
                    color: root.selectedId === modelData.id ? Style.on_primary : Style.on_surface
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.label
                    font.pixelSize: Config.fontSizeLabel
                    font.family: Config.uiFont
                    font.weight: Config.fontWeightMedium
                    color: root.selectedId === modelData.id ? Style.on_primary : Style.on_surface
                }
            }

            Mouse {
                id: _ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.itemClicked(modelData.id)
            }
        }
    }
}
