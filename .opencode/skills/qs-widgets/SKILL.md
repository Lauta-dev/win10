# QuickShell v0.3.0 — Quickshell.Widgets

`import Quickshell.Widgets`

---

## WrapperManager

Determines which child of an Item should be its visual child.

### Using wrapper types
WrapperManager-based types have a single visual child. Specify via default property or child property. Must use child property if widget has more than one Item-based child.

### Implementing wrapper types
Create a WrapperManager inside your wrapper component's default property, then alias a new property to WrapperManager's child property.

### Properties
- `wrapper: Item` — The wrapper managed by this manager. Defaults to the manager's parent. Cannot be changed after Component.onCompleted.
- `child: Item` — Selected child. Setting overrides default selection. Can be defined inline or reference a non-child component (will be reparented). Setting to null selects no child, undefined restores default.

---

## MarginWrapperManager (extends WrapperManager)

Applies margins to a child item, handling size/implicit size relationship.

WARNING: MarginWrapperManager-based types set the child's Item.x, Item.y, Item.width, Item.height or Item.anchors. Do not set them yourself; use Item.implicitWidth and Item.implicitHeight.

### Margin calculation
- If `resizeChild` is true: each side's margin = `<side>Margin` + `extraMargin`. Content item stretched to match margin if wrapper not at implicit size.
- If `resizeChild` is false: `<side>Margin` properties interpreted as ratio. Content item not stretched.
- Implicit size of wrapper = implicit size of content item + all margins.

### Properties
- `margin: real` — Default for topMargin, bottomMargin, leftMargin, rightMargin (default 0).
- `topMargin: real`, `bottomMargin: real`, `leftMargin: real`, `rightMargin: real` — Requested margins, not counting extraMargin. Default to margin. Reset by assigning undefined.
- `extraMargin: real` — Extra margin in addition to side margins (default 0).
- `resizeChild: bool` — If child should be resized larger than implicit size when parent is resized larger (default true).
- `implicitWidth: real` — Override implicit width. Default: content implicit width + left/right margin. Reset by assigning undefined.
- `implicitHeight: real` — Override implicit height. Default: content implicit height + top/bottom margin. Reset by assigning undefined.

---

## WrapperItem (extends Item)

MarginWrapperManager-based. Wrap a single component in an item, or give it a margin.

WARNING: Do not set Item.x, Item.y, Item.width, Item.height or Item.anchors on the child. Use Item.implicitWidth and Item.implicitHeight.

### Properties
- `child: Item` — See WrapperManager.child.
- Inherits all MarginWrapperManager properties: margin, topMargin, bottomMargin, leftMargin, rightMargin, extraMargin, resizeChild, implicitWidth, implicitHeight.

---

## WrapperRectangle (extends Rectangle)

MarginWrapperManager-based. Add a border or background rectangle to a child item. For clipping, use ClippingWrapperRectangle.

WARNING: Do not set Item.x, Item.y, Item.width, Item.height or Item.anchors on the child. Use Item.implicitWidth and Item.implicitHeight.

### Properties
- `child: unknown` — See WrapperManager.child.
- `contentInsideBorder: bool` — If true (default), rectangle's border width added to extraMargin.
- `sets: unknown`
- Inherits all MarginWrapperManager properties.

---

## ClippingWrapperRectangle

MarginWrapperManager-based. Add a clipping border or background rectangle to a child item. Clips content inside border including rounded corners.

If you don't need clipping, use WrapperRectangle.

WARNING: Do not set Item.x, Item.y, Item.width, Item.height or Item.anchors on the child. Use Item.implicitWidth and Item.implicitHeight.

### Properties
- `child: unknown` — See WrapperManager.child.
- `extraMargin: real` — Extra margin. If contentInsideBorder is true, rectangle's border width added to this.
- Inherits all MarginWrapperManager properties: margin, topMargin, bottomMargin, leftMargin, rightMargin, resizeChild, implicitWidth, implicitHeight.

---

## WrapperMouseArea

MarginWrapperManager-based. Wrap a single component in a mouse area. Works same as WrapperItem but with MouseArea.

WARNING: Do not set Item.x, Item.y, Item.width, Item.height or Item.anchors on the child. Use Item.implicitWidth and Item.implicitHeight.

### Properties
- `child: Item` — See WrapperManager.child.
- Inherits all MarginWrapperManager properties.

---

## ClippingRectangle (extends Item)

Specialized Rectangle that clips content inside its border, including rounded corners. Costs more than Rectangle — only use when you need to clip items inside to the border.

WARNING: Requires at least Qt 6.7.

### Properties
- `color: color` — Background color, goes under content.
- `radius: real` — Radius of all corners (default 0).
- `topLeftRadius: real`, `topRightRadius: real`, `bottomLeftRadius: real`, `bottomRightRadius: real` — Individual corner radii. Default to radius.
- `antialiasing: bool` — If rectangle should be antialiased. Default: true if any corner has non-zero radius, otherwise false.
- `border: unknown` — See Rectangle.border.
- `contentItem: unknown` (readonly) — Item containing the rectangle's content.
- `contentInsideBorder: bool` — If content item should be resized to fit inside the border. Default: !contentUnderBorder.
- `contentUnderBorder: bool` — If content should be displayed underneath the border. Default: false. Does nothing if border is opaque.
- `children: unknown` — Visual children of contentItem (list<Item>).
- `data: unknown` (default) — Data of contentItem (list<QtObject>).

---

## IconImage (extends Item)

Specialization of Image configured for icon-style images. Assumes 1:1 aspect ratio. If not 1:1, padding is added.

Use for: Custom button icons, status indicators, system tray icons.
Do NOT use for: Big images, frequently changing images, non-icon content.

### Properties
- `source: string` — URL of the image (default empty).
- `implicitSize: real` — Suggested size. Used as default for Item.implicitWidth and Item.implicitHeight.
- `actualSize: real` (readonly) — Actual size the image will display at.
- `mipmap: bool` — If mipmap filtered (default false). Enable if image is significantly scaled down and looks bad.
- `asynchronous: bool` — If loaded asynchronously (default false).
- `status: unknown` — Load status of the image.
- `backer: Image` — The backing Image. Useful to access more functionality than exposed by IconImage.
