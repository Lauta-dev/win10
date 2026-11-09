// Package args: tests unitarios para argumentos.
package args

import (
	"strings"
	"testing"
)

// TestParse con --k v, --k=v, --flag, posicionales mezclados.
func TestParse(t *testing.T) {
	tests := []struct {
		input string
		expect Parsed
	}{
		{"--foo bar", Parsed{Opts: map[string]string{"foo": "bar"}, Flags: map[string]bool{}, Pos: []string{}}},
		{"--foo=bar", Parsed{Opts: map[string]string{"foo": "bar"}, Flags: map[string]bool{}, Pos: []string{}}},
		{"--foo --verbose", Parsed{Opts: map[string]string{}, Flags: map[string]bool{"foo": true, "verbose": true}, Pos: []string{}}},
		{"a", Parsed{Opts: map[string]string{}, Flags: map[string]bool{}, Pos: []string{"a"}}},
		{"--key val1 --flag --key2 val2", Parsed{Opts: map[string]string{"key": "val1", "key2": "val2"}, Flags: map[string]bool{"flag": true}, Pos: []string{}}},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := Parse(strings.Split(tt.input, " "))
			// Comparar maps: necesitamos comparar las llaves, pero no podemos acceder a campos privados.
			// Como los campos del test están en el mismo package (args), podemos acceder.
			if len(got.Opts) != len(tt.expect.Opts) {
				t.Errorf("Opts: longitud got %d, want %d", len(got.Opts), len(tt.expect.Opts))
			}
			for k, v := range tt.expect.Opts {
				if got.Opts[k] != v {
					t.Errorf("Opts[%s]: got %q, want %q", k, got.Opts[k], v)
				}
			}
			if len(got.Flags) != len(tt.expect.Flags) {
				t.Errorf("Flags: longitud got %d, want %d", len(got.Flags), len(tt.expect.Flags))
			}
			for k, v := range tt.expect.Flags {
				if got.Flags[k] != v {
					t.Errorf("Flags[%s]: got %v, want %v", k, got.Flags[k], v)
				}
			}
			if len(got.Pos) != len(tt.expect.Pos) {
				t.Errorf("Pos: longitud got %d, want %d", len(got.Pos), len(tt.expect.Pos))
			}
			for i, v := range tt.expect.Pos {
				if got.Pos[i] != v {
					t.Errorf("Pos[%d]: got %q, want %q", i, got.Pos[i], v)
				}
			}
		})
	}
}

// TestOpt con default.
func TestOpt(t *testing.T) {
	p := Parse([]string{"--color", "red", "--size"})
	if v := p.Opt("color", "blue"); v != "red" {
		t.Errorf("Opt color: got %q, want red", v)
	}
	if v := p.Opt("size", "10"); v != "10" { // --size es flag, no option, debe devolver default
		t.Errorf("Opt size: got %q, want default 10", v)
	}
	if v := p.Opt("missing", "default"); v != "default" {
		t.Errorf("Opt missing: got %q, want default", v)
	}
}