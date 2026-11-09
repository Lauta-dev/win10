import ".."
import "../../state"
// CpCalcPanel.qml — Calculadora del modo "calc" del Command Palette.
// Un solo input fijo abajo + Display readout arriba (resultado en vivo).
// Motor: CalculatorState (async, binario bin/calc-eval). El Display
// es reactivo: "…" mientras busy, resultado o error al llegar.
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string _expr: calcInput.text
    property string _lastText: ""
    readonly property bool _canCommit: (root._expr || "").trim() !== "" && !CalculatorState.busy && CalculatorState.liveOk
    // Fracción exacta: se renderiza apilada estilo \frac en vez de "a/b".
    readonly property bool _isFraction: (root._expr || "").trim() !== "" && !CalculatorState.busy && CalculatorState.liveOk && CalculatorState.liveNum !== "" && CalculatorState.liveDen !== ""

    signal cancelled()
    signal committed(string expr, string result)

    function open() {
        calcInput.clear();
        Qt.callLater(function() {
            calcInput.forceActiveFocus();
        });
    }

    function focusInput() {
        calcInput.forceActiveFocus();
    }

    function clearInput() {
        calcInput.clear();
    }

    // Enter guarda el resultado como último y limpia para la próxima.
    function _commitCurrent() {
        var expr = (calcInput.text || "").trim();
        if (expr === "" || CalculatorState.busy || !CalculatorState.liveOk)
            return ;

        var res = CalculatorState.liveResult;
        _lastText = res;
        calcInput.clear();
        root.committed(expr, res);
        calcInput.forceActiveFocus();
    }

    function _copyText(t) {
        if (t === "")
            return ;

        CalculatorState.copyText(t);
    }

    // ── Teclado: inserta en el cursor del input, mismo motor ──
    function _press(s) {
        var f = calcInput.editField;
        f.insert(f.cursorPosition, s);
        calcInput.forceActiveFocus();
    }

    function _backspace() {
        var f = calcInput.editField;
        if (f.selectedText !== "") {
            var a = f.selectionStart, b = f.selectionEnd;
            f.text = f.text.slice(0, a) + f.text.slice(b);
            f.cursorPosition = a;
        } else {
            var pos = f.cursorPosition;
            if (pos > 0) {
                f.text = f.text.slice(0, pos - 1) + f.text.slice(pos);
                f.cursorPosition = pos - 1;
            }
        }
        calcInput.forceActiveFocus();
    }

    // "=" encadena: el resultado pasa al input para seguir operando.
    function _equals() {
        if (!root._canCommit)
            return ;
        calcInput.text = CalculatorState.liveResult;
        var f = calcInput.editField;
        f.cursorPosition = f.text.length;
        calcInput.forceActiveFocus();
    }

    function _keyAction(k) {
        if (k.act === "clear")
            root.clearInput();
        else if (k.act === "back")
            root._backspace();
        else if (k.act === "eq")
            root._equals();
        else
            root._press(k.ins);
        calcInput.forceActiveFocus();
    }

    on_ExprChanged: CalculatorState.requestEval(_expr)

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 20, 340)
        spacing: 8

        // ── Display: readout con bg propio (sin borde de input) ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            radius: Style.popup_radius_md
            color: Style.surface_container_low

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    Layout.fillHeight: true
                    visible: !root._isFraction
                    text: {
                        if (root._expr.trim() === "")
                            return root._lastText !== "" ? root._lastText : "0";

                        if (CalculatorState.busy)
                            return "…";

                        if (CalculatorState.liveOk)
                            return CalculatorState.liveResult;

                        return "…";
                    }
                    font.pixelSize: Config.fontSizeDisplay
                    font.weight: Config.fontWeightBold
                    font.family: Config.ibmPlexMono
                    color: {
                        if (root._expr.trim() === "")
                            return Style.on_surface;

                        if (CalculatorState.busy)
                            return Style.outline;

                        if (CalculatorState.liveOk)
                            return Style.primary;

                        return Style.outline;
                    }
                    elide: Text.ElideLeft
                    maximumLineCount: 1

                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root._isFraction
                    spacing: 12

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    CpCalcPie {
                        Layout.alignment: Qt.AlignVCenter
                        ratio: CalculatorState.liveRatio
                    }

                    CpCalcFraction {
                        Layout.alignment: Qt.AlignVCenter
                        numText: CalculatorState.liveNum
                        denText: CalculatorState.liveDen
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: CalculatorState.liveApprox !== "" ? "≈ " + CalculatorState.liveApprox : ""
                        visible: text !== ""
                        font.pixelSize: Config.fontSizeBodySm
                        font.family: Config.ibmPlexMono
                        color: Style.on_surface_variant
                    }

                }

            }

            TapHandler {
                onTapped: {
                    if (root._canCommit)
                        root._copyText(CalculatorState.liveResult);
                    else if (root._expr.trim() === "" && root._lastText !== "")
                        root._copyText(root._lastText);
                }
            }

        }

        // ── Input: fijo abajo ───────────────────────────────────
        AppTextInput {
            id: calcInput
            bgColor: Style.surface_container

            Layout.fillWidth: true
            inputHeight: 44
            placeholderText: "2*(3+4) · {llaves} · 1/3 exacta · Enter guarda"
            fontSize: Config.fontSizeBody
            fontFamily: Config.ibmPlexMono
            onAccepted: root._commitCurrent()
            onReturnPressed: root._commitCurrent()
            onEscapePressed: {
                if ((calcInput.text || "") !== "")
                    root.clearInput();
                else
                    root.cancelled();
            }
        }

        // ── Teclado básico (ancho acotado y centrado: botones cuadrados) ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: keyGrid.implicitHeight

            GridLayout {
                id: keyGrid
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                columns: 4
                rowSpacing: 8
                columnSpacing: 8

            Repeater {
                model: [
                    { t: "C", act: "clear", kind: "util" },
                    { t: "(", ins: "(", kind: "op" },
                    { t: ")", ins: ")", kind: "op" },
                    { t: "⌫", act: "back", kind: "util" },
                    { t: "7", ins: "7", kind: "num" },
                    { t: "8", ins: "8", kind: "num" },
                    { t: "9", ins: "9", kind: "num" },
                    { t: "÷", ins: "÷", kind: "op" },
                    { t: "4", ins: "4", kind: "num" },
                    { t: "5", ins: "5", kind: "num" },
                    { t: "6", ins: "6", kind: "num" },
                    { t: "×", ins: "×", kind: "op" },
                    { t: "1", ins: "1", kind: "num" },
                    { t: "2", ins: "2", kind: "num" },
                    { t: "3", ins: "3", kind: "num" },
                    { t: "−", ins: "−", kind: "op" },
                    { t: "%", ins: "%", kind: "op" },
                    { t: "0", ins: "0", kind: "num" },
                    { t: ".", ins: ".", kind: "num" },
                    { t: "+", ins: "+", kind: "op" },
                    { t: "=", act: "eq", kind: "eq", span: 4 },
                ]

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.columnSpan: modelData.span || 1
                    Layout.preferredHeight: 64
                    radius: Style.button_radius_lg
                    color: modelData.kind === "eq" ? Style.primary : Style.surface_container_high

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: modelData.kind === "eq" ? Qt.darker(Style.primary, 1.3) : Style.interactive_bg
                        opacity: _ma.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.t
                        font.pixelSize: Config.fontSizeHeadline
                        font.weight: Config.fontWeightMedium
                        font.family: modelData.kind === "num" ? Config.ibmPlexMono : Config.uiFont
                        color: {
                            if (modelData.kind === "eq")
                                return Style.on_primary;
                            if (modelData.kind === "op")
                                return Style.primary;
                            if (modelData.act === "clear")
                                return Style.error;
                            return Style.on_surface;
                        }
                    }

                    Mouse {
                        id: _ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._keyAction(modelData)
                    }
                }
            }
            }
        }

    }

}
