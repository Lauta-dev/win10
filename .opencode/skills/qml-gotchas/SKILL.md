---
name: qml-gotchas
description: Bugs recurrentes de QML/Quickshell en esta shell y su patrón correcto. Usar ante flashes de color en hover/click, popups que saltan al animar altura, clicks que no responden o se duplican, o máscaras (Region) que no siguen al contenido.
---

# Trampas QML de la shell

## 1. Flash de color en hover/click
`ColorAnimation` entre `"transparent"` (o `Qt.alpha(c, 0)`) y un color con RGB distinto interpola por un gris.
```qml
// ✅ mismo RGB, solo cambia alpha
color: ph ? Qt.rgba(1,1,1, Config.dark ? 0.07 : 0.04) : Qt.rgba(1,1,1, 0)
Behavior on color { ColorAnimation { duration: 80 } }
// ✅ o animar opacity de un Rectangle con color fijo
```

## 2. Pulso al clickear tiles con estado activo
Un solo `Rectangle` con `opacity: tileActive ? 1 : ph ? .5 : 0` hace competir hover y active. Usar base fija + dos overlays independientes:
```qml
Rectangle { /* hover  */ opacity: ph && !tileActive ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 100 } } }
Rectangle { /* active */ opacity: tileActive ? 1 : 0;        Behavior on opacity { NumberAnimation { duration: 150 } } }
```

## 3. Salto al animar la altura de un popup
Bindear `implicitHeight` al contenido redimensiona la superficie layer-shell por frame y labwc lo aplica a saltos. Superficie fija; anima un wrapper (patrón de `ControlCenterNew`):
```qml
implicitHeight: Screen.height - Config.taskbarHeight - 20      // fija
Item { id: wrapper; anchors.bottom: parent.bottom
       height: root.visualHeight
       Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } } }
```

## 4. Click-through (doble acción)
Un `MouseArea` que actúa en `onPressed` sobre una celda con `TapHandler` dispara ambos (el TapHandler pasivo observa igual). Con capas superpuestas, todo `MouseArea` + `onClicked`; nunca `TapHandler` debajo. `grabPermissions` y cooldowns no lo arreglan.

## 5. Máscara congelada (`Region { item: x }`)
`item:` toma la geometría al crearse; si nace vacío (lista con 0 ítems), la máscara queda enana y el popup no responde a hover/click. Usar rect explícito bindeado (ver `components/WipePopupShell.qml`):
```qml
Region { id: listMask
  x: Math.round((root.implicitWidth - root.toastWidth) / 2)
  y: Math.round(root.implicitHeight - notifList.height)
  width: root.toastWidth; height: notifList.height }
mask: notifList.count > 0 ? listMask : emptyMask
```
Un wrapper que nace a tamaño final sí puede usar `item:`.
