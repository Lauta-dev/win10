// PanelList.qml — Lista scrollable genérica con estilo del proyecto.
// Soporta estado vacío, estado cargando, navegación por teclado,
// y buscador opcional en la parte inferior.
//
// Uso mínimo:
//   PanelList {
//       model:    myArray
//       delegate: MyItemDelegate { required property var modelData }
//   }
//
// Con buscador:
//   PanelList {
//       model:       filteredArray
//       showSearch:  true
//       searchPlaceholder: "Buscar tareas…"
//       onSearchChanged: text => myFilter.apply(text)
//       delegate:    MyItemDelegate { required property var modelData }
//   }
//
// Con navegación de teclado:
//   PanelList {
//       id: panel
//       model:     filteredArray
//       showSearch: true
//       onItemActivated: index => doSomething(filteredArray[index])
//   }
//
// Estados vacío/cargando:
//   PanelList {
//       loading:        myProc.running
//       loadingIcon:    Icons.refresh   // default
//       loadingTitle:   "Cargando…"     // default
//       emptyIcon:      "󰄭"           // Nerd Font codepoint
//       emptyTitle:     "Sin tareas"
//       emptySubtitle:  "Todo listo"
//       emptySearchTitle:    "Sin resultados"
//       emptySearchSubtitle: "Intentá otra búsqueda"
//   }

import QtQuick
import "../state"

Item {
    id: root

    // ── API — datos ───────────────────────────────────────────────────────────
    property var    model:    []
    property bool   loading:  false

    // ── API — márgenes del body ──────────────────────────────────────────────
    property int bodyTopMargin:    8
    property int bodyBottomMargin: 8
    property int bodyLeftMargin:   12
    property int bodyRightMargin:  12

    // ── API — buscador ────────────────────────────────────────────────────────
    property bool   showSearch:        false
    property string searchPlaceholder: "Buscar…"
    property string searchText:        ""      // bindable desde afuera si se necesita
    property bool   passwordMode:      false
    // Contador "actual / total" al lado del buscador (opt-in por vista).
    property bool   showSearchCounter: false
    // Fondo del buscador (opt-in por vista).
    property color  searchBgColor: Style.surface_container_low

    signal searchChanged(string text)
    signal searchEmptyBackspace()

    // ── API — estado vacío ────────────────────────────────────────────────────
    property string emptyIcon:           Icons.emptyState
    property string emptyTitle:          "Sin entradas"
    property string emptySubtitle:       "La lista está vacía"
    property string emptySearchTitle:    "Sin resultados"
    property string emptySearchSubtitle: "Intentá otra búsqueda"
    // Acciones del vacío: [{label, icon}] → EmptyState.actionTriggered
    property var    emptyActions:        []
    signal emptyActionTriggered(int index)

    // ── API — estado cargando (EmptyState, como el vacío) ───────────────────
    property string loadingIcon:  Icons.refresh
    property string loadingTitle: "Cargando…"

    // ── API — navegación de teclado ───────────────────────────────────────────
    property bool inverted: true // true = BottomToTop (command palette), false = TopToBottom (playlist)
    signal itemActivated(int index)

    // ── API — delegate ────────────────────────────────────────────────────────
    property Component delegate

    // ── API — comportamiento de índice ───────────────────────────────────────
    property bool preserveIndexOnModelChange: false

    // ── API — highlight animado tipo macOS ──────────────────────────────────
    property int  highlightDuration: 150
    property real highlightMargin: 4
    // Acento del highlight (default: tema global). El palette MPD lo
    // sobreescribe con el color del cover.
    property color accent: Style.primary
    // Fondo del foco por teclado (default: pill M3 sólida). El palette MPD
    // pasa un tinte más visible.
    property color highlightBg: Style.secondary_container

    // ── Acceso externo ────────────────────────────────────────────────────────
    readonly property int _count: root.model ? (root.model.count !== undefined ? root.model.count : root.model.length) : 0

    function forceSearchFocus() { if (showSearch) searchInput.forceActiveFocus() }
    function moveUp() {
        if (_count === 0) return
        if (inverted) listView.incrementCurrentIndex()
        else          listView.decrementCurrentIndex()
    }
    function moveDown() {
        if (_count === 0) return
        if (inverted) listView.decrementCurrentIndex()
        else          listView.incrementCurrentIndex()
    }
    function activate() {
        if (listView.currentIndex >= 0 && listView.currentIndex < _count)
            root.itemActivated(listView.currentIndex)
    }
    function resetNav() {
        if (_count > 0) {
            if (listView.currentIndex < 0 || listView.currentIndex >= _count) listView.currentIndex = 0
        } else {
            listView.currentIndex = -1
        }
    }
    function selectFirst()      { if (_count > 0) listView.currentIndex = 0 }
    function selectIndex(idx) {
        if (idx >= 0 && idx < _count) {
            listView.currentIndex = idx
        }
    }
    function clearSearch()      { searchInput.clear(); root.searchText = "" }

    // ── Foco inicial + type-to-focus (compartido por todas las vistas) ───────
    // focusInitial(): con texto, foco al buscador; vacío, foco a la lista
    // para que la primera tecla la despierte sin resaltar el input.
    function focusInitial() {
        if (root.searchText !== "") forceSearchFocus()
        else root.forceActiveFocus()
    }
    function typeToSearch(text) {
        forceSearchFocus()
        searchInput.appendText(text)
    }

    // Estos handlers solo actúan con foco en la lista (no en el input):
    // con el input enfocado, sus propios handlers aceptan primero.
    // Escape no se toca acá: cada vista decide (cerrar, salir de subvista…).
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) return
        if (event.text.length > 0 && !(event.modifiers & Qt.ControlModifier)
                && event.key !== Qt.Key_Backspace && event.key !== Qt.Key_Delete) {
            typeToSearch(event.text)
            event.accepted = true
        }
    }
    Keys.onUpPressed:     { if (!searchInput.hasFocus) root.moveUp() }
    Keys.onDownPressed:   { if (!searchInput.hasFocus) root.moveDown() }
    Keys.onReturnPressed: { if (!searchInput.hasFocus) root.activate() }

    // ── Layout ────────────────────────────────────────────────────────────────
    Item {
        id: body
        anchors {
            top: parent.top; topMargin: root.bodyTopMargin
            bottom: showSearch ? searchInput.top : parent.bottom
            bottomMargin: root.bodyBottomMargin
            left: parent.left; right: parent.right
            leftMargin: root.bodyLeftMargin; rightMargin: root.bodyRightMargin
        }
        clip: true

        // Estado cargando
        EmptyState {
            anchors.centerIn: parent
            width: parent.width
            height: 220
            visible: root.loading
            icon: root.loadingIcon
            title: root.loadingTitle
        }

        // Estado vacío
        EmptyState {
            anchors.centerIn: parent
            width: parent.width
            height: 220
            visible: !root.loading && (!root.model || (root.model.count !== undefined ? root.model.count : root.model.length) === 0)
            icon: root.emptyIcon
            title: root.searchText.trim() !== "" ? root.emptySearchTitle : root.emptyTitle
            subtitle: root.searchText.trim() !== "" ? root.emptySearchSubtitle : root.emptySubtitle
            actions: root.searchText.trim() !== "" ? [] : root.emptyActions
            onActionTriggered: idx => root.emptyActionTriggered(idx)
        }

        // Lista
        ListView {
            id: listView
            anchors.fill: parent
            visible: !root.loading && !!root.model && (root.model.count !== undefined ? root.model.count : root.model.length) > 0
            clip:           true
            boundsBehavior: Flickable.StopAtBounds
            verticalLayoutDirection: root.inverted ? ListView.BottomToTop : ListView.TopToBottom
            topMargin:    6
            bottomMargin: 6
            spacing:      4
            cacheBuffer:  150
            model:        root.model

            property bool keyboardActive: false

            onModelChanged: {
                if (root.preserveIndexOnModelChange) {
                    var count = root.model ? (root.model.count !== undefined ? root.model.count : root.model.length) : 0
                    if (count > 0 && currentIndex >= 0 && currentIndex < count) return
                    currentIndex = count > 0 ? 0 : -1
                } else {
                    currentIndex = 0
                }
            }
            // Slide del highlight al cambiar de ítem (0 = instantáneo).
            highlightFollowsCurrentItem: true
            highlightMoveDuration: root.highlightDuration
            highlightResizeDuration: root.highlightDuration

            highlight: Item {
                // Pill M3 sólida.
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: root.highlightBg
                }
            }

            delegate: root.delegate
        }
    }

    // Buscador (opcional)
        SmartSearchInput {
            id: searchInput
            visible: root.showSearch
        anchors {
            bottom: parent.bottom; bottomMargin: 10
            left: parent.left; right: parent.right
            leftMargin: 10; rightMargin: 10
        }
        height:      root.showSearch ? 44 : 0
        placeholder: root.searchPlaceholder
        passwordMode: root.passwordMode
        bgColor:     root.searchBgColor
        text:        root.searchText

        onQueryChanged: text => {
            root.searchText = text
            root.searchChanged(text)
        }
        onUpPressed:        root.moveUp()
        onDownPressed:      root.moveDown()
        onReturnPressed:    root.activate()
        onEmptyBackspace:   root.searchEmptyBackspace()
        counterText: root.showSearchCounter
            ? (root._count > 0 ? (listView.currentIndex + 1) + " / " + root._count : "0 / 0")
            : ""
    }

    // Exponer el ListView para casos avanzados
    readonly property alias listView:     listView
    readonly property alias currentIndex: listView.currentIndex
    readonly property alias searchInput:  searchInput
    property alias bodyOpacity:  body.opacity
}
