import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../state"

Item {
    id: root

    signal backToRoot()
    signal backToMain()
    signal closeRequested()
    signal focusWrapper()
    // ── Aside estilo sheet: el Hub dueña el abierto/cerrado ──
    // (formOpen), la vista solo pide y reporta.
    signal toggleFormRequested()
    signal closeFormRequested()
    signal formSaved(var form)
    signal formEditRequested(var item)
    signal formCancelled()

    property bool active: false
    // Entrada: el Hub la bindea a su flag (como sheet formOpen).
    property bool formOpen: false

    // Aside del form: ancho animado (360 abierto, 0 cerrado).
    property real _formW: root.formOpen ? 360 : 0

    readonly property bool locked: !KeePassState.isUnlocked
    readonly property bool adding: KeePassState.addingEntry
    readonly property bool totpInput: KeePassState.enteringTotp
    readonly property bool delConfirm: KeePassState.pendingDel !== ""

    // ── Header M3: titular según estado + guía de uso ──
    readonly property string _headTitle: {
        if (root.adding) return KeePassState.editingEntry ? "Editar entrada" : "Nueva entrada"
        if (root.delConfirm) return "Eliminar entrada"
        if (root.totpInput) return "Verificación en dos pasos"
        return "Contraseñas"
    }
    readonly property string _headSub: {
        if (root.locked) return "Ingresá la contraseña y presioná Enter"
        if (root.adding) return KeePassState.editingEntry ? "Modificá los campos y guardá" : "Completá los campos y guardá"
        if (root.delConfirm) return KeePassState.pendingDel
        if (root.totpInput) return "Pegá el secreto o dejá vacío para generar"
        return "Buscá para filtrar"
    }

    function enter() {
        KeePassState.leaveDetail()
        KeePassState.closeAddForm()
        KeePassState.cancelTotpInput()
        KeePassState.cancelDel()
        if (KeePassState.isUnlocked) KeePassState.filterEntries("")
        list.clearSearch()
        Qt.callLater(function() { list.forceSearchFocus(); list.selectFirst() })
    }

    function moveUp() { list.moveUp() }
    function moveDown() { list.moveDown() }
    function activateCurrent() { list.activate() }
    function appendText(t) { list.forceSearchFocus(); list.searchInput.appendText(t) }
    function focusSearch() { list.forceSearchFocus() }

    function submitPassword() {
        var pwd = list.searchText
        list.clearSearch()
        KeePassState.unlock(pwd)
    }

    function escapeInSearch() {
        if (root.adding) cancelAdd()
        else if (root.delConfirm) {
            if (list.searchText === "") cancelDel()
            else list.clearSearch()
        } else if (root.totpInput) {
            if (list.searchText === "") cancelTotp()
            else list.clearSearch()
        } else if (list.searchText === "") {
            if (TaskbarState.rootLocked) root.closeRequested()
            else root.backToRoot()
        } else {
            list.clearSearch()
        }
    }

    function leaveDetail() {
        KeePassState.leaveDetail()
        list.clearSearch()
        KeePassState.filterEntries("")
        Qt.callLater(function() { list.selectFirst(); list.forceSearchFocus() })
    }

    // API para el Hub (el flag formOpen lo pone el Hub; acá solo UI).
    // No tocan la lista: la selección y el scroll quedan donde estaban.
    function openForm() {
        Qt.callLater(function() { addForm.open("") })
    }
    function openFormEdit(item) {
        var full = KeePassState.findFullEntry(item)
        KeePassState.openEditForm(full)
        Qt.callLater(function() { addForm.openForEdit(full) })
    }
    function routeView(item, act) {
        if (act === KeePassState.resClear) list.clearSearch()
        else if (act === KeePassState.resOpenEdit) root.formEditRequested(item)
    }
    // Al cerrar el aside la lista no se toca: vuelve el foco sin
    // mover selección ni scroll.
    function cancelAdd() {
        KeePassState.closeAddForm()
        Qt.callLater(function() { list.forceSearchFocus() })
    }
    function cancelTotp() {
        KeePassState.cancelTotpInput()
        list.clearSearch()
        Qt.callLater(function() { list.selectFirst(); list.forceSearchFocus() })
    }
    function cancelDel() {
        KeePassState.cancelDel()
        Qt.callLater(function() { list.forceSearchFocus() })
    }

    Connections {
        target: KeePassState
        function onIsUnlockedChanged() {
            if (!root.active || !KeePassState.isUnlocked) return
            Qt.callLater(function() {
                list.selectFirst()
                list.forceSearchFocus()
            })
        }
        // Cierre del aside (cancel o guardado): solo vuelve el foco.
        // El selectFirst al tipear ya lo hace onSearchChanged.
        function onAddingEntryChanged() {
            if (!root.active || KeePassState.addingEntry) return
            Qt.callLater(function() { list.forceSearchFocus() })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header M3: círculo tonal + dos líneas + chip de estado ──
        // Siempre visible: bloqueada o no.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16; Layout.rightMargin: 16
            Layout.topMargin: 12; Layout.bottomMargin: 8
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignVCenter
                radius: 22
                color: root.locked ? Style.error_container : Style.primary_container
                Text {
                    anchors.centerIn: parent
                    text: root.locked ? Icons.lock : Icons.unlock
                    font.pixelSize: 22; font.family: Icons.font
                    color: root.locked ? Style.on_error_container : Style.on_primary_container
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: root._headTitle
                    font.pixelSize: Config.fontSizeHeadline; font.weight: Config.fontWeightBold
                    font.family: Config.uiFont
                    color: Style.on_surface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    Layout.fillWidth: true
                    text: root._headSub
                    font.pixelSize: Config.fontSizeBodySm; font.family: Config.uiFont
                    color: Style.on_surface_variant
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Añadir entrada (el Hub abre el aside)
            PillButton {
                visible: !root.locked && !root.adding
                Layout.alignment: Qt.AlignVCenter
                size: 36
                icon: Icons.add
                label: "Nueva"
                active: root.formOpen
                onClicked: root.toggleFormRequested()
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: _pillTxt.implicitWidth + 24
                Layout.preferredHeight: 32
                radius: 16
                color: Style.secondary_container
                Text {
                    id: _pillTxt
                    anchors.centerIn: parent
                    text: root.locked ? "Bloqueada" : KeePassState.entries.length + (KeePassState.entries.length === 1 ? " entrada" : " entradas")
                    font.pixelSize: Config.fontSizeLabelSm; font.weight: Config.fontWeightMedium
                    font.family: Config.uiFont
                    color: Style.on_secondary_container
                }
            }
        }

    PanelList {
        id: list
        Layout.fillWidth: true; Layout.fillHeight: true
        // Siempre visible: con el aside abierto queda de fondo (patrón sheet).
        model: KeePassState.visibleRows(list.searchText)
        loading: KeePassState.loading
        showSearch: true; searchPlaceholder: KeePassState.placeholderFor(list.searchText)
        searchBgColor: Style.surface_container
        passwordMode: root.locked
        inverted: true; highlightDuration: 0
        preserveIndexOnModelChange: true
        highlightBg: Qt.alpha(Style.primary, 0.1)
        emptyIcon: root.locked ? Icons.lock : Icons.question
        emptyTitle: root.locked ? "Base de datos bloqueada" : "Sin resultados"
        emptySubtitle: root.locked ? "Ingresá la contraseña y presioná Enter" : "Intentá otra búsqueda"
        emptySearchTitle: root.locked ? "Base de datos bloqueada" : "Sin resultados"
        emptySearchSubtitle: root.locked ? "Ingresá la contraseña y presioná Enter" : "Intentá otra búsqueda"
        onSearchEmptyBackspace: root.focusWrapper()
        onSearchChanged: text => {
            if (KeePassState.handleSearch(text)) Qt.callLater(function() { list.selectFirst() })
        }
        onItemActivated: index => {
            // Con el drawer de borrado abierto el teclado no toca la lista.
            if (root.delConfirm) return
            var m = KeePassState.visibleRows(list.searchText); if (!m || index < 0) return
            var item = m.get ? m.get(index) : m[index]; if (!item) return
            root.routeView(item, KeePassState.activateItem(item, list.searchText))
        }

        searchInput.onEscapePressed: {
            if (root.adding) {
                root.cancelAdd()
            } else if (root.delConfirm) {
                root.cancelDel()
            } else if (root.totpInput) {
                if (list.searchText === "") root.cancelTotp()
                else list.clearSearch()
            } else if (list.searchText === "") {
                if (TaskbarState.rootLocked) root.closeRequested()
                else root.backToRoot()
            } else list.clearSearch()
        }
        searchInput.onSuperPressed: root.closeRequested()
        searchInput.onBackspaceOnEmpty: {
            if (root.adding) root.cancelAdd()
            else if (root.delConfirm) root.cancelDel()
            else if (root.totpInput) root.cancelTotp()
            else if (!TaskbarState.rootLocked) root.backToRoot()
        }
        searchInput.onReturnPressed: {
            if (root.locked && !KeePassState.loading) root.submitPassword()
        }

        delegate: Loader {
            width: ListView.view ? ListView.view.width : parent.width
            required property var modelData; required property int index

            sourceComponent: {
                if (root.totpInput) return keepassDetailDelegate
                return keepassDelegate
            }
            Binding { target: item; property: "itemData"; value: modelData; when: status === Loader.Ready }
            Binding { target: item; property: "itemIndex"; value: index; when: status === Loader.Ready }
            Binding { target: item; property: "isSelected"; value: list.currentIndex === index; when: status === Loader.Ready }
            Binding { target: item; property: "accent"; value: Style.primary; when: status === Loader.Ready && item && item.hasOwnProperty("accent") }
            Binding { target: item; property: "textAccent"; value: Style.primary; when: status === Loader.Ready && item && item.hasOwnProperty("textAccent") }
            Binding { target: item; property: "hoverColor"; value: Style.surface_container_highest; when: status === Loader.Ready && item && item.hasOwnProperty("hoverColor") }
            Binding { target: item; property: "useAccent"; value: false; when: status === Loader.Ready && item && item.hasOwnProperty("useAccent") }
        }
    }

    } // ← columna: header + lista

    // ── Scrim del form (patrón sheet): velo + cierra al click fuera ──
    MouseArea {
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.formOpen ? 1 : 0
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.closeFormRequested()
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
        }
    }
    // ── Aside de alta/edición: flota a la derecha sobre la lista ──
    // Se recorta a la derecha al cerrar.
    Item {
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.topMargin: 12; anchors.bottomMargin: 12; anchors.rightMargin: 12
        width: root._formW
        visible: root._formW > 0 || root.formOpen
        clip: true
        Rectangle {
            anchors.fill: parent
            color: Style.surface_container_low
            radius: 12
            border.color: Style.outline_variant; border.width: 1
        }
        // Fondo: traga clicks en padding/gaps (si no, caen al
        // scrim y cierran el form). Antes del form para no tapar inputs.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: true
            onPressed: {}
        }
        CpKeepassAddForm {
            id: addForm
            anchors.fill: parent
            anchors.margins: 12
            onVisibleChanged: if (!visible) clearSecrets()
            onSaved: form => root.formSaved(form)
            onCancelled: root.formCancelled()
        }
    }

    // ── Drawer de borrado (Drawer reutilizable) ──
    Drawer {
        anchors.fill: parent
        open: root.delConfirm
        sheetHeight: 236
        sheetWidth: 520
        title: "Eliminar entrada"
        onClosed: root.cancelDel()

        Text {
            Layout.fillWidth: true
            text: KeePassState.pendingDel
            font.pixelSize: Config.fontSizeBody; font.weight: Config.fontWeightMedium
            font.family: Config.uiFont; color: Style.on_surface
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: "No se puede deshacer"
            font.pixelSize: Config.fontSizeBodySm; font.family: Config.uiFont
            color: Style.on_surface_variant
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }
            PillButton {
                label: "Cancelar"
                customRadius: 10
                onClicked: root.cancelDel()
            }
            PillButton {
                label: "Eliminar"
                customRadius: 10
                customContainerColor: Style.error_container
                customTextColor: Style.on_error_container
                onClicked: {
                    KeePassState.confirmDel()
                }
            }
        }
    }

    Component { id: keepassDelegate; CpKeepassDelegate {
        panelWidth: root.width
        onEntryActivated: entry => root.routeView(entry, KeePassState.activateItem(entry, list.searchText))
        onEditRequested: entry => root.formEditRequested(entry)
        onDelRequested: entry => KeePassState.startDel(entry.path)
        onCopyRequested: (kind, entry) => {
            if (kind === KeePassState.kindUser) KeePassState.copyUser(entry.path)
            else if (kind === KeePassState.kindPassword) KeePassState.copyPassword(entry.path)
            else if (kind === KeePassState.kindTotp) KeePassState.copyTotp(entry.path)
        }
    } }
    Component { id: keepassDetailDelegate; CpKeepassDetailDelegate {
        panelWidth: root.width
        onActionTriggered: id => root.routeView(null, KeePassState.dispatchAction(id, list.searchText))
    } }
}
