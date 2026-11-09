import QtQuick
import ".."
import "../../state"

Row {
    id: root

    property string label: ""
    property int value: 0
    signal decrementRequested()
    signal incrementRequested()

    spacing: 10

    Text {
        text: root.label
        width: 100
        font.pixelSize: Config.fontSizeBodySm
        font.family: Config.uiFont
        color: Style.on_surface
        verticalAlignment: Text.AlignVCenter
        anchors.verticalCenter: parent.verticalCenter
    }

    PillButton {
        size: 32
        customRadius: height / 2
        iconSize: Config.fontSizeBody
        icon: Icons.minus
        onClicked: root.decrementRequested()
    }

    Text {
        text: root.value + "′"
        width: 36
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Config.fontSizeBody
        font.weight: Config.fontWeightMedium
        font.family: Config.uiFont
        color: Style.on_surface
        anchors.verticalCenter: parent.verticalCenter
    }

    PillButton {
        size: 32
        customRadius: height / 2
        iconSize: Config.fontSizeBody
        icon: Icons.add
        onClicked: root.incrementRequested()
    }
}
