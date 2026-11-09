// Package md3 deriva paletas Material3 desde las semillas de un preset
// (data/shell-themes.json) y renderiza los slots que consumen la shell,
// alacritty y labwc.
package md3

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Black y White como constantes: se mezclan, nunca se hardcodean en formulas.
const (
	Black = "#000000"
	White = "#FFFFFF"
)

// RequiredRoles son las claves que Style lee de matugen-active.json.
// Build falla si falta alguna: mejor fallar que escribir un JSON incompleto.
var RequiredRoles = []string{
	"background", "error", "error_container", "inverse_on_surface", "inverse_primary",
	"inverse_surface", "on_background", "on_error", "on_error_container", "on_primary",
	"on_primary_container", "on_primary_fixed", "on_primary_fixed_variant", "on_secondary",
	"on_secondary_container", "on_secondary_fixed", "on_secondary_fixed_variant", "on_surface",
	"on_surface_variant", "on_tertiary", "on_tertiary_container", "on_tertiary_fixed",
	"on_tertiary_fixed_variant", "outline", "outline_variant", "primary", "primary_container",
	"primary_fixed", "primary_fixed_dim", "scrim", "secondary", "secondary_container",
	"secondary_fixed", "secondary_fixed_dim", "shadow", "source_color", "surface", "surface_bright",
	"surface_container", "surface_container_high", "surface_container_highest",
	"surface_container_low", "surface_container_lowest", "surface_dim", "surface_tint",
	"surface_variant", "tertiary", "tertiary_container", "tertiary_fixed", "tertiary_fixed_dim",
}

// Seeds son los 5 colores semilla de un modo (dark o light).
type Seeds struct {
	Primary    string `json:"primary"`
	Secondary  string `json:"secondary"`
	Tertiary   string `json:"tertiary"`
	Background string `json:"background"`
	Foreground string `json:"foreground"`
}

// Preset es un tema del catalogo. Dark/Light nil = sin semillas (matugen).
type Preset struct {
	ID    string   `json:"id"`
	Label string   `json:"label"`
	Hint  string   `json:"hint"`
	Gtk   []string `json:"gtk"`
	Dark  *Seeds   `json:"dark"`
	Light *Seeds   `json:"light"`
}

// Catalog es data/shell-themes.json.
type Catalog struct {
	Themes []Preset `json:"themes"`
}

// LoadCatalog lee y parsea el catalogo de presets.
func LoadCatalog(path string) (Catalog, error) {
	var catalog Catalog
	raw, err := os.ReadFile(path)
	if err != nil {
		return catalog, fmt.Errorf("catalogo %q: %w", path, err)
	}
	if err := json.Unmarshal(raw, &catalog); err != nil {
		return catalog, fmt.Errorf("catalogo %q: %w", path, err)
	}
	return catalog, nil
}

// ByID busca un preset por id. Nil si no existe o no trae semillas.
func (c Catalog) ByID(id string) *Preset {
	for i := range c.Themes {
		p := &c.Themes[i]
		if p.ID == id && p.Dark != nil && p.Light != nil {
			return p
		}
	}
	return nil
}

// Mix mezcla a hacia b en t (0 = a, 1 = b) en RGB.
func Mix(a, b string, t float64) string {
	ra, rb := parseHex(a), parseHex(b)
	var out [3]int
	for i := range 3 {
		v := float64(ra[i]) + float64(rb[i]-ra[i])*t
		out[i] = clampInt(int(v+0.5), 0, 255)
	}
	return fmt.Sprintf("#%02X%02X%02X", out[0], out[1], out[2])
}

func parseHex(h string) [3]int {
	h = strings.TrimPrefix(h, "#")
	var rgb [3]int
	if len(h) != 6 {
		return rgb
	}
	for i := range 3 {
		var v int
		fmt.Sscanf(h[2*i:2*i+2], "%02x", &v)
		rgb[i] = v
	}
	return rgb
}

func clampInt(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// Alpha agrega canal alfa 0-1 al hex (para overlays del themerc).
func Alpha(hex string, a float64) string {
	return hex + fmt.Sprintf("%02X", clampInt(int(a*255+0.5), 0, 255))
}

// accentRoles genera los 8 roles M3 de un acento tiñendo con el fondo.
func accentRoles(name, seed, bg string, dark bool) map[string]string {
	on := White
	cont := Mix(seed, White, 0.84)
	onCont := Mix(seed, Black, 0.70)
	if dark {
		on = Mix(seed, Black, 0.82)
		cont = Mix(seed, bg, 0.80)
		onCont = Mix(seed, White, 0.85)
	}
	return map[string]string{
		name:                            seed,
		"on_" + name:                    on,
		name + "_container":             cont,
		"on_" + name + "_container":     onCont,
		name + "_fixed":                 Mix(seed, White, 0.60),
		name + "_fixed_dim":             Mix(seed, White, 0.35),
		"on_" + name + "_fixed":         Mix(seed, Black, 0.75),
		"on_" + name + "_fixed_variant": Mix(seed, Black, 0.55),
	}
}

// Build deriva la paleta md3 completa de un modo. other es el modo opuesto
// (para los inversos). Error si falta algun rol requerido.
func Build(seeds, other Seeds, dark bool) (map[string]string, error) {
	bg, fg := seeds.Background, seeds.Foreground
	m := map[string]string{}
	for _, acc := range []struct {
		name, seed string
	}{
		{"primary", seeds.Primary},
		{"secondary", seeds.Secondary},
		{"tertiary", seeds.Tertiary},
	} {
		for k, v := range accentRoles(acc.name, acc.seed, bg, dark) {
			m[k] = v
		}
	}
	if dark {
		m["surface_dim"] = Mix(bg, Black, 0.25)
		m["surface_bright"] = Mix(bg, White, 0.20)
		m["surface_container_lowest"] = Mix(bg, Black, 0.38)
		m["surface_container_low"] = Mix(bg, Black, 0.18)
		m["surface_container"] = Mix(bg, White, 0.055)
		m["surface_container_high"] = Mix(bg, White, 0.10)
		m["surface_container_highest"] = Mix(bg, White, 0.15)
		m["error"] = "#F2B8B8"
		m["on_error"] = "#601410"
		m["error_container"] = "#8C1D18"
		m["on_error_container"] = "#F9DEDC"
	} else {
		m["surface_dim"] = Mix(bg, Black, 0.10)
		m["surface_bright"] = Mix(bg, White, 0.60)
		m["surface_container_lowest"] = Mix(bg, White, 0.80)
		m["surface_container_low"] = Mix(bg, White, 0.45)
		m["surface_container"] = Mix(bg, Black, 0.035)
		m["surface_container_high"] = Mix(bg, Black, 0.07)
		m["surface_container_highest"] = Mix(bg, Black, 0.11)
		m["error"] = "#B3261E"
		m["on_error"] = White
		m["error_container"] = "#F9DEDC"
		m["on_error_container"] = "#410E0B"
	}
	surfaceVariantMix := 0.06
	if dark {
		surfaceVariantMix = 0.10
	}
	outlineVariantMix := 0.10
	if dark {
		outlineVariantMix = 0.14
	}
	invSurface, invOnSurface := other.Background, other.Foreground
	if dark {
		invSurface, invOnSurface = other.Foreground, other.Background
	}
	m["background"] = bg
	m["on_background"] = fg
	m["surface"] = bg
	m["on_surface"] = fg
	m["surface_variant"] = Mix(bg, fg, surfaceVariantMix)
	m["on_surface_variant"] = Mix(fg, bg, 0.35)
	m["surface_tint"] = seeds.Primary
	m["inverse_surface"] = invSurface
	m["inverse_on_surface"] = invOnSurface
	m["inverse_primary"] = other.Primary
	m["outline"] = Mix(fg, bg, 0.45)
	m["outline_variant"] = Mix(bg, fg, outlineVariantMix)
	m["scrim"] = Black
	m["shadow"] = Black
	m["source_color"] = seeds.Primary
	for _, role := range RequiredRoles {
		if _, ok := m[role]; !ok {
			return nil, fmt.Errorf("falta rol md3: %q", role)
		}
	}
	return m, nil
}

// ActiveDoc es el JSON que lee Style: md3 dual + meta del preset.
type ActiveDoc struct {
	Dark    map[string]map[string]string `json:"dark"`
	Light   map[string]map[string]string `json:"light"`
	Palette map[string]string            `json:"palette"`
}

// BuildActive genera el documento activo completo para un preset.
func BuildActive(preset *Preset) (ActiveDoc, error) {
	dark, err := Build(*preset.Dark, *preset.Light, true)
	if err != nil {
		return ActiveDoc{}, fmt.Errorf("dark: %w", err)
	}
	light, err := Build(*preset.Light, *preset.Dark, false)
	if err != nil {
		return ActiveDoc{}, fmt.Errorf("light: %w", err)
	}
	return ActiveDoc{
		Dark:  map[string]map[string]string{"md3": dark},
		Light: map[string]map[string]string{"md3": light},
		Palette: map[string]string{
			"theme": preset.ID, "source": preset.Dark.Primary,
		},
	}, nil
}

// AlacrittySection es una seccion [colors.X] con lineas con tokens {rol}.
type AlacrittySection struct {
	Name  string   `json:"name"`
	Lines []string `json:"lines"`
}

// LabwcColor es una linea "clave: valor" del themerc. Key vacia = en blanco.
// Alpha 0 = sin alfa; >0 agrega canal alfa al hex.
type LabwcColor struct {
	Key   string  `json:"key"`
	Role  string  `json:"role"`
	Alpha float64 `json:"alpha"`
}

// Exports son las plantillas de data/theme-exports.json.
type Exports struct {
	Alacritty struct {
		Header   string             `json:"header"`
		Sections []AlacrittySection `json:"sections"`
	} `json:"alacritty"`
	Labwc struct {
		Static string       `json:"static"`
		Colors []LabwcColor `json:"colors"`
	} `json:"labwc"`
}

// LoadExports lee las plantillas de exportacion.
func LoadExports(path string) (Exports, error) {
	var exp Exports
	raw, err := os.ReadFile(path)
	if err != nil {
		return exp, fmt.Errorf("exports %q: %w", path, err)
	}
	if err := json.Unmarshal(raw, &exp); err != nil {
		return exp, fmt.Errorf("exports %q: %w", path, err)
	}
	return exp, nil
}

var tokenRe = regexp.MustCompile(`\{([a-z0-9_]+)\}`)

// expand reemplaza {rol} por su hex. Rol ausente = cadena vacia.
func expand(line string, md3 map[string]string) string {
	return tokenRe.ReplaceAllStringFunc(line, func(token string) string {
		return md3[token[1:len(token)-1]]
	})
}

// RenderAlacritty genera color.toml desde el md3 del modo.
func RenderAlacritty(exp Exports, md3 map[string]string) string {
	var sb strings.Builder
	sb.WriteString(exp.Alacritty.Header + "\n\n")
	for _, sec := range exp.Alacritty.Sections {
		fmt.Fprintf(&sb, "[colors.%s]\n", sec.Name)
		for _, line := range sec.Lines {
			sb.WriteString(expand(line, md3) + "\n")
		}
		sb.WriteString("\n")
	}
	return sb.String()
}

// RenderThemerc genera el themerc openbox desde el md3 del modo.
func RenderThemerc(exp Exports, md3 map[string]string) string {
	var sb strings.Builder
	sb.WriteString(exp.Labwc.Static)
	sb.WriteString("\n")
	for _, c := range exp.Labwc.Colors {
		if c.Key == "" {
			sb.WriteString("\n")
			continue
		}
		value := md3[c.Role]
		if c.Alpha > 0 {
			value = Alpha(value, c.Alpha)
		}
		fmt.Fprintf(&sb, "%s: %s\n", c.Key, value)
	}
	return sb.String()
}

// AtomicWrite escribe data en path via tmp+rename (Style observa con watch).
func AtomicWrite(path string, data []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), ".tmp-*")
	if err != nil {
		return fmt.Errorf("tmp para %q: %w", path, err)
	}
	tmpName := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return fmt.Errorf("tmp para %q: %w", path, err)
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("tmp para %q: %w", path, err)
	}
	if err := os.Chmod(tmpName, 0o644); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("tmp para %q: %w", path, err)
	}
	if err := os.Rename(tmpName, path); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("tmp para %q: %w", path, err)
	}
	return nil
}
