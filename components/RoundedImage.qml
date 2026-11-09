// RoundedImage.qml — Imagen con esquinas redondeadas.
// Usa ClippingRectangle nativo (Qt 6.7+): recorte por GPU sin los dos
// offscreens + shader que pedía la máscara con MultiEffect.
import QtQuick
import Quickshell.Widgets
import "../state"

ClippingRectangle {
    id: root

    property string source: ""
    property int fillMode: Image.PreserveAspectCrop
    property size sourceSize: Qt.size(0, 0)

    readonly property alias status: img.status

    color: "transparent"
    radius: 8

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize.width: root.sourceSize.width > 0 ? root.sourceSize.width : 0
        sourceSize.height: root.sourceSize.height > 0 ? root.sourceSize.height : 0
        fillMode: root.fillMode
        asynchronous: true
        smooth: true
        mipmap: true
        cache: true
    }
}
