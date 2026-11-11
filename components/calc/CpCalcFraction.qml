import "../../state"
// CpCalcFraction.qml — Fracción apilada estilo LaTeX \frac.
// Numerador sobre denominador con vínculo, en IBM Plex Mono.
import QtQuick

Item {
    id: root

    property string numText: ""
    property string denText: ""
    property int fontSize: Config.fontSizeHeadline

    implicitWidth: col.implicitWidth + 16
    implicitHeight: col.implicitHeight + 8

    Column {
        id: col

        anchors.centerIn: parent
        spacing: 3

        Text {
            id: numT

            anchors.horizontalCenter: parent.horizontalCenter
            text: root.numText
            font.pixelSize: root.fontSize
            font.weight: Config.fontWeightBold
            font.family: Config.ibmPlexMono
            color: Style.primary
        }

        Rectangle {
            width: Math.max(numT.implicitWidth, denT.implicitWidth) + 12
            height: 2
            radius: 1
            color: Style.primary
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            id: denT

            anchors.horizontalCenter: parent.horizontalCenter
            text: root.denText
            font.pixelSize: root.fontSize
            font.weight: Config.fontWeightBold
            font.family: Config.ibmPlexMono
            color: Style.primary
        }

    }

}
