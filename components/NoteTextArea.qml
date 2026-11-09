// NoteTextArea.qml — Textarea multilínea reutilizable (estilo Notas).
// Fondo + Flickable + TextEdit con placeholder y scrollbar. Ctrl+Enter
// emite accepted(); Ctrl+S emite saveRequested(); Escape emite
// escapePressed(). Tab inserta `tabSize` espacios (o sangra la selección
// con Shift+Tab); slashCommands y listContinuation son opt-in.
// Resaltado vía KSyntaxHighlighting: highlightFileName resuelve la
// definition por nombre de archivo (mime de shared-mime-info), con
// fallback a Markdown si syntaxHighlighting=true; highlightTheme elige el
// tema ("Atom One Dark" en Notas) o el default del sistema si no existe.
import QtQuick
import QtQuick.Controls
import org.kde.syntaxhighlighting as KSyntax
import "../state"

Rectangle {
    id: root

    property alias  text: input.text
    property alias  editField: input
    property string placeholderText: ""
    property real   fontSize: Config.fontSizeBodySm
    property string fontFamily: Config.uiFont
    property int    minHeight: 96
    property bool   showBorder: true
    property bool   tabInsertsSpaces: false
    property int    tabSize: 3
    // Slash commands de Notas ("/b " → **|**, "/c " → `|`, "/cjs " → bloque js)
    // y continuación de listas con Enter ("- algo" → "- ").
    property bool   slashCommands: false
    property bool   listContinuation: false
    property bool   syntaxHighlighting: false
    property string highlightFileName: ""
    // "" = tema por defecto; con texto, Repository.theme(nombre) si existe.
    property string highlightTheme: ""
    property bool   showLineNumbers: false
    property bool   highlightCurrentLine: false
    property real   contentMargin: 8
    onFontSizeChanged: Qt.callLater(updateGutter)

    signal accepted()
    signal saveRequested()
    signal escapePressed()

    readonly property string languageName: highlighter.definition ? highlighter.definition.name : "Texto plano"
    readonly property int lineCount: input.lineCount
    readonly property int currentLine: _currentLine

    property int _currentLine: 1
    property var _gutterLines: []
    property var _selRects: []

    function forceActiveFocus() { input.forceActiveFocus() }
    function clear() { input.text = "" }

    // ── Edición tipo editor de código ────────────────────────────────────────
    // Espacios de una tabulación (2 en Notas, 3 heredado para el resto).
    function _indentUnit() { return new Array(Math.max(1, root.tabSize) + 1).join(" ") }

    function _lineStartAt(pos) { return input.text.lastIndexOf("\n", pos - 1) + 1 }

    function _selMin() { return Math.min(input.selectionStart, input.selectionEnd) }
    function _selMax() { return Math.max(input.selectionStart, input.selectionEnd) }
    function _hasSelection() { return input.selectionStart !== input.selectionEnd }

    // Líneas completas que toca la selección (o el cursor si no hay).
    function _blockRange() {
        var t = input.text
        var s = _hasSelection() ? _selMin() : input.cursorPosition
        var e = _hasSelection() ? _selMax() : input.cursorPosition
        var start = t.lastIndexOf("\n", s - 1) + 1
        var stop  = t.indexOf("\n", e)
        // Selección que termina justo después de un salto de línea: la línea
        // siguiente no entra (el usuario no la seleccionó).
        if (e > s && e > 0 && t.charAt(e - 1) === "\n") stop = e - 1
        if (stop < 0) stop = t.length
        return { start: start, stop: stop }
    }

    // Indenta/desindenta las líneas de la selección (o la del cursor).
    function indentBlock(outdent) {
        var r = _blockRange()
        var block = input.text.slice(r.start, r.stop)
        if (block === "") return
        var pad = _indentUnit()
        var lines = block.split("\n")
        var deltaFirst = 0
        for (var i = 0; i < lines.length; i++) {
            if (outdent) {
                var n = 0
                while (n < pad.length && lines[i].charAt(n) === " ") n++
                if (n === 0 && lines[i].charAt(0) === "\t") n = 1
                lines[i] = lines[i].slice(n)
                if (i === 0) deltaFirst = -n
            } else {
                lines[i] = pad + lines[i]
                if (i === 0) deltaFirst = pad.length
            }
        }
        var nb = lines.join("\n")
        if (nb === block) return
        var hadSel = _hasSelection()
        var cur = input.cursorPosition
        input.remove(r.start, r.stop)
        input.insert(r.start, nb)
        if (hadSel) input.select(r.start, r.start + nb.length)
        else input.cursorPosition = Math.max(r.start, cur + deltaFirst)
    }

    // Envuelve la selección (o inserta el par y deja el cursor adentro).
    function wrapSelection(before, after) {
        var s = _selMin(), e = _selMax()
        if (s === e) {
            input.insert(input.cursorPosition, before + after)
            input.cursorPosition -= after.length
            return
        }
        var sel = input.text.slice(s, e)
        input.remove(s, e)
        input.insert(s, before + sel + after)
        input.select(s + before.length, s + before.length + sel.length)
    }

    // "/b ", "/c ", "/cjs ": se dispara con el espacio y deja el cursor
    // adentro del markup. Sin espacio, el texto queda como está.
    function trySlashCommand() {
        if (!root.slashCommands || _hasSelection()) return false
        var pos = input.cursorPosition
        var lineStart = _lineStartAt(pos)
        var before = input.text.slice(lineStart, pos)
        var m = before.match(/(^|\s)\/(b|i|c|cjs)$/)
        if (!m) return false
        var cmd = m[2]
        var start = pos - (cmd.length + 1)
        var repl = ""
        var inside = 0
        if (cmd === "b")        { repl = "****";       inside = 2 }
        else if (cmd === "i")   { repl = "**";         inside = 1 }
        else if (cmd === "c")   { repl = "``";         inside = 1 }
        else                    { repl = "```js\n\n```"; inside = 6 }
        input.remove(start, pos)
        input.insert(start, repl)
        input.cursorPosition = start + inside
        return true
    }

    // Enter en "  - algo" → nueva línea con el mismo prefijo; en un ítem
    // vacío ("- ") borra el marcador y deja la línea en blanco.
    function continueList() {
        if (!root.listContinuation || _hasSelection()) return false
        var pos = input.cursorPosition
        var lineStart = _lineStartAt(pos)
        var line = input.text.slice(lineStart, pos)
        var m = line.match(/^(\s*)([-*+]\s+|\d+[.)]\s+)(.*)$/)
        if (!m) return false
        if (m[3].trim() === "") {
            input.remove(lineStart, pos)
            input.cursorPosition = lineStart
            return true
        }
        var marker = m[2]
        if (/^\d/.test(marker))
            marker = marker.replace(/^\d+/, String(parseInt(marker, 10) + 1))
        input.insert(pos, "\n" + m[1] + marker)
        return true
    }

    // Números de línea: y real de cada inicio de línea (respeta wrap).
    // Además calcula rects de selección para líneas VACÍAS, que el
    // resaltado nativo no pinta (Shift+Up/Down las salteaba).
    function updateGutter() {
        var t = input.text
        var pre = t.slice(0, input.cursorPosition).split("\n").length
        if (root._currentLine !== pre) root._currentLine = pre
        var ys = [0]
        for (var i = 0; i < t.length; i++) {
            if (t.charAt(i) === "\n")
                ys.push(input.positionToRectangle(i + 1).y)
        }
        var sel = []
        if (input.selectionStart !== input.selectionEnd) {
            var s = Math.min(input.selectionStart, input.selectionEnd)
            var e = Math.max(input.selectionStart, input.selectionEnd)
            var startLine = t.slice(0, s).split("\n").length
            var endLine = t.slice(0, e).split("\n").length
            var lines = t.split("\n")
            for (var n = startLine; n <= endLine; n++) {
                if (n >= 1 && n <= lines.length && lines[n - 1] === "") {
                    var h = 0
                    if (n < ys.length) h = ys[n] - ys[n - 1]
                    else if (ys.length > 1) h = ys[ys.length - 1] - ys[ys.length - 2]
                    if (!(h > 0)) h = input.cursorRectangle.height
                    sel.push({ y: ys[n - 1], h: h })
                }
            }
        }
        root._selRects = sel
        if (!root.showLineNumbers) { root._gutterLines = []; return }
        var arr = []
        for (var k = 0; k < ys.length; k++) arr.push({ n: k + 1, y: ys[k] })
        root._gutterLines = arr
    }

    implicitHeight: minHeight
    radius: root.showBorder ? Style.radius_md : 0
    color: root.showBorder ? Style.surface_container_high : "transparent"
    border.color: !root.showBorder ? "transparent" : (input.activeFocus ? Style.primary : Style.outline_variant)
    border.width: !root.showBorder ? 0 : (input.activeFocus ? 1.5 : 1)

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: root.contentMargin
        clip: true
        contentHeight: input.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        // Sin drag del Flickable: le robaba el gesto al TextEdit y la
        // selección con mouse moría en la primera fila. La rueda sigue
        // scrolleando y el cursor se mantiene visible por followCursor.
        interactive: false
        onWidthChanged: Qt.callLater(root.updateGutter)

        // Gutter de números (en coords de contenido: scrollea solo).
        Item {
            visible: root.showLineNumbers
            x: 0; width: 36
            height: Math.max(input.implicitHeight, flick.height)
            Repeater {
                model: root._gutterLines
                delegate: Text {
                    required property var modelData
                    y: modelData.y
                    width: 28
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.weight: modelData.n === root.currentLine ? Config.fontWeightMedium : Font.Normal
                    color: modelData.n === root.currentLine ? Style.primary : Style.outline
                    text: modelData.n
                }
            }
        }

        // Resaltado de la línea actual (fondo sutil, a lo ancho total).
        Rectangle {
            visible: root.highlightCurrentLine && input.activeFocus
            x: 0
            y: input.cursorRectangle.y
            width: flick.width
            height: input.cursorRectangle.height
            color: Qt.alpha(Style.primary, 0.10)
        }

        TextEdit {
            id: input
            x: root.showLineNumbers ? 40 : 0
            width: flick.width - x
            // Llena el viewport: el click posiciona el cursor en cualquier
            // punto del área, no solo sobre el texto.
            height: Math.max(implicitHeight, flick.height)
            font.pixelSize: root.fontSize
            font.family: root.fontFamily
            color: Style.on_surface
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            selectionColor: Qt.alpha(Style.primary, 0.35)
            focus: true
            Keys.onEscapePressed: root.escapePressed()
            Keys.onPressed: (event) => {
                var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                // Ctrl+S: guardar (lo maneja el host vía saveRequested).
                if (ctrl && event.key === Qt.Key_S) {
                    root.saveRequested()
                    event.accepted = true
                    return
                }
                // Espacio: slash commands (se consume, no se inserta).
                if (root.slashCommands && event.key === Qt.Key_Space
                        && !ctrl && !(event.modifiers & Qt.AltModifier)) {
                    if (root.trySlashCommand()) { event.accepted = true; return }
                }
                if (ctrl) {
                    // Formato rápido (convención de editores de Markdown).
                    if (event.key === Qt.Key_B) { root.wrapSelection("**", "**"); event.accepted = true; return }
                    if (event.key === Qt.Key_I) { root.wrapSelection("*", "*"); event.accepted = true; return }
                    if (event.key === Qt.Key_K) { root.wrapSelection("`", "`"); event.accepted = true; return }
                    // Ctrl+> / Ctrl+] indentan; Ctrl+< / Ctrl+[ desindentan.
                    if (event.key === Qt.Key_Greater || event.key === Qt.Key_BracketRight) {
                        root.indentBlock(false); event.accepted = true; return
                    }
                    if (event.key === Qt.Key_Less || event.key === Qt.Key_BracketLeft) {
                        root.indentBlock(true); event.accepted = true; return
                    }
                }
            }
            Keys.onTabPressed: function(event) {
                // Solo NOTAS: Tab inserta espacios en el cursor (o indenta la
                // selección de varias líneas), sin mover el cursor de línea.
                if (!root.tabInsertsSpaces) return
                if (root._hasSelection() && input.selectedText.indexOf("\n") >= 0) {
                    root.indentBlock(false)
                } else {
                    var pos = input.cursorPosition
                    var pad = root._indentUnit()
                    input.insert(pos, pad)
                    input.cursorPosition = pos + pad.length
                }
                event.accepted = true
            }
            Keys.onBacktabPressed: function(event) {
                if (!root.tabInsertsSpaces) return
                if (root._hasSelection()) {
                    root.indentBlock(true)
                } else {
                    var pos = input.cursorPosition
                    var ls = input.text.lastIndexOf("\n", pos - 1) + 1
                    var unit = root._indentUnit()
                    var n = 0
                    while (n < unit.length && ls + n < pos && input.text.charAt(ls + n) === " ") n++
                    if (n === 0 && input.text.charAt(ls) === "\t") n = 1
                    if (n > 0) {
                        input.remove(ls, ls + n)
                        input.cursorPosition = Math.max(ls, pos - n)
                    }
                }
                event.accepted = true
            }
            Keys.onReturnPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier) {
                    root.accepted()
                    event.accepted = true
                    return
                }
                if (event.modifiers === Qt.NoModifier && root.continueList()) {
                    event.accepted = true
                    return
                }
                // Salto de línea explícito y consumido: ningún padre
                // lo roba (vale para sheet y Notes).
                input.insert(input.cursorPosition, "\n")
                event.accepted = true
            }
            // Sigue al cursor solo si sale de la vista (margen chico: con
            // 80px en un viewport de 80 el scroll se clavaba al fondo en
            // cada tecla y parecía que el texto "se iba al final").
            onCursorPositionChanged: Qt.callLater(function() {
                root.updateGutter()
                var cr = input.cursorRectangle
                var m = 8
                if (cr.y + cr.height > flick.contentY + flick.height)
                    flick.contentY = cr.y + cr.height - flick.height + m
                else if (cr.y < flick.contentY)
                    flick.contentY = Math.max(cr.y - m, 0)
            })
            onTextChanged: Qt.callLater(root.updateGutter)
            onSelectionStartChanged: Qt.callLater(root.updateGutter)
            onSelectionEndChanged: Qt.callLater(root.updateGutter)
            Component.onCompleted: Qt.callLater(root.updateGutter)
        }

        // Selección en líneas vacías: el nativo no las pinta (van arriba,
        // pero ahí no hay glifos que tapar). Mismo color que selectionColor.
        Repeater {
            model: root._selRects
            delegate: Rectangle {
                required property var modelData
                x: root.showLineNumbers ? 40 : 0
                y: modelData.y
                width: flick.width - x
                height: modelData.h
                color: Qt.alpha(Style.primary, 0.35)
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: root.showLineNumbers ? 40 : 0
            anchors.top: parent.top
            text: root.placeholderText
            font.pixelSize: root.fontSize
            font.family: Config.uiFont
            color: Style.outline
            visible: input.text === "" && !input.activeFocus
        }

        ScrollBar.vertical: ScrollBar {
            policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        // Rueda del mouse: Flickable tiene interactive:false para no robar
        // la selección del TextEdit, así que la rueda se maneja manual.
        // acceptedButtons: NoButton → clicks/selección pasan al TextEdit.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            cursorShape: Qt.IBeamCursor
            onWheel: (wheel) => {
                var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                if (delta === 0) return
                var maxY = Math.max(0, flick.contentHeight - flick.height)
                if (maxY <= 0) return
                flick.contentY = Math.max(0, Math.min(flick.contentY - delta * 0.4, maxY))
                wheel.accepted = true
            }
        }
    }

    // Resaltado estilo Kate según tipo de archivo (mime por nombre:
    // XML, Bash, QML, Markdown...). Solo display: el texto no cambia.
    // definition null = sin resaltar.
    function _definitionFor(fname) {
        if (fname !== "") {
            try {
                var f = KSyntax.Repository.definitionForFileName
                if (f) return KSyntax.Repository.definitionForFileName(fname)
            } catch (e) {}
        }
        return root.syntaxHighlighting ? KSyntax.Repository.definitionForName("Markdown") : null
    }

    // Tema del resaltado: highlightTheme por nombre ("Atom One Dark"); si no
    // existe, el default claro/oscuro del sistema.
    readonly property var _highlightTheme: {
        if (root.highlightTheme !== "") {
            var t = KSyntax.Repository.theme(root.highlightTheme)
            if (t && t.name !== "") return t
        }
        return KSyntax.Repository.defaultTheme(Style.dark ? KSyntax.Repository.DarkTheme : KSyntax.Repository.LightTheme)
    }

    KSyntax.SyntaxHighlighter {
        id: highlighter
        textEdit: input
        definition: root._definitionFor(root.highlightFileName)
        theme: root._highlightTheme
    }
}
