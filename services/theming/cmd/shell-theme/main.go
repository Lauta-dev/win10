// Command shell-theme aplica un preset de data/shell-themes.json a todo
// el stack: md3 dual (shell), GTK/Qt (Fluent por modo), labwc y alacritty.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"theming/internal/args"
	"theming/internal/gtk"
	"theming/internal/labwc"
	"theming/internal/md3"
)

func main() {
	parsed := args.Parse(os.Args[1:])
	mode := parsed.Opt("mode", "")
	printOnly := parsed.Flags["print"]

	home, err := os.UserHomeDir()
	if err != nil {
		fatal(err)
	}
	exe, err := os.Executable()
	if err != nil {
		fatal(err)
	}
	exeDir := filepath.Dir(exe)
	catalogPath := filepath.Join(exeDir, "..", "data", "shell-themes.json")
	dataPath := filepath.Join(exeDir, "..", "data", "gtk-variants.json")
	exportsPath := filepath.Join(exeDir, "..", "data", "theme-exports.json")

	args := parsed.Pos
	id := ""
	if len(args) > 0 {
		id = args[0]
	}
	if id == "" || id == "matugen" {
		fmt.Fprintf(os.Stderr, "shell-theme: id invalido ('%s'); 'matugen' se regenera con matugen-apply\n", id)
		os.Exit(1)
	}
	if mode != gtk.ModeDark && mode != gtk.ModeLight {
		fmt.Fprintln(os.Stderr, "shell-theme: --mode <dark|light> requerido")
		os.Exit(1)
	}

	catalog, err := md3.LoadCatalog(catalogPath)
	if err != nil {
		fatal(err)
	}
	preset := catalog.ByID(id)
	if preset == nil {
		fmt.Fprintf(os.Stderr, "shell-theme: preset '%s' inexistente\n", id)
		os.Exit(1)
	}

	doc, err := md3.BuildActive(preset)
	if err != nil {
		fatal(err)
	}
	exp, err := md3.LoadExports(exportsPath)
	if err != nil {
		fatal(err)
	}
	raw, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		fatal(err)
	}
	if printOnly {
		fmt.Println(string(raw))
		return
	}

	// Escritura atomica: Style observa el archivo con watch.
	activePath := filepath.Join(home, ".cache", "matugen-active.json")
	if err := md3.AtomicWrite(activePath, raw); err != nil {
		fatal(err)
	}
	md3Path := filepath.Join(home, ".cache", "qs-matugen-md3.json")
	if err := md3.AtomicWrite(md3Path, raw); err != nil {
		fatal(err)
	}

	// Slot activo de terminal y labwc (mismas rutas que matugen genera).
	modeMd3 := doc.Dark["md3"]
	if mode == gtk.ModeLight {
		modeMd3 = doc.Light["md3"]
	}
	alacrittyPath := filepath.Join(home, ".config", "alacritty", "color.toml")
	if err := md3.AtomicWrite(alacrittyPath, []byte(md3.RenderAlacritty(exp, modeMd3))); err != nil {
		fatal(err)
	}
	themercDir := filepath.Join(home, ".local", "share", "themes", "matugen", "openbox-3")
	if err := os.MkdirAll(themercDir, 0o755); err != nil {
		fatal(err)
	}
	if err := md3.AtomicWrite(filepath.Join(themercDir, "themerc"), []byte(md3.RenderThemerc(exp, modeMd3))); err != nil {
		fatal(err)
	}
	_ = labwc.Reload()

	// GTK por modo sobre la familia preferida; se conserva -compact.
	resolver := gtk.NewResolver(dataPath, home)
	gtkArg := ""
	curGtk := gtk.Get(gtk.IfaceSchema, gtk.KeyGtkTheme)
	for _, fam := range preset.Gtk {
		if fam == "auto" {
			gtkArg = "auto"
			break
		}
		var cands []string
		if mode == gtk.ModeDark {
			cands = []string{fam + "-Dark", fam + "-dark", fam}
		} else {
			cands = []string{fam + "-Light", fam + "-light", fam}
		}
		for _, cand := range cands {
			if resolver.Exists("gtk", cand) {
				gtkArg = cand
				break
			}
		}
		if gtkArg != "" {
			break
		}
	}
	if gtkArg == "" {
		gtkArg = "auto"
	}
	if gtkArg != "auto" && isCompact(curGtk) && resolver.Exists("gtk", gtkArg+"-compact") {
		gtkArg += "-compact"
	}

	// gtk-apply corre en el mismo directorio; su stderr pasa tal cual.
	gtkBin := filepath.Join(exeDir, "gtk-apply")
	cmd := exec.Command(gtkBin, "--gtk", gtkArg, "--icons", "auto", "--mode", mode)
	cmd.Stderr = os.Stderr
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	if err := cmd.Run(); err != nil {
		fatal(err)
	}
	resolved := gtkArg
	for _, line := range strings.Split(stdout.String(), "\n") {
		if rest, ok := strings.CutPrefix(line, gtk.Marker); ok {
			resolved = rest
		}
	}
	fmt.Printf("%s%s\n", gtk.Marker, resolved)
}

func isCompact(name string) bool {
	return strings.Contains(strings.ToLower(name), "compact")
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
