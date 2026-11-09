// ClipDelegate.qml — Delegate del clipboard (buscar + pegar).
// Wrapper fino sobre ClipItemDelegate. Emite copyRequested al activar.

import QtQuick
import "../../state"
import "."

Item {
    property var  itemData:  ({})
    property int  itemIndex: 0
    property bool isSelected: false
    property int  panelWidth: 520

    signal copyRequested(var entry)

    // Altura en sync con ClipItemDelegate (banner 186 / fila 56).
    height: (itemData.isImage === true && (itemData.raw ?? "") !== "") ? 186 : 56

    ClipItemDelegate {
        id: delegate
        anchors.fill: parent
        entry:       itemData
        itemHeight:  parent.height
        highlighted: isSelected
        onCopyRequested: copyRequested(itemData)
    }
}
