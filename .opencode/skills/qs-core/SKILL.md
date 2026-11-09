# QuickShell v0.3.0 — Core

`import Quickshell`

## QML Essentials

- **Imports**: `import Quickshell`, `import QtQuick`, `import QtQuick.Layouts`
- **Reactive bindings**: `property: value` auto re-evaluates when dependencies change
- **Signal handlers**: `on<SignalName>: expression`
- **Components**: Any `.qml` file starting with uppercase is a type. Use `pragma Singleton` for singletons.
- **Default property**: Allows assigning children without naming the property
- **`id`**: Special lowercase identifier for referencing objects within a file

## Item Size & Position

- **Implicit size** (implicitWidth/implicitHeight): desired size, flows children → parent
- **Actual size** (width/height): set by parent, flows parent → children
- **Never set width/height on items managed by containers**; use implicitWidth/implicitHeight instead
- **Layouts**: RowLayout, ColumnLayout, GridLayout (use over Row/Column for pixel alignment)

---

## Quickshell (singleton)

- `cacheDir: string` (readonly) — `~/.cache/quickshell/by-shell/<shell-id>`
- `dataDir: string` (readonly) — `~/.local/share/quickshell/by-shell/<shell-id>`
- `stateDir: string` (readonly) — `~/.local/state/quickshell/by-shell/<shell-id>`
- `shellDir: string` (readonly) — Root directory of your shell
- `shellRoot: string` (readonly) [DEPRECATED] — Renamed to shellDir
- `configDir: string` (readonly) [DEPRECATED] — Renamed to shellDir
- `workingDirectory: string` — Quickshell's working directory
- `watchFiles: bool` — Auto-reload on file changes (default true)
- `clipboardText: string` — System clipboard (empty unless a QS window is focused on Wayland)
- `screens: list<ShellScreen>` (readonly) — All connected screens
- `processId: int` (readonly) — Quickshell's PID

### Functions
- `cachePath(path): string` — `${cacheDir}/${path}`
- `dataPath(path): string` — `${dataDir}/${path}`
- `statePath(path): string` — `${stateDir}/${path}`
- `shellPath(path): string` — `${configDir}/${path}`
- `configPath(path): string` [DEPRECATED] — Renamed to shellPath()
- `env(variable): variant` — Get env var or null
- `execDetached(context)` — Launch detached process
- `hasQtVersion(major, minor): bool` — Check Qt version
- `hasVersion(major, minor, features?): bool` — Check QS version
- `hasThemeIcon(icon): bool` — Check if icon exists in theme
- `iconPath(icon): string` — Resolve icon to Image.source string
- `iconPath(icon, check): string` — Empty string if icon doesn't exist
- `iconPath(icon, fallback): string` — Fallback icon if requested not found
- `reload(hard)` — Reload shell (hard = full reload)
- `inhibitReloadPopup()` — Prevent reload popup (call from reloadCompleted/reloadFailed)

### Signals
- `reloadCompleted()` — Reload succeeded
- `reloadFailed(errorString)` — Reload failed
- `lastWindowClosed()` — Last window closed

---

## ShellScreen (uncreatable)

- `name: string` (readonly) — e.g. `DP-1`, `HDMI-1`, `eDP-1`
- `model: string` (readonly) — Screen model
- `serialNumber: string` (readonly) — Screen serial
- `x: int` (readonly), `y: int` (readonly)
- `width: int` (readonly), `height: int` (readonly)
- `devicePixelRatio: real` (readonly) — Physical vs device-independent pixels
- `logicalPixelDensity: real` (readonly) — Device-independent pixels per mm
- `physicalPixelDensity: real` (readonly) — Physical pixels per mm
- `primaryOrientation` (readonly), `orientation` (readonly)
- `toString(): string`

WARNING: If monitor is disconnected, stored ShellScreen becomes dangling with default values.

---

## SystemClock

- `date: date` (readonly) — Current date and time
- `hours: int` (readonly) — Current hour
- `minutes: int` (readonly) — 0 if precision is Hours
- `seconds: int` (readonly) — 0 if precision is Hours or Minutes
- `precision: SystemClock` — Seconds | Minutes | Hours (default Seconds)
- `enabled: bool` — Pause updates (default true)

WARNING: Clock updates within ±50ms of system clock change.

---

## QsWindow (uncreatable, inherits Reloadable)

Base class of all Quickshell windows.

### Attached properties
Use as attached object of any Item subclass: `QsWindow.window`, `QsWindow.contentItem`, `QsWindow.itemPosition()`, `QsWindow.itemRect()`, `QsWindow.mapFromItem()`.

### Properties
- `color: color` — Background color (default white). WARNING: If opaque before visible, cannot become transparent later unless surfaceFormat.opaque is false.
- `visible: bool` — Shown or hidden (default true)
- `implicitWidth: int`, `implicitHeight: int` — Desired size
- `width: int`, `height: int` — Actual size (DEPRECATED to set, use implicit)
- `contentItem: Item` (readonly)
- `mask: Region` — Clickthrough mask (default null)
- `devicePixelRatio: real` (readonly)
- `screen: ShellScreen` — Current screen, can be moved
- `surfaceFormat: { opaque: bool }` — Cannot change after window created
- `updatesEnabled: bool` — Render updates (default true)
- `backingWindowVisible: bool` (readonly) — Window shown (prefer visible)
- `windowTransform: QtObject` (readonly) — Opaque transform trigger
- `data: list<QtObject>` (default, readonly)

### Functions
- `itemPosition(item): point` — Item position relative to window (not reactive)
- `itemRect(item): rect` — Item geometry relative to window (not reactive)
- `mapFromItem(item, point): point`
- `mapFromItem(item, x, y): point`
- `mapFromItem(item, rect): rect`
- `mapFromItem(item, x, y, width, height): rect`

### Signals
- `windowConnected()`
- `closed()` — Closed by user, display server, or error
- `resourcesLost()` — Resources lost, followed by closed()

---

## PanelWindow (inherits QsWindow)

Decorationless window attached to screen edges.

### Properties
- `anchors: [bottom, top, right, left]` — Attach to screen edges (all false by default). Opposite anchors force dimension to screen size.
- `margins: [right, top, left, bottom]` — Offsets from screen sides. Only applies to anchored edges.
- `exclusiveZone: int` — Reserved space. Sets exclusionMode to Normal. Needs 1 or 3 anchors.
- `focusable: bool` — Accept keyboard focus (default false)
- `aboveWindows: bool` — Render above standard windows (default true). Corresponds to WlrLayershell.layer on Wayland.
- `exclusionMode: ExclusionMode` — Default Auto

### ExclusionMode (enum)
- `Normal` — Respect other exclusion zones
- `Ignore` — Ignore other zones, cannot set one
- `Auto` — Decide based on window dimensions and anchors

---

## FloatingWindow (inherits QsWindow)

Standard toplevel OS window.

### Properties
- `title: string` — Window title
- `maximized: bool` — Currently maximized
- `minimized: bool` — Currently minimized
- `fullscreen: bool` — Currently fullscreen
- `parentWindow: QtObject` — Parent window (cannot change after visible)
- `maximumSize: size`, `minimumSize: size` — Size constraints

### Functions
- `startSystemMove(): bool` — Start move (call during pointer press/drag)
- `startSystemResize(edges): bool` — Start resize (call during pointer press/drag)

---

## PopupWindow (inherits QsWindow)

Popup positioned relative to a floating or panel window.

### Properties
- `visible: bool` — Shown or hidden (default false)
- `grabFocus: bool` — Dismiss on outside click. WARNING: Changes while open only take effect after hide/show.
- `screen: ShellScreen` (readonly) — Current screen
- `anchor: PopupAnchor` (readonly) — Anchor/positioner. Popup not shown until valid anchor.
- `parentWindow: QtObject` [DEPRECATED] — Use anchor.window
- `relativeX: int` [DEPRECATED] — Use anchor.rect.x
- `relativeY: int` [DEPRECATED] — Use anchor.rect.y

---

## PopupAnchor (uncreatable)

Anchorpoint for popup windows.

### Properties
- `item: Item` — Item to anchor to (unsets window)
- `window: QtObject` — Window to anchor to (unsets item)
- `rect: [x, y, width, height]` — Anchor rect relative to item or window
- `edges: Edges` — Point on anchor rect popup attaches to (default Top|Left)
- `gravity: Edges` — Direction popup expands (default Bottom|Right)
- `adjustment: PopupAdjustment` — Strategy if popup doesn't fit on screen
- `margins: [bottom, right, left, top]` — Margin on anchor rect

### Functions
- `updateAnchor()` — Update anchor rect relative to parent window

### Signals
- `anchoring()` — About to be used

---

## Edges (enum)

Combine with `|` operator.

- `Left`, `Top`, `Right`, `Bottom`, `None`

---

## PopupAdjustment (enum)

Combine with `|` operator. Applied: Flip → Slide → Resize.

- `None`
- `Flip` = `FlipX | FlipY`
- `FlipX` — Invert horizontal gravity
- `FlipY` — Invert vertical gravity
- `Slide` = `SlideX | SlideY`
- `SlideX` — Slide along X axis
- `SlideY` — Slide along Y axis
- `Resize` = `ResizeX | ResizeY`
- `ResizeX` — Reduce width to fit
- `ResizeY` — Reduce height to fit
- `All` = `Flip | Slide | Resize`

---

## Region

Used for QsWindow.mask.

### Properties
- `x: int`, `y: int`, `width: int`, `height: int` — Default 0. Ignored if item is set.
- `item: Item` — Item determines geometry (overrides x/y/w/h)
- `shape: RegionShape` — Rect | Ellipse (default Rect)
- `radius: int` — Corner radius for Rect (default 0)
- `topLeftRadius`, `topRightRadius`, `bottomLeftRadius`, `bottomRightRadius: int`
- `regions: list<Region>` (default, readonly) — Sub-regions
- `intersection: Intersection` — How region interacts with parent (default Combine)

### Signals
- `changed()` — Geometry changed
- `childrenChanged()`

---

## RegionShape (enum)
- `Rect`, `Ellipse`

## Intersection (enum)
- `Combine` — Union
- `Subtract` — Cut this region out
- `Intersect` — Only area covered by both
- `Xor` — Area not covered by both

---

## LazyLoader (inherits Reloadable)

Load components asynchronously between frames.

### Properties
- `component: Component` (default) — Component to load (mutually exclusive with source)
- `source: string` — URI to load from (mutually exclusive with component)
- `active: bool` — Fully loaded. Setting true blocks UI. Setting false destroys.
- `activeAsync: bool` — Async load like loading
- `loading: bool` — Actively loading
- `item: QtObject` (readonly) — Loaded item (null if not loading/active). WARNING: Accessing while loading blocks.

WARNING: Variants does not support async loading.

---

## Variants (inherits Reloadable)

Creates/destroys component instances when model changes. For non-Item objects.

### Properties
- `model: list<variant>` — Values to create instances with
- `delegate: Component` (default) — Component to create. Should define `modelData`.
- `instances: list<QtObject>` (readonly) — Current instances

WARNING: BUG — fails to reload children if variant set changes during instantiation.

---

## ScriptModel

QML Data Model that generates model operations from JS expression changes.

### Properties
- `values: list` — Values to reflect. WARNING: Only works with *unique* values.
- `objectProp: string` — Property for JS object comparison (default "")

Use when data changes over time to avoid destroying/recreating all delegates.

---

## Scope (inherits Reloadable)

Convenience type — sets Reloadable.reloadableId for all children.

### Properties
- `children: list<QtObject>` (default, readonly)

Does NOT work for visible Items (all widgets).

---

## ShellRoot (inherits Scope)

Optional root config element.

### Properties
- `settings: QuickshellSettings` (readonly)

---

## QuickshellSettings (uncreatable)

Accessor for Quickshell options.

### Properties
- `workingDirectory: string` — Default: launch location
- `watchFiles: bool` — Auto-reload (default true)

### Signals
- `lastWindowClosed()` — Call `Qt.quit()` to exit

---

## Singleton (inherits Scope)

All singletons should inherit from this type.

---

## Reloadable (uncreatable)

Objects that attempt to take state from previous config revisions.

### Properties
- `reloadableId: string` — Identifier for matching to previous state

---

## Retainable (uncreatable)

Attached property to keep objects alive after normal destruction (exit transitions).

### Properties
- `retained: bool` (readonly) — Currently retained

### Functions
- `lock()` — Hold a lock (counter-based)
- `unlock()` — Remove a lock
- `forceUnlock()` — Destroy the object

### Signals
- `dropped()` — Would normally be destroyed
- `aboutToDestroy()` — Immediately before destruction

NOTE: Use RetainableLock instead.

---

## RetainableLock

Safe wrapper for Retainable objects.

### Properties
- `object: QtObject` — Must be Retainable
- `locked: bool` — Lock state
- `retained: bool` (readonly) — Currently retained

### Signals
- `aboutToDestroy()` — Rebroadcast
- `dropped()` — Rebroadcast

---

## PersistentProperties (inherits Reloadable)

Holds properties across reloads.

### Signals
- `loaded()` — Reload stage completed (always called)
- `reloaded()` — Properties reloaded (not called if no old instance)

---

## BoundComponent (inherits Item)

Component loader for setting initial properties, escaping cyclic dependency errors.

### Properties
- `sourceComponent: Component` — Source as Component
- `source: string` — Source as Url
- `item: QtObject` (readonly) — Loaded component (null until finished)
- `bindValues: bool` — Bind properties after initial set (default true)
- `implicitWidth: real` (readonly), `implicitHeight: real` (readonly)

---

## ObjectModel (uncreatable)

Typed view into a list of objects. Works as QML Data Model with `modelData` role.

### Properties
- `values: list<QtObject>` (readonly) — Content as QML list

### Functions
- `indexOf(): int`

### Signals
- `objectInsertedPre(object, index)` / `objectInsertedPost(object, index)`
- `objectRemovedPre(object, index)` / `objectRemovedPost(object, index)`

NOTE: `property var foo: model[3]` does NOT update reactively. Use `model.values[3]`.

---

## DesktopEntries (singleton)

Index of desktop entries per spec.

### Properties
- `applications: ObjectModel<DesktopEntry>` (readonly) — All Application entries not Hidden or NoDisplay

### Functions
- `byId(id): DesktopEntry` — Lookup by name. May return null.
- `heuristicLookup(name): DesktopEntry` — Heuristic lookup. May return null.

### Signals
- `applicationsChanged()`

---

## DesktopEntry (uncreatable)

### Properties
- `id: string` (readonly)
- `name: string`
- `icon: string` — Icon name, may be empty
- `genericName: string` — Short description (e.g. "Web Browser")
- `comment: string` — Long description
- `categories: list<string>`
- `keywords: list<string>`
- `command: list<string>` — Parsed Exec command
- `execString: string` — Raw Exec string (WARNING: cannot reliably run)
- `workingDirectory: string`
- `runInTerminal: bool`
- `noDisplay: bool` — Should not appear in menus
- `startupClass: string` — Initial class/appid for matching
- `actions: list<DesktopAction>` (readonly)

### Functions
- `execute()` — Run the application

---

## DesktopAction (uncreatable)

### Properties
- `id: string` (readonly)
- `name: string`
- `icon: string`
- `command: list<string>` — Parsed Exec (usable with execDetached/Process)
- `execString: string` — Raw Exec (WARNING: cannot reliably run)

### Functions
- `execute()` — Run the action

---

## ColorQuantizer

Get prevalent colors from an image.

### Properties
- `source: unknown` — Image path
- `depth: real` — Max depth. Produces 2^n colors.
- `imageRect: rect` — Crop rect (undefined to reset)
- `rescaleSize: real` — Rescale for faster processing (0 = no scaling)
- `colors: list<color>` (readonly) — Resulting colors

---

## EasingCurve

Directly accessible easing curve.

### Properties
- `curve: EasingCurve` — Same as PropertyAnimation.easing

### Functions
- `interpolate(x, a, b): real|point|rect` — Interpolate values
- `valueAt(x): real` — Y value for X on curve 0.0-1.0

---

## ElapsedTimer

Measure time between events.

### Functions
- `elapsed(): real` — Seconds since last start/restart
- `elapsedMs(): int` — Milliseconds
- `elapsedNs(): int` — Nanoseconds
- `restart(): real` — Restart, return seconds
- `restartMs(): int` — Restart, return milliseconds
- `restartNs(): int` — Restart, return nanoseconds

---

## TransformWatcher

Monitor geometry relationship between two Items.

### Properties
- `a: Item`, `b: Item`
- `commonParent: Item` — Known common parent (default null)
- `transform: QtObject` (readonly) — Updated when geometry changes (opaque value)

Biased towards `a` being parent of `b` or closer to common parent.

---

## QsMenuHandle (uncreatable)

### Signals
- `menuChanged()`

---

## QsMenuEntry (inherits QsMenuHandle, uncreatable)

### Properties
- `text: string` (readonly) — Menu item text
- `icon: string` (readonly) — Icon URL (empty if none)
- `enabled: bool` (readonly)
- `isSeparator: bool` (readonly) — Render as separator (other props meaningless)
- `buttonType: QsMenuButtonType` (readonly) — CheckBox | RadioButton | None
- `checkState: Qt.CheckState` (readonly)
- `hasChildren: bool` (readonly) — Accessible via QsMenuOpener

### Functions
- `display(parentWindow, relativeX, relativeY)` — Display platform menu

### Signals
- `triggered()` — Click/trigger

---

## QsMenuButtonType (enum)
- `None` — No checkbox/radiobutton
- `CheckBox` — Draw checkbox
- `RadioButton` — Draw radiobutton

---

## QsMenuOpener

Access children of a QsMenuEntry.

### Properties
- `menu: QsMenuHandle` — Menu to retrieve children from
- `children: ObjectModel<QsMenuEntry>` (readonly)

---

## QsMenuAnchor

Display anchor for platform menus.

### Properties
- `anchor: PopupAnchor` (readonly) — Positioner (must be valid to show)
- `menu: QsMenuHandle` — Menu to display
- `visible: bool` (readonly) — Currently open

### Functions
- `open()` — Open menu (requires valid anchor)
- `close()` — Close menu

### Signals
- `opened()` — Menu displayed
- `closed()` — Menu closed
