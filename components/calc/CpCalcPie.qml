import "../../state"
// CpCalcPie.qml — Chart pie de la fracción (porción rellena).
// Patrón de dibujo del anillo de PomodoroPanel (Canvas + requestPaint
// ante cambios). ratio se clamped 0..1 (impropias = disco lleno).
import QtQuick

Item {
    id: root

    property real ratio: 0
    property int pieSize: 76
    readonly property real _fill: Math.max(0, Math.min(1, ratio))

    implicitWidth: pieSize
    implicitHeight: pieSize

    Canvas {
        id: pie

        readonly property real fill: root._fill

        anchors.fill: parent
        onFillChanged: requestPaint()
        onVisibleChanged: {
            if (visible)
                requestPaint();

        }
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var cx = w / 2;
            var cy = w / 2;
            var radius = w / 2 - 1;
            ctx.clearRect(0, 0, w, w);
            // Disco base.
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.fillStyle = Qt.alpha(Style.on_surface, 0.1);
            ctx.fill();
            // Porción desde las 12 en punto.
            if (root._fill > 0) {
                var startAngle = -Math.PI / 2;
                var endAngle = startAngle + root._fill * Math.PI * 2;
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.arc(cx, cy, radius, startAngle, endAngle);
                ctx.closePath();
                ctx.fillStyle = Style.primary;
                ctx.fill();
            }
        }
    }

}
