// AppMenuView.qml — Vista appmenu: buscar + abrir. Sin submenús:
// sin navegación por categorías, sin prefix nav. Filtra por nombre/comentario
// y lanza con Enter o click (derecho pineea). Con ">" adelante corren los
// comandos del menú (">b", ">ia", ">sf"), ver StartmenuState.

import QtQuick
import ".."
import "../../state"

Item {
    id: root

    signal closeRequested()

    // Al abrir solo se refresca el modelo reaplicando el filtro vigente.
    function enter() {
        StartmenuState.reloadApps()
        StartmenuState.refreshSearchIndex()
        StartmenuState.filterApps(list.searchText)
    }

    function focusSearch() { list.forceSearchFocus() }
    function clearSearch() { list.clearSearch() }

    // Foco inicial y type-to-focus viven en PanelList (compartido);
    // acá solo el cierre con Escape.
    function focusInitial() { list.focusInitial() }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        }
    }

    PanelList {
        id: list
        anchors.fill: parent
        model: StartmenuState.filteredApps
        showSearch: true; searchPlaceholder: "Buscar aplicaciones…"
        inverted: true; highlightDuration: 180
        highlightBg: Qt.alpha(Style.primary, 0.1)
        // Apps flush: sin separación entre filas.
        listView.spacing: 0
        emptyIcon: Icons.question
        emptyTitle: "Sin resultados"
        emptySubtitle: "Intentá otra búsqueda"
        emptySearchTitle: "Sin resultados"
        emptySearchSubtitle: "Intentá otra búsqueda"
        onSearchChanged: text => {
            // Texto crudo: ">" activa los comandos del menú.
            StartmenuState.pendingFilter = text
            StartmenuState.applyPendingFilter()
        }
        onItemActivated: index => {
            var m = StartmenuState.filteredApps; if (!m || index < 0) return
            var item = m.get ? m.get(index) : m[index]; if (!item) return
            StartmenuState.activateItem(item)
        }

        searchInput.onEscapePressed: {
            if (list.searchText === "") root.closeRequested()
            else list.clearSearch()
        }
        searchInput.onSuperPressed: root.closeRequested()

        delegate: AppDelegate {
            width: ListView.view ? ListView.view.width : parent.width
            itemData: modelData
            itemIndex: index
            isSelected: list.currentIndex === index
            panelWidth: root.width
            onAppLaunched: app => StartmenuState.activateItem(app)
            onPinRequested: app => TaskbarState.togglePinSmart(app.id)
        }
    }
}
