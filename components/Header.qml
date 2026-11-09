import QtQuick
import "../state"

Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property int badge: 0
    property bool showAction: true
    property string actionLabel: ""
    property real height_: 48

    signal action()

    height: root.height_
    color: "transparent"

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.pixelSize: Config.fontSizeTitle
            font.family: Icons.font
            color: Style.on_surface
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.pixelSize: Config.fontSizeBody
            font.weight: Config.fontWeightMedium
            font.family: Config.uiFont
            color: Style.on_surface
        }

        Rectangle {
            visible: root.badge > 0
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            width: Math.max(20, badgeText.implicitWidth + 10)
            radius: 10
            color: Style.primary

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                font.pixelSize: Config.fontSizeLabelSm
                font.weight: Config.fontWeightBold
                font.family: Config.uiFont
                color: Style.on_primary
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        implicitWidth: actionLbl.implicitWidth + 20
        radius: Style.radius_pill
        visible: root.actionLabel !== "" && root.badge > 0
        property bool ph: false
        color: ph
            ? Style.overlay_tint(0.08)
            : Style.overlay_tint(0)
        Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }

        Text {
            id: actionLbl
            anchors.centerIn: parent
            text: root.actionLabel
            font.pixelSize: Config.fontSizeLabel
            font.family: Config.uiFont
            color: Style.primary
            font.weight: Config.fontWeightMedium
        }
        HoverHandler { onHoveredChanged: parent.ph = hovered }
        TapHandler { onTapped: root.action() }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Style.outline_variant
        opacity: 0.4
    }
}
