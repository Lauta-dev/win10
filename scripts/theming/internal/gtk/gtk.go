// Package gtk resuelve y aplica temas GTK e iconos en todos los frentes
// que GTK lee en labwc: gsettings, settings.ini (gtk3/gtk4, que pisa a
// gsettings), gtkrc-2.0, accent-color y el scheme de mousepad.
package gtk

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"theming/internal/run"
)

// Modos y valores sin magic strings.
const (
	ModeDark  = "dark"
	ModeLight = "light"

	IfaceSchema = "org.gnome.desktop.interface"
	MouseSchema = "org.xfce.mousepad.preferences.view"

	KeyGtkTheme   = "gtk-theme"
	KeyIconTheme  = "icon-theme"
	KeyColorTheme = "color-scheme"
	KeyAccent     = "accent-color"
	KeyMouseView  = "color-scheme"

	SchemeDark  = "prefer-dark"
	SchemeLight = "prefer-light"

	FallbackDark  = "adw-gtk3-dark"
	FallbackLight = "adw-gtk3"
	// adw-gtk3-light NO existe: el light es adw-gtk3 a secas.

	SysThemeDir = "/usr/share/themes"
	SysIconDir  = "/usr/share/icons"

	Marker = "__GTK_THEME__="
)

var (
	darkMark  = regexp.MustCompile(`(?i)dark`)
	darkLight = regexp.MustCompile(`(?i)[-_](dark|light)$`)

	darkSuffixes  = []string{"-dark", "-Dark", "_dark", "_Dark"}
	lightSuffixes = []string{"-Light", "-light", "_Light", "_light"}

	// Hue por nombre de accent-color GNOME, del primario al mas cercano.
	accentHues = map[string]float64{
		"red": 350.0, "orange": 25.0, "yellow": 48.0, "green": 135.0,
		"teal": 178.0, "blue": 214.0, "purple": 283.0, "pink": 327.0,
	}
)

// Variant describe las variantes light/dark de una familia de temas.
type Variant struct {
	Light   string            `json:"light"`
	Dark    string            `json:"dark"`
	Aliases map[string]string `json:"aliases"`
}

// Family agrupa variantes gtk e iconos bajo un mismo nombre.
type Family struct {
	Gtk   *Variant `json:"gtk"`
	Icons *Variant `json:"icons"`
}

// Catalog es data/gtk-variants.json.
type Catalog struct {
	Families []Family `json:"families"`
}

// Resolver resuelve nombres contra el filesystem. Los dirs se inyectan
// para testear sin tocar /usr/share ni $HOME.
type Resolver struct {
	DataPath string
	GtkDirs  []string
	IconDirs []string
}

// NewResolver arma el resolver real para un home dado.
func NewResolver(dataPath, home string) Resolver {
	return Resolver{
		DataPath: dataPath,
		GtkDirs:  []string{SysThemeDir, filepath.Join(home, ".themes")},
		IconDirs: []string{SysIconDir,
			filepath.Join(home, ".local", "share", "icons"),
			filepath.Join(home, ".icons")},
	}
}

func dirsFor(r Resolver, kind string) []string {
	if kind == "gtk" {
		return r.GtkDirs
	}
	return r.IconDirs
}

// Exists dice si el tema existe como directorio.
func (r Resolver) Exists(kind, name string) bool {
	if name == "" {
		return false
	}
	for _, d := range dirsFor(r, kind) {
		if st, err := os.Stat(filepath.Join(d, name)); err == nil && st.IsDir() {
			return true
		}
	}
	return false
}

// generic infiere la variante cuando el tema no esta en ninguna familia:
// sin marca -dark es light; con marca se prueba la base sin sufijo.
func (r Resolver) generic(kind, name, mode string) string {
	if mode == ModeDark {
		if darkMark.MatchString(name) {
			return name
		}
		for _, suf := range darkSuffixes {
			if r.Exists(kind, name+suf) {
				return name + suf
			}
		}
		return name
	}
	if m := darkLight.FindStringSubmatch(name); m != nil && strings.ToLower(m[1]) == ModeDark {
		base := name[:len(name)-len(m[0])]
		if r.Exists(kind, base) {
			return base
		}
		for _, suf := range lightSuffixes {
			if r.Exists(kind, base+suf) {
				return base + suf
			}
		}
	}
	return name
}

// Auto resuelve la variante del modo pedido: 1) familia del JSON,
// 2) inferencia generica, 3) conservar el actual.
func (r Resolver) Auto(kind, current, mode string) string {
	target := current
	data, err := os.ReadFile(r.DataPath)
	if err != nil {
		return r.generic(kind, current, mode)
	}
	var catalog Catalog
	if err := json.Unmarshal(data, &catalog); err != nil {
		return r.generic(kind, current, mode)
	}
	matched := false
	for _, fam := range catalog.Families {
		var spec *Variant
		if kind == "gtk" {
			spec = fam.Gtk
		} else {
			spec = fam.Icons
		}
		if spec == nil {
			continue
		}
		isMember := current == spec.Light || current == spec.Dark
		if !isMember {
			_, isMember = spec.Aliases[current]
		}
		if !isMember {
			continue
		}
		base := spec.Dark
		if mode == ModeLight {
			base = spec.Light
		}
		if base != "" {
			lower := strings.ToLower(current)
			if kind == "gtk" && strings.Contains(lower, "compact") &&
				!strings.Contains(strings.ToLower(base), "compact") &&
				r.Exists(kind, base+"-compact") {
				base += "-compact"
			}
			if r.Exists(kind, base) {
				target = base
			}
		}
		matched = true
		break
	}
	if !matched {
		target = r.generic(kind, current, mode)
	}
	return target
}

// Resolve valida el pedido con fallbacks e informa por stderr igual que antes:
// tema inexistente -> actual si es valido -> adw-gtk3 (dark: -dark).
func (r Resolver) Resolve(kind, req, cur, mode string) string {
	target := req
	if req == "auto" {
		target = r.Auto(kind, cur, mode)
	}
	if r.Exists(kind, target) {
		return target
	}
	fmt.Fprintf(os.Stderr, "gtk-apply: tema %s '%s' no existe\n", label(kind), target)
	if r.Exists(kind, cur) {
		fmt.Fprintf(os.Stderr, "gtk-apply: conservo el actual ('%s')\n", cur)
		return cur
	}
	if kind == "gtk" {
		if mode == ModeDark && r.Exists(kind, FallbackDark) {
			return FallbackDark
		}
		if r.Exists(kind, FallbackLight) {
			return FallbackLight
		}
	}
	return target
}

func label(kind string) string {
	if kind == "gtk" {
		return "GTK"
	}
	return "de iconos"
}

// AccentName mapea el primario md3 del modo al accent-color GNOME mas cercano.
// Vacío cuando no hay paleta: el actual se conserva.
func AccentName(md3Primary string) string {
	hex := strings.TrimPrefix(md3Primary, "#")
	if len(hex) != 6 {
		return ""
	}
	var rgb [3]float64
	for i := range 3 {
		var v int
		if _, err := fmt.Sscanf(hex[2*i:2*i+2], "%02x", &v); err != nil {
			return ""
		}
		rgb[i] = float64(v) / 255.0
	}
	h, s := rgbToHsv(rgb[0], rgb[1], rgb[2])
	h *= 360.0
	if s < 0.12 {
		return "slate"
	}
	best, bestDist := "", 360.0
	for name, ref := range accentHues {
		d := abs(ref - h)
		if 360-d < d {
			d = 360 - d
		}
		if d < bestDist {
			best, bestDist = name, d
		}
	}
	return best
}

func rgbToHsv(r, g, b float64) (h, s float64) {
	max := r
	if g > max {
		max = g
	}
	if b > max {
		max = b
	}
	min := r
	if g < min {
		min = g
	}
	if b < min {
		min = b
	}
	d := max - min
	if max == 0 {
		return 0, 0
	}
	s = d / max
	if d == 0 {
		return 0, s
	}
	switch max {
	case r:
		h = (g - b) / d
		if g < b {
			h += 6
		}
	case g:
		h = (b-r)/d + 2
	default:
		h = (r-g)/d + 4
	}
	return h / 6, s
}

func abs(f float64) float64 {
	if f < 0 {
		return -f
	}
	return f
}

// md3Primary lee el primario del modo desde qs-matugen-md3.json.
func md3Primary(home, mode string) string {
	raw, err := os.ReadFile(filepath.Join(home, ".cache", "qs-matugen-md3.json"))
	if err != nil {
		return ""
	}
	var doc map[string]map[string]map[string]string
	if err := json.Unmarshal(raw, &doc); err != nil {
		return ""
	}
	return doc[mode]["md3"]["primary"]
}

// AccentForMode resuelve el accent-color para el modo pedido.
func AccentForMode(home, mode string) string {
	return AccentName(md3Primary(home, mode))
}

// WriteSettingsINI escribe gtk3/gtk4 linea por linea, preservando el resto.
func WriteSettingsINI(home, gtk, icons, mode string) error {
	pref := "0"
	if mode == ModeDark {
		pref = "1"
	}
	wanted := map[string]string{
		"gtk-theme-name":                    gtk,
		"gtk-icon-theme-name":               icons,
		"gtk-application-prefer-dark-theme": pref,
	}
	paths := []string{
		filepath.Join(home, ".config", "gtk-3.0", "settings.ini"),
		filepath.Join(home, ".config", "gtk-4.0", "settings.ini"),
	}
	for _, path := range paths {
		if err := editINI(path, wanted); err != nil {
			return fmt.Errorf("settings.ini %q: %w", path, err)
		}
	}
	return nil
}

func editINI(path string, wanted map[string]string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	raw, err := os.ReadFile(path)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	var out []string
	seen := map[string]bool{}
	inSection := false
	hasSection := false
	if len(raw) > 0 {
		for _, line := range strings.Split(string(raw), "\n") {
			// strings.Split deja un ultimo "" si hay trailing newline:
			// se reconstruye al final con Join + "\n".
			s := strings.TrimSpace(line)
			if strings.HasPrefix(s, "[") && strings.HasSuffix(s, "]") {
				inSection = s == "[Settings]"
				if inSection {
					hasSection = true
				}
				out = append(out, line)
				continue
			}
			if inSection && strings.Contains(s, "=") &&
				!strings.HasPrefix(s, "#") && !strings.HasPrefix(s, ";") {
				key := strings.TrimSpace(strings.SplitN(s, "=", 2)[0])
				if val, ok := wanted[key]; ok {
					out = append(out, key+"="+val)
					seen[key] = true
					continue
				}
			}
			out = append(out, line)
		}
		// Quitar el "" final del Split para no duplicar newline.
		if len(out) > 0 && out[len(out)-1] == "" {
			out = out[:len(out)-1]
		}
	}
	if !hasSection {
		out = append(out, "[Settings]")
	}
	// Orden estable: mismo orden que el mapa no garantiza; usar claves fijas.
	for _, key := range []string{"gtk-theme-name", "gtk-icon-theme-name", "gtk-application-prefer-dark-theme"} {
		if !seen[key] {
			out = append(out, key+"="+wanted[key])
		}
	}
	return os.WriteFile(path, []byte(strings.Join(out, "\n")+"\n"), 0o644)
}

// WriteGtkrc actualiza ~/.gtkrc-2.0 si existe, conservando el resto.
func WriteGtkrc(home, gtk, icons string) error {
	path := filepath.Join(home, ".gtkrc-2.0")
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	lines := strings.Split(string(raw), "\n")
	if len(lines) > 0 && lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	var out []string
	seenGtk, seenIcons := false, false
	for _, line := range lines {
		switch {
		case strings.HasPrefix(line, "gtk-theme-name="):
			out = append(out, `gtk-theme-name="`+gtk+`"`)
			seenGtk = true
		case strings.HasPrefix(line, "gtk-icon-theme-name="):
			out = append(out, `gtk-icon-theme-name="`+icons+`"`)
			seenIcons = true
		default:
			out = append(out, line)
		}
	}
	// Igual que el sed original: las claves quedan garantizadas.
	if !seenGtk {
		out = append(out, `gtk-theme-name="`+gtk+`"`)
	}
	if !seenIcons {
		out = append(out, `gtk-icon-theme-name="`+icons+`"`)
	}
	return os.WriteFile(path, []byte(strings.Join(out, "\n")+"\n"), 0o644)
}

// Get lee una clave gsettings (sin comillas simples).
func Get(schema, key string) string {
	out, err := run.Out("gsettings", "get", schema, key)
	if err != nil {
		return ""
	}
	return strings.Trim(strings.TrimSpace(out), "'")
}

// Set escribe una clave gsettings. Los errores se propagan con contexto.
func Set(schema, key, value string) error {
	return run.Fire("gsettings", "set", schema, key, value)
}

// HasSchemas dice si gsettings responde (evita colgarse sin sesion).
func HasSchemas() bool {
	return run.Fire("gsettings", "list-schemas") == nil
}

// ApplyMousepad fija classic/oblivion segun modo, respetando eleccion manual.
func ApplyMousepad(mode string) error {
	out, err := run.Out("gsettings", "list-schemas")
	if err != nil || !strings.Contains(out, MouseSchema) {
		return nil
	}
	want := "classic"
	if mode == ModeDark {
		want = "oblivion"
	}
	switch cur := Get(MouseSchema, KeyMouseView); cur {
	case "none", "classic", "oblivion":
		return Set(MouseSchema, KeyMouseView, want)
	default:
		return nil
	}
}

// ApplyColorScheme pasa por el esquema opuesto y vuelve (reload de apps).
func ApplyColorScheme(mode string) error {
	want := SchemeLight
	if mode == ModeDark {
		want = SchemeDark
	}
	opp := SchemeDark
	if want == SchemeDark {
		opp = SchemeLight
	}
	if err := Set(IfaceSchema, KeyColorTheme, opp); err != nil {
		return err
	}
	return Set(IfaceSchema, KeyColorTheme, want)
}
