// AppIcon.qml — Ícono de app con fallback de inicial coloreada.
// Uso: AppIcon { source: Config.resolveIcon(appId); appId: appId; size: 22 }
import QtQuick
import "../state"

Item {
    id: root
    property string source: ""
    property string appId:  ""
    property int    size:   22

    width: size; height: size

    Image {
        id: img
        anchors.fill: parent
        source:       root.source
        fillMode:     Image.PreserveAspectFit
        // Decode a 2x (hidpi) en vez de full-res.
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        asynchronous: true
        smooth: true; mipmap: true
        visible: root.source !== "" && status === Image.Ready
    }

    Rectangle {
        id: fallbackRect
        anchors.fill: parent
        radius: Math.round(size * 0.22)
        visible: img.status !== Image.Ready || root.source === ""
        color: root.appId !== ""
            ? Qt.hsla(((root.appId.charCodeAt(0) * 53) % 360) / 360, 0.55, 0.42, 1.0)
            : Style.surface_container_highest
        Text {
            anchors.centerIn: parent
            text:  root.appId.length > 0 ? root.appId[0].toUpperCase() : "?"
            color: Config._contrastOn(fallbackRect.color)
            font.pixelSize:  Math.round(root.size * 0.5)
            font.family:     Config.uiFont
            font.weight:     Config.fontWeightBold
        }
    }
}
