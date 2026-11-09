// ConvexPopupShape.qml — Fondo de popup que "enchufa" a la barra:
// arriba redondeado, abajo cuadrado para apoyar a filo.
import QtQuick
import QtQuick.Shapes
import "../state"

Item {
    id: root

    property color color: Style.surface_container_lowest
    property color borderColor: Style.outline_variant
    property real borderWidth: 0
    property real radius: Style.popup_radius
    property real bottomRadius: 0
    // Flares cóncavos que abren la base hacia la barra (fusión estilo drawer).
    property real flareW: 16
    property real flareH: 12

    function edgePath(w, h, r, br) {
        if (w <= 0 || h <= 0)
            return ""
        r = Math.max(0, Math.min(r, h / 2, w / 2))
        br = Math.max(0, Math.min(br, h / 2, w / 2))
        let fw = Math.max(0, Math.min(root.flareW, w / 2))
        let fh = Math.max(0, Math.min(root.flareH, h / 2))
        let k1 = fh * 0.55, k2 = fw * 0.55
        let p = `M 0 ${r} `
        p += `A ${r} ${r} 0 0 1 ${r} 0 `
        p += `L ${w - r} 0 `
        p += `A ${r} ${r} 0 0 1 ${w} ${r} `
        if (br > 0) {
            p += `L ${w} ${h - br} `
            p += `A ${br} ${br} 0 0 0 ${w - br} ${h} `
            p += `L ${br} ${h} `
            p += `A ${br} ${br} 0 0 1 0 ${h - br} `
            p += `L 0 ${r} `
        } else {
            // Base a filo con flares: el borde baja recto y se abre
            // cócavo hasta (±fw, h) apoyando sobre la barra.
            p += `L ${w} ${h - fh} `
            p += `C ${w} ${h - fh + k1}, ${w + fw - k2} ${h}, ${w + fw} ${h} `
            p += `L ${-fw} ${h} `
            p += `C ${-fw + k2} ${h}, 0 ${h - fh + k1}, 0 ${h - fh} `
            p += `L 0 ${r} `
        }
        p += `Z`
        return p
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: root.borderWidth
            strokeColor: root.borderColor
            fillColor: root.color
            PathSvg {
                path: root.edgePath(root.width, root.height, root.radius, root.bottomRadius)
            }
        }
    }
}
