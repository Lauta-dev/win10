# Skill: conventions — Reglas, Bugs, IPC, AppMenu

## Dependencias del sistema
QuickShell · labwc · PipeWire (native API) · cliphist · wlr-randr · swaybg · gsettings · xfconf-query (opcional) · Nerd Fonts · Papirus icon theme · binarios Go propios (resolve-icons, list-monitors, list-dirs, wp-helper)

---

## Bugs conocidos

### Bug 1: Flash de color intermedio en hover/click (alpha bug)

**Síntoma:** Al hacer hover/click aparece un color intermedio no deseado — tono semi-transparente que no pertenece ni al estado idle ni al activo.

**Causa:** QML interpola entre dos colores usando ColorAnimation. Si uno es `"transparent"` (string) en lugar de un color con alpha 0 del mismo tono, produce un flash grisáceo.

**Patrón con bug (NO usar):**
```qml
// MAL: "transparent" no tiene RGB definido → flash
color: ph ? Config.hoverBg : "transparent"
Behavior on color { ColorAnimation { duration: 100 } }

// MAL: Qt.alpha con 0 puede producir flash
color: isActive ? Qt.alpha(Config.primaryColor, 0.15) : Qt.alpha(Config.primaryColor, 0)
Behavior on color { ColorAnimation { duration: 100 } }
```

**Patrón correcto (USAR):**
```qml
// BIEN: mismo RGB en ambos estados, solo cambia alpha
color: ph ? Qt.rgba(1,1,1, Config.dark ? 0.07 : 0.04) : Qt.rgba(1,1,1, 0.0)
Behavior on color { ColorAnimation { duration: 80 } }

// BIEN: opacity en lugar de color
Rectangle {
    color: Config.hoverBg
    opacity: ph ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 100 } }
}
```

**Regla:** Cuando el estado idle es "sin color", nunca usar `"transparent"` ni `Qt.alpha(..., 0)` como extremo de ColorAnimation.

### Bug 2: Flash/pulso al hacer click en tiles con estado activo (hover + active conflict)

**Síntoma:** Al hacer click en un tile toggle el fondo hace un pulso visible: sube de intensidad al presionar, baja, y al hacer click de nuevo sube y desaparece bruscamente.

**Causa:** Usar un solo Rectangle cuya opacity depende de dos estados simultáneos (`ph` y `tileActive`).

**Patrón con bug (NO usar):**
```qml
// MAL: ph y tileActive compiten
Rectangle {
    color: Config.primaryContainer
    opacity: tileActive ? 1.0 : ph ? 0.5 : 0.0
    Behavior on opacity { NumberAnimation { duration: 150 } }
}
```

**Patrón correcto (USAR):**
```qml
// Base fija, sin animación
color: Config.surface2

// Overlay hover — solo activo cuando NO hay estado activo
Rectangle {
    anchors.fill: parent; radius: parent.radius
    color: Config.hoverBgStrong
    opacity: ph && !tileActive ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
}

// Overlay activo — independiente del hover
Rectangle {
    anchors.fill: parent; radius: parent.radius
    color: Config.primaryContainer
    opacity: tileActive ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
}
```

**Regla:** Cuando un elemento tiene dos estados visuales independientes, cada uno debe tener su propio Rectangle con su propia Behavior.

### Bug 3: Salto al animar la altura de un popup (surface resize)

**Síntoma:** Al expandir/colapsar contenido en un `PanelWindow`, el popup "salta" aunque el ítem interno tenga `Behavior on height`.

**Causa:** `implicitHeight` bindeado al contenido → la superficie layer-shell se redimensiona por frame y labwc lo aplica a saltos.

**Patrón correcto (patrón `ControlCenterNew`):**
```qml
// Superficie FIJA — el compositor no recalcula nada por frame
implicitHeight: Screen.height - Config.taskbarHeight - 20
readonly property real visualHeight: Math.min(Math.max(flickable.contentHeight + 2, MIN), _maxH)
Item {
    id: wrapper
    anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
    height: root.visualHeight
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    // Rectangle + Flickable con clip adentro
}
```

**Regla:** ningún `PanelWindow` bindea `implicitHeight` al contenido si este cambia de tamaño animado. Lo que usaba `root.height` como alto visible pasa a `wrapper.height`.

---

### Bug 4: Click-through — un click dispara el botón Y el TapHandler de abajo (doble acción)

**Síntoma:** Click en un botón abre su panel (correcto) pero TAMBIÉN dispara el TapHandler de la celda que está debajo.

**Causa:** Mezclar sistemas de eventos: el botón es `MouseArea` que actúa en `onPressed`, y la celda usa `TapHandler` con `gesturePolicy: DragThreshold` (default). Con ese policy el TapHandler usa solo *passive grab* y la doc de Qt dice que dispara igual aunque otro ítem ya esté reaccionando, incluso en otra capa del UI. Resultado: el press actúa el botón y en el release el TapHandler dispara también. Dos acciones de un click, por diseño — no es race ni timing.
No sirven: `grabPermissions: TakeOverForbidden` (el TapHandler pasivo no roba nada, solo observa), cooldowns ni guards de estado.

**Patrón correcto (todo `MouseArea` + `onClicked`, sin mezclar):**
```qml
// MAL: TapHandler debajo de un botón MouseArea → doble acción
TapHandler {
    onTapped: root.dayActivated(cell.dkey)
}

// BIEN: MouseArea legacy — el press aceptado arriba nunca llega abajo
MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    onClicked: root.dayActivated(cell.dkey)
}
```

**Regla:** en layouts con capas superpuestas (botones sobre celdas, drawers sobre grillas), todos los clicks van con `MouseArea` + `onClicked`. Nunca un `TapHandler` pasivo debajo de un `MouseArea` que actúa en press.

### Bug 5: Mask con `item:` congela la geometría al nacer (click/hover muertos)

**Síntoma:** Un `PanelWindow` con superficie fija muestra su contenido pero no responde a hover ni clicks, salvo una franja al borde.

**Causa:** `Region { item: <algo> }` toma la geometría del ítem al momento de crearse y no la sigue. Si el ítem nace vacío/colapsado (ej: lista de notificaciones con 0 ítems → 16px), el mask queda enano para siempre aunque el contenido crezca.

**Patrón correcto (ver `components/WipePopupShell.qml`, que lo encapsula):**
```qml
// MAL: geometría congelada al nacer
Region { id: listMask; item: notifList }

// BIEN: rect explícito con bindings — reactivo al alto real del contenido
Region {
    id: listMask
    x: Math.round((root.implicitWidth - root.toastWidth) / 2)
    y: Math.round(root.implicitHeight - notifList.height)
    width: root.toastWidth
    height: notifList.height
}
mask: notifList.count > 0 ? listMask : emptyMask
```

**Regla:** para masks que siguen contenido de tamaño variable, usar `Region` con `x/y/width/height` bindeados, nunca `item:`. (un wrapper que nace a tamaño final sí puede usar `item:`.)

---

## Reglas para la IA

**Regla general:** No hacer ningún cambio que no haya sido explícitamente pedido. Revisar siempre `docs/` y `.opencode/skills/project/` antes de modificar código.

---

## Añadir un nuevo ítem a la SystemTray

**1. Tamaño — derivado de Config.taskbarHeight:**
```qml
implicitWidth:  Config.taskbarHeight
implicitHeight: Config.taskbarHeight
```

**2. Padding interno:** Copiar de VolumeWidget y ClipboardWidget.

**3. Color de fondo — desde Config:**
```qml
color: "transparent"   // o Config.idleBg
color: Config.hoverBg
color: Config.activeBg
```

**4. Animación:**
```qml
Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
```

**5. Radio:** Config.radiusMd (12px)

**6. Evento de click — via TaskbarState:**
```qml
onClicked: TaskbarState.activePopup = "mi-popup"   // popup con superficie propia
onClicked: TaskbarState.openPanel("controlcenter") // panel grande del PanelPopupHost
```

**7. Tooltip:**
```qml
onEntered: TaskbarState.showTip("Mi tooltip", mapToItem(null, width/2, 0).x)
onExited:  TaskbarState.hideTip()
```

**8. Dónde insertar:** Antes de VolumeWidget y antes de DashWidget.

---

## IPC — Control externo

```bash
qs ipc call <target> <función> [args...]
```

**Handlers disponibles:**

| Target | Función | Args | Descripción |
|---|---|---|---|
| clipboard | toggle() | — | Abre/cierra popup |
| clipboard | open() | — | Abre popup |
| clipboard | close() | — | Cierra popup |
| notify | send(app, title, body, icon) | strings | Notificación |
| command-palette | toggle()/open()/close()/openStartmenu() | — | AppMenu (compat: antes la paleta) |
| command-palette | openMpd/openMusic/openCalc/openCalculator/openPomodoro/openKeepass/openPasswords | — | Tabs del Hub |

**Agregar un nuevo IpcHandler:**
```qml
IpcHandler {
    target: "mi-target"
    function toggle(): string {
        return "ok"
    }
}
```
Siempre en un singleton de state/, nunca en un popup. Las funciones retornan string.

---

## AppMenu

`popups/LauncherPopup.qml` — Lanzador único AppMenu/Clipboard por modo (superficie fija 640×520, abajo-centro). Se activa via IPC (`command-palette toggle` abre modo app, `clipboard toggle` abre modo clip).

**Importante:** el panel launcher vive como vista `Item` en `components/PanelPopupHost.qml` (cargada con `AutoLazyLoader` interno, condición `TaskbarState.panel === "launcher"`); sus `IpcHandler` viven en `ipc/AppMenuIpc.qml` e `ipc/ClipboardIpc.qml`, siempre en memoria.

### Arquitectura
Un popup único con dos modos (cambiar de modo en caliente no reabre):
- `LauncherPopup` + `components/appmenu/` (vista `AppMenuView`, delegate `AppDelegate`) — buscar + abrir apps .desktop, con recientes y categorías.
- `LauncherPopup` + `components/clipboard/` (vista `ClipView`, delegate `ClipDelegate`) — buscar + pegar.
- Música/Claves/Calc viven en el Hub (`popups/HubPopup.qml` + `components/{mpd,keepass,hub}/`).

### AppMenu — Categorías y Recientes

**Categorías via `>`:**
- `>` solo → lista categorías como ítems seleccionables
- `>Category` → filtra apps por categoría (match exacto primero, luego parcial)
- `>Category texto` → filtra por categoría + búsqueda en nombre/comment
- Categorías extraídas del campo `Categories` de .desktop (solo la primera, vendors filtrados: XFCE, Qt, GNOME, GTK, X-XFCE)
- Labels en español: Game→"Juegos", Utility→"Utilidades", Office→"Oficina", AudioVideo→"Audio y Video", System→"Sistema", Network→"Red", Settings→"Configuración", Security→"Seguridad", Education→"Educación", Graphics→"Gráficos"

**Apps recientes:**
- Máximo 5 apps recordadas en `SettingsState.recentApps`
- Ordenadas por última apertura (más reciente primero)
- Aparecen **siempre al tope** de cualquier lista filtrada
- Badge "Reciente" inline junto al nombre (56×16, `Config.primaryColor`)
- Se registran automáticamente al lanzar una app: `SettingsState.addRecentApp(exec, name)`

**Delegate de apps (AppDelegate.qml):**
```
[ICON] Name [Reciente]
       Description (si existe)
```

### Convenciones (vistas AppMenu/Clipboard)
- Cada vista es dueña de su lista + buscador + teclado
- Datos cargados en `enter()`, nunca en Component.onCompleted
- Filtro siempre via onSearchChanged
- ESC con búsqueda vacía → cierra

---

## Convenciones del proyecto

- **Singletons solo en state/** — no crear pragma Singleton en otras carpetas
- **Colores siempre via Config** — nunca hardcodear hex
- **Preferir APIs nativas de Quickshell** antes que Process{} — ej: Pipewire, Mpris, Networking, Bluetooth
- **Si no hay API nativa → Process{}** — nunca síncronos
- **Popups via AutoLazyLoader** — no instanciarlos directamente (excepción: los 4 paneles grandes son vistas `Item` del `PanelPopupHost` único, con sus loaders internos)
- **Paneles grandes via slot `TaskbarState.panel`** — abrir/cerrar con `openPanel(name)` / `closePanel(name)`; nunca escribir flags derivados
- **Estado compartido en singletons de state/** — no pasar estado via props. TaskbarState (UI efímero), AudioState (volumen), MprisState (música), SettingsState (persistencia)
- **Persistencia via SettingsState.markDirty()** — nunca escribir a disco desde popup
- **_animReady pattern** en todos los PanelWindow de popups con superficie propia
- **Process estático con función run(cmd)** — evita que command sea reactivo