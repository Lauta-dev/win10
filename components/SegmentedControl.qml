// SegmentedControl.qml
import QtQuick
import "../state"

Item {
    id: root
    property var    model:      []
    property var    value:      null
    property int    itemHeight: 28
    property int    itemPadding: 12
    property string orientation: "horizontal"
    property bool   fillWidth: false
    signal selected(var val)

    implicitWidth: orientation === "horizontal" ? row.implicitWidth : (fillWidth ? parent?.width || 0 : col.implicitWidth)
    implicitHeight: orientation === "vertical" ? col.implicitHeight : itemHeight

    width: implicitWidth
    height: implicitHeight

    Row {
        id: row
        visible: root.orientation === "horizontal"
        spacing: 2

        Repeater {
            model: root.model
            delegate: segDelegate
        }
    }

    Column {
        id: col
        visible: root.orientation === "vertical"
        spacing: 2

        Repeater {
            model: root.model
            delegate: segDelegate
        }
    }

    Component {
        id: segDelegate
        Item {
            required property var modelData
            readonly property bool sel: root.value === modelData.val
            width:  root.fillWidth && root.orientation === "vertical" ? parent.width : (lbl.implicitWidth + (iconLbl.visible ? iconLbl.implicitWidth + 8 : 0) + root.itemPadding * 2)
            height: root.itemHeight

            // Fondo seleccionado
            Rectangle {
                anchors.fill: parent
                radius: Style.button_radius
                color: parent.sel ? Style.primary_container : "transparent"
            }

            // Overlay hover
            Rectangle {
                anchors.fill: parent
                radius: Style.button_radius
                color: Style.surface_container_highest
                opacity: sh.hovered && !parent.sel ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    id: iconLbl
                    visible: modelData.icon !== undefined && modelData.icon !== ""
                    text: modelData.icon || ""
                    font.pixelSize: Config.fontSizeTitleSm
                    font.family: Icons.font
                    color: parent.parent.sel ? Style.primary : Style.on_surface
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: lbl
                    text: modelData.label
                    font.pixelSize: Config.fontSizeLabel; font.family: Config.uiFont
                    font.weight: parent.parent.sel ? Font.Medium : Font.Normal
                    color: parent.parent.sel ? Style.primary : Style.on_surface
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            HoverHandler { id: sh }
            TapHandler { onTapped: root.selected(modelData.val) }
            Mouse{}
        }
    }
}
