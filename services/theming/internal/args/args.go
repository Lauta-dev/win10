// Package args parsea argv con orden libre: --clave valor, --clave=valor,
// --flag y posicionales mezclados, como hacian los scripts bash.
package args

import "strings"

// Parsed es el resultado de Parse.
type Parsed struct {
	Opts  map[string]string
	Flags map[string]bool
	Pos   []string
}

// Parse separa opciones, flags y posicionales en cualquier orden.
func Parse(argv []string) Parsed {
	p := Parsed{Opts: map[string]string{}, Flags: map[string]bool{}, Pos: []string{}}
	for i := 0; i < len(argv); i++ {
		a := argv[i]
		if !strings.HasPrefix(a, "--") || a == "--" {
			p.Pos = append(p.Pos, a)
			continue
		}
		name := strings.TrimPrefix(a, "--")
		if eq := strings.IndexByte(name, '='); eq >= 0 {
			p.Opts[name[:eq]] = name[eq+1:]
			continue
		}
		if i+1 < len(argv) && !strings.HasPrefix(argv[i+1], "--") {
			p.Opts[name] = argv[i+1]
			i++
			continue
		}
		p.Flags[name] = true
	}
	return p
}

// Opt devuelve la opcion o el default.
func (p Parsed) Opt(name, def string) string {
	if v, ok := p.Opts[name]; ok {
		return v
	}
	return def
}
