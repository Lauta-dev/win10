// Command keybinds lee el rc.xml de labwc y devuelve los atajos como JSON
// para el panel "keybinds" de la shell. Es un comando one-shot: corre cada
// vez que se abre el popup, no queda vivo (KeybindsState.qml lo lanza).
//
// De rc.xml toma el atributo label (no es parte del spec de labwc: labwc lo
// ignora, es metadata para acá) y hace la interpretación: chips de teclas
// ("W-m" → ["Super","M"], XF86 → "Vol +", ...) y sección temática según la
// acción. Los mousebinds solo entran si tienen label.
//
// Uso:    keybinds [rc.xml]
// Sin argumento: $XDG_CONFIG_HOME/labwc/rc.xml, si no ~/.config/labwc/rc.xml
// Salida: {"sections":[{"title":"Sistema","rows":[{"desc":"...","keys":["..."],"raw":"W-m"}]}]}
// Errores por stderr con exit 1.
package main

import (
	"encoding/json"
	"encoding/xml"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ── Modelo XML de rc.xml ──────────────────────────────────────────────────
// labwc acepta la misma cosa como atributo o como hijo, así que las
// acciones se leen en las dos formas y se elige la que venga.

type xmlAction struct {
	Name         string `xml:"name,attr"`
	MenuAttr     string `xml:"menu,attr"`
	MenuChild    string `xml:"menu"`
	CommandAttr  string `xml:"command,attr"`
	CommandChild string `xml:"command"`
	ToAttr       string `xml:"to,attr"`
	ToChild      string `xml:"to"`
}

func (a xmlAction) menu() string {
	if a.MenuChild != "" {
		return a.MenuChild
	}
	return a.MenuAttr
}

func (a xmlAction) command() string {
	if a.CommandChild != "" {
		return a.CommandChild
	}
	return a.CommandAttr
}

func (a xmlAction) to() string {
	if a.ToChild != "" {
		return a.ToChild
	}
	return a.ToAttr
}

type xmlKeybind struct {
	Key       string      `xml:"key,attr"`
	Label     string      `xml:"label,attr"`
	OnRelease string      `xml:"onRelease,attr"`
	Actions   []xmlAction `xml:"action"`
}

type xmlKeyboard struct {
	Keybinds []xmlKeybind `xml:"keybind"`
}

type xmlMousebind struct {
	Button    string      `xml:"button,attr"`
	Direction string      `xml:"direction,attr"`
	Act       string      `xml:"action,attr"`
	Label     string      `xml:"label,attr"`
	Actions   []xmlAction `xml:"action"`
}

type xmlContext struct {
	Name       string         `xml:"name,attr"`
	Mousebinds []xmlMousebind `xml:"mousebind"`
}

type xmlMouse struct {
	Contexts []xmlContext `xml:"context"`
}

type xmlConfig struct {
	Keyboard xmlKeyboard `xml:"keyboard"`
	Mouse    xmlMouse    `xml:"mouse"`
}

// ── Salida ────────────────────────────────────────────────────────────────

type Row struct {
	Desc string   `json:"desc"`
	Keys []string `json:"keys"`
	Raw  string   `json:"raw,omitempty"`
}

type Section struct {
	Title string `json:"title"`
	Rows  []Row  `json:"rows"`
}

type Output struct {
	Sections []Section `json:"sections"`
}

// Orden canónico de secciones. La UI reparte en columnas por título:
// izquierda = {Sistema, Ventanas, Mouse}, el resto a la derecha.
var sectionOrder = []string{"Sistema", "Ventanas", "Mouse", "Apps", "Escritorios", "Menús", "Otros"}

var modifierName = map[string]string{
	"C": "Ctrl", "A": "Alt", "S": "Shift", "W": "Super", "H": "Hyper", "M": "Meta",
}

// Teclas con nombre humano (búsqueda en minúscula).
var namedKeys = map[string]string{
	"return": "Enter", "kp_enter": "Enter", "escape": "Esc", "space": "Space",
	"left": "←", "right": "→", "up": "↑", "down": "↓",
	"tab": "Tab", "print": "Print", "menu": "Menú",
	"prior": "PgUp", "next": "PgDn", "home": "Home", "end": "End",
	"insert": "Insert", "delete": "Supr", "backspace": "Retroceso",
	"xf86audioraisevolume": "Vol +", "xf86audiolowervolume": "Vol −",
	"xf86audiomute": "Mudo", "xf86audiomicmute": "Mic mute",
	"xf86monbrightnessup": "Brillo +", "xf86monbrightnessdown": "Brillo −",
}

func chipFor(tok string) string {
	if len(tok) == 1 {
		if m, ok := modifierName[tok]; ok {
			return m
		}
		return strings.ToUpper(tok)
	}
	if v, ok := namedKeys[strings.ToLower(tok)]; ok {
		return v
	}
	return tok
}

// fnKeys: mapeo físico de teclas de medios de este laptop (Fn+Fx emite el
// keysym XF86*). Si el hardware cambia, ajustar acá.
var fnKeys = map[string]string{
	"xf86audiomute":         "F3",
	"xf86audiolowervolume":  "F4",
	"xf86audioraisevolume":  "F5",
	"xf86monbrightnessdown": "F7",
	"xf86monbrightnessup":   "F8",
}

// keyChips traduce la combinación de rc.xml a chips humanas.
func keyChips(kb xmlKeybind) []string {
	key := kb.Key
	switch {
	case key == "Super_L": // modificador solo (onRelease)
		return []string{"Super"}
	case strings.HasPrefix(key, "XF86"):
		if f, ok := fnKeys[strings.ToLower(key)]; ok {
			return []string{"Fn", f}
		}
		if v, ok := namedKeys[strings.ToLower(key)]; ok {
			return []string{"Fn", v}
		}
		return []string{"Fn", key}
	}
	parts := strings.Split(key, "-")
	chips := make([]string, 0, len(parts))
	for _, p := range parts {
		chips = append(chips, chipFor(p))
	}
	return chips
}

// sectionFor clasifica el keybind por su primera acción (y el comando para
// Execute). Lo que no encaja va a "Otros" para no perderse.
func sectionFor(kb xmlKeybind) string {
	first := ""
	cmd := ""
	for _, a := range kb.Actions {
		if a.Name == "" {
			continue
		}
		if first == "" {
			first = a.Name
		}
		if a.Name == "Execute" && cmd == "" {
			cmd = a.command()
		}
	}
	switch first {
	case "ShowMenu":
		return "Menús"
	case "GoToDesktop", "SendToDesktop":
		return "Escritorios"
	case "NextWindow", "PreviousWindow", "Close", "ToggleMaximize",
		"ToggleFullscreen", "Iconify", "Shade", "ToggleShade", "Move", "Resize",
		"ToggleDecorations", "ToggleAlwaysOnTop", "ToggleOmnipresent":
		return "Ventanas"
	case "Reconfigure":
		return "Sistema"
	case "Execute":
		lower := strings.ToLower(cmd)
		if strings.HasPrefix(kb.Key, "XF86") ||
			strings.Contains(lower, "grim") ||
			strings.Contains(lower, "volume") ||
			strings.Contains(lower, "bright") ||
			strings.Contains(lower, "backligth") { // typo histórico del script
			return "Sistema"
		}
		return "Apps"
	default:
		return "Otros"
	}
}

// descFor usa el label; sin label, describe con la acción principal.
func descFor(kb xmlKeybind) string {
	if kb.Label != "" {
		return kb.Label
	}
	for _, a := range kb.Actions {
		if a.Name == "" {
			continue
		}
		d := a.Name
		if c := a.command(); c != "" {
			d += ": " + c
		} else if m := a.menu(); m != "" {
			d += ": " + m
		} else if t := a.to(); t != "" {
			d += ": " + t
		}
		return d
	}
	return "(sin descripción)"
}

// mouseChip traduce (contexto, botón/dirección, acción) a una chip humana.
func mouseChip(ctx string, mb xmlMousebind) string {
	switch {
	case mb.Act == "Drag" && mb.Button == "W-Left":
		return "Super + arrastre izq"
	case mb.Act == "Drag" && mb.Button == "W-Right":
		return "Super + arrastre der"
	case mb.Act == "Drag" && mb.Button == "A-Left":
		return "Alt + arrastre izq"
	case mb.Act == "Press" && mb.Button == "Right" && strings.Contains(strings.ToLower(ctx), "titlebar"):
		return "Clic der · título"
	case strings.HasSuffix(mb.Button, "Up") || strings.HasSuffix(mb.Button, "Down") ||
		strings.HasSuffix(mb.Direction, "Up") || strings.HasSuffix(mb.Direction, "Down"):
		arrow := "↑"
		if strings.HasSuffix(mb.Button, "Down") || strings.HasSuffix(mb.Direction, "Down") {
			arrow = "↓"
		}
		alt := strings.HasPrefix(mb.Button, "A-") || strings.HasPrefix(mb.Direction, "A-")
		if alt {
			return "Alt + rueda " + arrow + " · escritorio"
		}
		return "Rueda " + arrow + " · escritorio"
	}
	// Genérico para cualquier otro mousebind etiquetado
	mod := ""
	base := mb.Button
	if i := strings.Index(base, "-"); i >= 0 {
		if m, ok := modifierName[base[:i]]; ok {
			mod = m + " + "
			base = base[i+1:]
		}
	}
	btn := map[string]string{"Left": "clic izq", "Right": "clic der", "Middle": "clic medio"}[base]
	if btn == "" {
		btn = strings.ToLower(base)
	}
	switch mb.Act {
	case "Drag":
		return mod + "arrastre " + strings.TrimPrefix(btn, "clic ")
	case "Press", "Click", "DoubleClick":
		return mod + btn
	}
	return mod + base + " · " + strings.ToLower(mb.Act)
}

func appendUnique(rows []Row, r Row) []Row {
	k := r.Desc + "|" + strings.Join(r.Keys, ",")
	for _, existing := range rows {
		if existing.Desc+"|"+strings.Join(existing.Keys, ",") == k {
			return rows
		}
	}
	return append(rows, r)
}

func rcPath() string {
	if len(os.Args) > 1 {
		return os.Args[1]
	}
	if x := os.Getenv("XDG_CONFIG_HOME"); x != "" {
		return filepath.Join(x, "labwc", "rc.xml")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "rc.xml"
	}
	return filepath.Join(home, ".config", "labwc", "rc.xml")
}

func main() {
	data, err := os.ReadFile(rcPath())
	if err != nil {
		fmt.Fprintln(os.Stderr, "keybinds:", err)
		os.Exit(1)
	}
	var cfg xmlConfig
	if err := xml.Unmarshal(data, &cfg); err != nil {
		fmt.Fprintln(os.Stderr, "keybinds: XML:", err)
		os.Exit(1)
	}

	bySection := map[string][]Row{}
	for _, kb := range cfg.Keyboard.Keybinds {
		if kb.Key == "" {
			continue
		}
		r := Row{Desc: descFor(kb), Keys: keyChips(kb), Raw: kb.Key}
		bySection[sectionFor(kb)] = appendUnique(bySection[sectionFor(kb)], r)
	}
	for _, ctx := range cfg.Mouse.Contexts {
		for _, mb := range ctx.Mousebinds {
			if mb.Label == "" {
				continue
			}
			r := Row{
				Desc: mb.Label,
				Keys: []string{mouseChip(ctx.Name, mb)},
				Raw:  ctx.Name + "/" + mb.Button + mb.Direction + "/" + mb.Act,
			}
			bySection["Mouse"] = appendUnique(bySection["Mouse"], r)
		}
	}

	out := Output{}
	for _, title := range sectionOrder {
		if rows := bySection[title]; len(rows) > 0 {
			out.Sections = append(out.Sections, Section{Title: title, Rows: rows})
		}
	}

	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(out); err != nil {
		fmt.Fprintln(os.Stderr, "keybinds: JSON:", err)
		os.Exit(1)
	}
}
