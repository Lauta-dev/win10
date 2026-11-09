# QuickShell v0.3.0 — Quickshell.WindowManager

`import Quickshell.WindowManager`

---

## WindowManager (singleton)

Window management interfaces exposed by the window manager.

### Properties
- `windowsets: list<Windowset>` (readonly) — All windowsets tracked by the WM across all projections.
- `windowsetProjections: list<WindowsetProjection>` (readonly) — All windowset projections tracked by the WM. Does not include internal projections from screenProjection().

### Functions
- `screenProjection(screen: ShellScreen): ScreenProjection` — Returns an internal WindowsetProjection covering a single screen, containing all windowsets on that screen regardless of WM-specified projection.

---

## Windowset (uncreatable)

Generic type encompassing both "Workspaces" and "Tags" in window managers.

### Properties
- `id: string` (readonly) — Persistent internal identifier. Identical across restarts and destruction/recreation.
- `name: string` (readonly) — Human readable name.
- `active: bool` (readonly) — Currently active. In workspace WM, means workspace is current. In tag WM, means tag is active.
- `urgent: bool` (readonly) — A window in this windowset has been marked urgent.
- `shouldDisplay: bool` (readonly) — If false, should generally be hidden from workspace pickers.
- `canActivate: bool` (readonly) — Can be activated.
- `canDeactivate: bool` (readonly) — Can be deactivated. In workspace WM, deactivation is usually implicit.
- `canRemove: bool` (readonly) — Can be removed. May be done implicitly by the WM.
- `canSetProjection: bool` (readonly) — Can be moved to a different projection.
- `coordinates: list<int>` (readonly) — N-dimensional array. Most WMs only expose one coordinate. First=X, second=Y, third=Z.
- `projection: WindowsetProjection` (readonly) — The projection this windowset is a member of.

### Functions
- `activate()` — Activate the windowset. Requires canActivate.
- `deactivate()` — Deactivate/hide. Requires canDeactivate.
- `remove()` — Remove/destroy. Requires canRemove.
- `setProjection(projection: WindowsetProjection)` — Move to different projection. Requires canSetProjection.

---

## WindowsetProjection (uncreatable)

A space that can be occupied by one or more Windowsets. The space is one or more screens. Multiple projections may occupy the same screens.

### Properties
- `screens: list<ShellScreen>` (readonly) — Screens the projection spans, often a single screen or all screens.
- `windowsets: list<Windowset>` (readonly) — Windowsets currently present on the projection.

---

## ScreenProjection (extends WindowsetProjection, uncreatable)

Aggregates all windowsets across all projections covering a specific screen.

When used with Windowset.setProjection(), an arbitrary projection on the screen will be picked. Usually there is only one.

Use WindowManager.screenProjection() to get a ScreenProjection for a given screen.
