// ClipView.qml — Vista clipboard: buscar + pegar.
// Filtra el listado completo de cliphist en memoria.

import QtQuick
import ".."
import "../../state"

Item {
    id: root

    signal escapeEmpty()

    function enter() {
        ClipboardState.reload()
    }

    function focusSearch() { list.forceSearchFocus() }
    function focusInitial() { list.focusInitial() }
    function clearSearch() { list.clearSearch() }

    // Escape con foco en la lista (input vacío): igual que input vacío.
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.escapeEmpty()
            event.accepted = true
        }
    }

    PanelList {
        id: list
        anchors.fill: parent
        model: ClipboardState.visibleResults
        loading: ClipboardState.loading
        showSearch: true; searchPlaceholder: "Buscar en portapapeles…"
        showSearchCounter: true
        inverted: true; highlightDuration: 180
        highlightBg: Qt.alpha(Style.primary, 0.1)
        // Filas flush: sin separación entre entradas.
        listView.spacing: 0
        emptyIcon: Icons.clipboard
        emptyTitle: "Portapapeles vacío"
        emptySubtitle: "Copiá algo para verlo acá"
        emptySearchTitle: "Sin resultados"
        emptySearchSubtitle: "Intentá otra búsqueda"
        onSearchChanged: text => {
            ClipboardState.searchQuery = text
        }
        onItemActivated: index => ClipboardState.activateAt(index)

        searchInput.onEscapePressed: {
            if (list.searchText === "") root.escapeEmpty()
            else list.clearSearch()
        }
        searchInput.onSuperPressed: root.escapeEmpty()

        delegate: Loader {
            // Altura en sync con ClipItemDelegate (banner 186 / fila 56).
            height: (modelData.isImage === true && (modelData.raw ?? "") !== "") ? 186 : 56
            width: ListView.view ? ListView.view.width : parent.width
            required property var modelData; required property int index

            sourceComponent: clipDelegate
            Binding { target: item; property: "itemData"; value: modelData; when: status === Loader.Ready }
            Binding { target: item; property: "itemIndex"; value: index; when: status === Loader.Ready }
            Binding { target: item; property: "isSelected"; value: list.currentIndex === index; when: status === Loader.Ready }
        }
    }

    Component { id: clipDelegate; ClipDelegate {
        panelWidth: root.width
        onCopyRequested: entry => ClipboardState.pasteClip(entry)
    } }

    // Prefetch: al llegar a los últimos `prefetchAt` de la ventana,
    // se cargan 50 más.
    Connections {
        target: list.listView
        function onCurrentIndexChanged() {
            var idx = list.currentIndex
            if (idx >= 0 && ClipboardState.hasMore
                    && idx >= ClipboardState.visibleResults.length - ClipboardState.prefetchAt)
                ClipboardState.loadMore()
        }
    }
}
