---
name: qs-animations
description: >-
  Patrones de animación para esta taskbar QuickShell + QML: apertura/cierre de
  popups (wipe de WipePopupShell/PanelPopupHost, fade+scale de menús del CC), highlight de
  listas (PanelList), hovers y transiciones de estado, y diagnóstico de "la
  animación no se ve" (Behaviors que no disparan, easings imperceptibles,
  timing de creación del popup). Usar SIEMPRE que se agregue, ajuste o revise
  una animación o transición en QML/QuickShell, cuando un popup deba abrir o
  cerrar animado, al elegir duration/easing, o cuando el usuario diga que algo
  "no se anima", "no se desliza", "salta" o "se siente brusco" — aunque no
  mencione la palabra animación.
---

# Animaciones en QuickShell (QML)

Esta skill asume las convenciones de `.opencode/skills/project/` y el estilo de `components/` (colores/medidas vía `Style`/`Config`). Para reglas generales de Qt (Animator types, costo de `ShaderEffect`, etc.) está la skill `qt-qml`.

## Principios

1. **Opt-in y livianas.** El repo ya apagó globalmente las animaciones una vez por GPU débil (commit `61a66ad` "Experimento: quita todas las animaciones visuales"). Toda animación nueva debe poder desactivarse (prop `animated`, `duration: 0`, `enabled`) y no debe repintar superficies grandes por frame si no hace falta.
2. **Se percibe o no existe.** Una animación de reveal con easing front-loaded (`OutQuint`, `OutExpo`) y ~200ms en una superficie oscura se ve como un salto instantáneo. Ver "Duraciones y easings".
3. **Animar presentación, no require layout.** Preferir `opacity`, `scale`, `y`, `x`. Animar `width`/`height` de subárboles complejos relayouta todo por frame; permitido solo cuando el hijo tiene tamaño fijo (patrón wipe, más abajo).
4. **La animación no puede depender de estado que todavía no existe.** Si el popup se crea justo cuando se abre, el primer frame nace en el valor final si no se usa el gate `_animReady` (ver WipePopupShell).

## Tipos disponibles

QtQuick: `NumberAnimation`, `PropertyAnimation`, `ColorAnimation`, `Behavior` (default animation de una propiedad), `States`+`Transition`, `SequentialAnimation`/`ParallelAnimation`, `SpringAnimation`/`SmoothedAnimation` (feedback interactivo), `PauseAnimation`/`ScriptAction`, `Animator`* (`OpacityAnimator`, `ScaleAnimator`, `XAnimator`…).

Quickshell: `EasingCurve` (import `Quickshell`) expone curvas de easing (`curve`, `interpolate()`, `valueAt()`) para interpolar en JS cuando no se puede usar un `Behavior`.

**`Animator`* vs `Behavior`+`NumberAnimation`:** los `Animator` corren en el render thread (más baratos) pero **no actualizan el valor de la propiedad en el motor QML durante la animación** — si un binding, un `clip` o una altura dependen del valor intermedio, el Animator no sirve. En ese caso usar `Behavior` + `NumberAnimation` (como el wipe). Usar Animator solo para propiedades "hoja" (`opacity`, `scale`) que nadie más lee.

## Patrón A — apertura/cierre de popups (WipePopupShell)

`components/WipePopupShell.qml` encapsula el wipe vertical: la superficie layer-shell queda estática y el contenido se descubre con un clip que crece desde la barra. API relevante:

- `animated: false` por defecto; lo prende el host (`PanelPopupHost.qml`, `NotificationPopup.qml`, `OsdSliderPopup.qml`).
- `openMs` / `closeMs` los define el host. En los paneles grandes vienen por panel desde `_CONFIGS` de `PanelPopupHost` (launcher 320/240, jumplist 300/300, music 240/200, CC 320/240); `NotificationPopup` usa 250/200.
- `openProgress: (isOpen && !_hiding) ? 1 : 0` con `Behavior ... enabled: shell.animated`. La dirección se lee de `isOpen` (ya cambió cuando arranca la animación), no de `_hiding`.
- `_animReady` + `Component.onCompleted: Qt.callLater(...)` garantiza que el primer abierto también anime (el popup suele crearse cuando el flag se pone en true; sin el gate el primer frame nace en progreso 1).
- Al cerrar, `_hiding` mantiene el contenido visible `closeMs` (Timer) para que la reversa se vea antes de desmontar.
- El `mask` (`isOpen ? boxMask : emptyMask`) solo controla input, no visuales — no hace falta animarlo.

```qml
// Wipe con clip (dentro de WipePopupShell)
Item {
    anchors.bottom: parent.bottom
    width: parent.width
    height: Math.max(parent.height * shell.openProgress, 0.01)
    clip: true
    Item { // contenido a tamaño REAL, anclado abajo: el wipe lo descubre
        anchors.bottom: parent.bottom
        width: shell.contentWidth
        height: shell.contentHeight
    }
}
```

Para un popup nuevo con superficie propia: no reimplementar el wipe — heredar el shell, setear `animated: true` y `openMs`/`closeMs`. Para un panel grande: no crear ventana — sumarlo como vista `Item` de `PanelPopupHost` (el wipe y los tiempos los hereda del host).

## Patrón B — wipe interno de contenido (panel de notificaciones del CC)

Cuando el wipe es dentro de un popup que **ya existe** (no se remonta), el mismo truco se hace local: una prop `progress` con `Behavior` + un contenedor de clip anclado abajo + el contenido a tamaño real adentro (`popups/ControlCenterNew.qml`, `notifView`).

```qml
Item {
    id: notifView
    property real progress: active ? 1.0 : 0.0
    visible: progress > 0.01
    Behavior on progress {
        NumberAnimation {
            duration: notifView.active ? 250 : 200
            easing.type: Easing.OutCubic
        }
    }
    Item {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * notifView.progress
        clip: true
        Item { anchors.bottom: parent.bottom; width: parent.width; height: parent.height }
    }
}
```

Animar la altura del contenedor de clip es aceptable **si el hijo tiene tamaño fijo** (no relayouta). Si el contenido se dimensiona solo, animar `y`/`opacity` en vez de altura.

## Patrón C — menús flotantes (fade + scale)

Menús efímeros del CC (`pfMenu`, `layMenu`, `ctxMenu`, `plMenu`): `visible: opacity > 0` + Behaviors breves. El scale chico (0.96→1) da la sensación de "sale del punto" sin tocar layout.

```qml
Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
```

## Patrón D — highlight de listas (ListView)

`components/PanelList.qml` anima la selección con las propiedades del ListView, **no** con un `Behavior`:

```qml
highlightFollowsCurrentItem: true
highlightMoveDuration: root.highlightDuration    // 180 AppMenu/Clip/Mpd; 0 = snap
highlightResizeDuration: root.highlightDuration
```

- **`Behavior on highlight.y` no funciona**: el ListView escribe la geometría del highlight desde C++, y los cambios de propiedad hechos por C++ no disparan `Behavior`.
- **No** usar `highlightFollowsCurrentItem: false` + bindings a `currentItem.y`: rompe el auto-scroll (bug visto: "al estar en el top no hace scroll").

## Duraciones y easings

| Uso | Duración | Easing |
|---|---|---|
| Hover / color feedback | 80–150ms | `OutCubic` |
| Apertura de popup | 250–320ms | `OutCubic` |
| Cierre de popup | ~50ms menos que apertura | `OutCubic` |
| Highlight de lista | 150–180ms | default del ListView |
| Scale de menú | 160ms (junto a opacity 140ms) | `OutCubic` |
| Movimiento grande (track, expansión) | 300–400ms | `OutQuint`/`OutExpo` |

Guía de curvas: `OutCubic` es el default seguro (arranca rápido pero se ve). `OutQuint`/`OutExpo` solo en recorridos largos — en reveals cortos sobre fondo oscuro se perciben como "no hay animación" (caso real: wipe de 200ms OutQuint se reportó como inexistente; con 250–320ms OutCubic se ve). `OutBack`/`OutElastic`/`SpringAnimation` solo para interacción lúdica (drags, toggles), nunca en reveals serios.

## Pitfalls verificados

- **`ColorAnimation` con `"transparent"`**: interpola hacia gris. Siempre usar alpha 0 del mismo tono (regla en `project/conventions.md`).
- **Popup que "salta" al animar altura**: ningún `PanelWindow` debe bindear `implicitHeight` al contenido animado (patrón `ControlCenterNew`: wrapper con `Behavior on height`).
- **Mask `Region { item: ... }` congela la geometría al nacer**: usar `x/y/width/height` bindeados.
- **DismissOverlay/just-click**: no cambiar a `TapHandler` pasivo debajo de un `MouseArea` que actúa en press; los clicks van con `MouseArea` + `onClicked`.
- **No animar la geometría del `PanelWindow`** (layer surface anclada): animar hijos. Cambiar la superficie por frame = resize del surface + re-render completo.
- **`clip: true`** fuerza render offscreen del subárbol: mantener el contenedor de clip chico y con pocos hijos.

## Diagnóstico: "la animación no se ve"

1. ¿El host tiene `animated: true`? (el shell es opt-in; antes tenía el `Behavior` deshabilitado por completo). En paneles grandes es una sola línea en `PanelPopupHost`.
2. ¿El valor animado se escribe desde C++? → `Behavior` no dispara (caso ListView). Usar la API del componente.
3. ¿Duración/easing? Reveals ≥250ms con `OutCubic`.
4. ¿El ítem ya nace con el valor final? → gate `_animReady` + `Qt.callLater` para el primer ciclo.
5. Verificación programática sin ver la pantalla (el objetivo visual lo valida el humano): armar un harness en `/tmp/opencode/<algo>` con symlinks a `state/ components/ popups/ ...` + un `shell.qml` propio, correr `HOME=/tmp/opencode/<algo> timeout 20 qs -c /tmp/opencode/<algo>/` y muestrear el valor con `FileView.setText()` en timers (ej. +50/+100/+300ms). Ojo: `/tmp/opencode` puede vaciarse entre sesiones (recrear symlinks) y los imports relativos anidados necesitan espejo (ej. `DismissOverlay` importa `../../components/`).
6. `qmllint -i . -i ./state -i ./components -i ./popups -i ./taskbar -i ./widgets -i ./tray -i ./ipc <archivo>` después de cada edit.

## Referencias del repo

- `components/WipePopupShell.qml` — shell con wipe opt-in (`animated`, `openProgress`).
- `components/PanelPopupHost.qml` — superficie única de los 4 paneles grandes (wipe + `_CONFIGS` con openMs/closeMs por panel; retención `_lastPanel`/`closeHold` para el cierre).
- `popups/NotificationPopup.qml` (250/200), `popups/OsdSliderPopup.qml` — hosts animados con superficie propia.
- `popups/ControlCenterNew.qml` — wipe de `notifView` + fade/scale de menús (vista del panel `controlcenter`).
- `components/PanelList.qml` — highlight animado (`highlightDuration`).
- `components/MprisControl.qml`, `components/PillButton.qml` — hovers/feedback de botones.
- `.opencode/skills/project/conventions.md` — bugs históricos de animación (color, masks, altura de popups).
