// CalculatorState.qml — Motor aritmético para el modo "calc".
// Diseño espejo del Qalculator de Caelestia: evaluación async con
// contador de generación (descarta respuestas viejas), props busy +
// liveResult (≈ rawResult, copiable). El motor es el binario propio
// scripts/calc-eval (Go, protocolo JSON) en vez del plugin C++ con
// libqalculate: misma arquitectura, extensible sin C++.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ── Resultado en vivo (async) ────────────────────────────────────
    property string liveResult: ""
    property string liveError: ""
    property bool liveOk: false
    property bool busy: false
    // Fracción exacta apilada ("" si no hay): num/den + decimal aprox.
    property string liveNum: ""
    property string liveDen: ""
    property string liveApprox: ""
    // Proporción para el chart pie (clamp 0..1 en la UI).
    property real liveRatio: 0

    // Pide evaluar expr con debounce. "" limpia el estado sin spawnear.
    function requestEval(expr) {
        var t = (expr || "").trim()
        if (t === "") {
            debounce.stop()
            evalProc.running = false
            liveResult = ""
            liveError = ""
            liveOk = false
            busy = false
            liveNum = ""
            liveDen = ""
            liveApprox = ""
            liveRatio = 0
            return
        }
        _wanted = t
        debounce.restart()
    }

    // ── Motor async (generación anti-race estilo Qalculator) ─────────
    property string _wanted: ""
    property int _seq: 0
    property int _activeSeq: -1
    property bool _gotLine: false
    readonly property string _bin: Qt.resolvedUrl("../bin/calc-eval").toString().replace("file://", "")

    Timer {
        id: debounce
        interval: 150; repeat: false
        onTriggered: {
            root._seq++
            root._activeSeq = root._seq
            root._gotLine = false
            root.busy = true
            evalProc.run(root._wanted, root._seq)
        }
    }

    Process {
        id: evalProc
        property string _expr: ""
        property int _seq: 0
        command: [root._bin, _expr]
        running: false
        stdout: SplitParser {
            onRead: line => root._onEvalLine(evalProc._seq, line)
        }
        onExited: root._onEvalExit(evalProc._seq)
        // Process estático con run(): evita que command sea reactivo.
        function run(expr, seq) {
            _seq = seq
            _expr = expr
            running = false
            running = true
        }
    }

    function _onEvalLine(seq, line) {
        if (seq !== _activeSeq) return // respuesta vieja: se ignora
        _gotLine = true
        var obj = null
        try { obj = JSON.parse(line) } catch (e) { obj = null }
        if (!obj) {
            liveResult = ""
            liveError = "Sin respuesta"
            liveOk = false
            liveNum = ""
            liveDen = ""
            liveApprox = ""
            liveRatio = 0
        } else if (obj.ok) {
            liveResult = obj.result || ""
            liveError = ""
            liveOk = liveResult !== ""
            liveNum = obj.num || ""
            liveDen = obj.den || ""
            liveApprox = obj.approx || ""
            liveRatio = obj.ratio || 0
        } else {
            liveResult = ""
            liveError = obj.error || "Expresión inválida"
            liveOk = false
            liveNum = ""
            liveDen = ""
            liveApprox = ""
            liveRatio = 0
        }
        busy = false
    }

    function _onEvalExit(seq) {
        if (seq !== _activeSeq || _gotLine) return
        liveResult = ""
        liveError = "Sin respuesta"
        liveOk = false
        liveNum = ""
        liveDen = ""
        liveApprox = ""
        liveRatio = 0
        busy = false
    }

    // Copia al portapapeles sin que la UI acceda al sistema.
    Process {
        id: _copyProc
        property string _text: ""
        command: ["wl-copy", _text]
        running: false
    }
    function copyText(text) {
        if ((text || "") === "") return
        _copyProc._text = text
        _copyProc.running = false
        _copyProc.running = true
    }
}
