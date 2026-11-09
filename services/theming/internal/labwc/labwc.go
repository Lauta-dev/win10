// Package labwc sincroniza lo que el compositor toma de su rc.xml y que
// depende del tema del sistema: hoy, el tema de iconos de las
// decoraciones (<theme><icon>).
package labwc

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"theming/internal/md3"
	"theming/internal/run"
)

var (
	reTheme = regexp.MustCompile(`(?s)<theme>.*?</theme>`)
	reIcon  = regexp.MustCompile(`<icon>[^<]*</icon>`)
)

// Path devuelve el rc.xml del usuario.
func Path(home string) string {
	return filepath.Join(home, ".config", "labwc", "rc.xml")
}

// SetIconTheme escribe <theme><icon>name</icon> en rc.xml.
// Devuelve changed=false cuando no había nada que cambiar (no reescribe
// ni hace falta recargar). Sin bloque <theme> no toca nada: no inventa
// configuración que el usuario no tenga.
func SetIconTheme(home, name string) (changed bool, err error) {
	if name == "" {
		return false, nil
	}
	path := Path(home)
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, fmt.Errorf("rc.xml: %w", err)
	}
	src := string(raw)
	block := reTheme.FindString(src)
	if block == "" {
		return false, nil
	}

	var newBlock string
	if reIcon.MatchString(block) {
		newBlock = reIcon.ReplaceAllLiteralString(block, "<icon>"+escapeXML(name)+"</icon>")
	} else {
		// Insertar antes de </theme> con la indentación de esa línea + 2.
		idx := strings.LastIndex(block, "</theme>")
		lineStart := strings.LastIndex(block[:idx], "\n") + 1
		indent := block[lineStart:idx]
		newBlock = block[:lineStart] +
			indent + "  <icon>" + escapeXML(name) + "</icon>\n" +
			block[lineStart:]
	}
	if newBlock == block {
		return false, nil
	}
	out := strings.Replace(src, block, newBlock, 1)
	if err := md3.AtomicWrite(path, []byte(out)); err != nil {
		return false, err
	}
	return true, nil
}

// Reload recarga la configuración del compositor (rc.xml incluido).
func Reload() error {
	return run.Fire("labwc", "--reconfigure")
}

// escapeXML cubre lo que puede aparecer en un nombre de tema.
func escapeXML(s string) string {
	r := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;")
	return r.Replace(s)
}
