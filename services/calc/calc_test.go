// Package main: tests unitarios para calc-eval.
// Tests table-driven para parse, Value y funcs.
package main

import (
	"strings"
	"testing"
)

// TestParseExamples verifica los ejemplos del doc.md.
func TestParseExamples(t *testing.T) {
	tests := []struct {
		input string
		want  string
		exact bool
		num   string
		den   string
		approx string
		ok    bool
	}{
		// Ejemplo de docs: "200 - { 50 + 6 * (20 - (3 + 7)) + 25 }" => 65
		{input: "200 - { 50 + 6 * (20 - (3 + 7)) + 25 }", want: "65", exact: true, ok: true},
		// 1/3 exacto con num/den/approx
		{input: "1/3", want: "1/3", exact: true, num: "1", den: "3", approx: "0.3333333333", ok: true},
		// División por cero error
		{input: "2/0", ok: false, want: "", exact: false},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			v, err := parse(tt.input)
			if tt.ok {
				if err != nil {
					t.Fatalf("parse devolvió error inesperado: %v", err)
				}
				// Verificar format
				text, exact := v.format()
				if text != tt.want {
					t.Errorf("format: got %q, want %q", text, tt.want)
				}
				if exact != tt.exact {
					t.Errorf("exact: got %v, want %v", exact, tt.exact)
				}
				if tt.num != "" {
					num, den, ok := numDen(v)
					if !ok {
						t.Error("numDen esperado true pero falló")
					}
					if num != tt.num || den != tt.den {
						t.Errorf("numDen: got %s/%s, want %s/%s", num, den, tt.num, tt.den)
					}
					approx := approxOf(v)
					if approx != tt.approx {
						t.Errorf("approx: got %q, want %q", approx, tt.approx)
					}
				}
			} else {
				if err == nil {
					t.Error("parse debería haber fallado pero no falló")
				}
				// No necesitamos verificar más
			}
		})
	}
}

// TestPrecedenceAndAssociativity prueba precedencia y asociatividad de ^.
func TestPrecedenceAndAssociativity(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"2^3^2", "512"}, // derecho: 2^(3^2)
		{"3^2^3", "6561"}, // derecho: 3^(2^3)
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			v, err := parse(tt.input)
			if err != nil {
				t.Fatalf("parse error: %v", err)
			}
			text, _ := v.format()
			if text != tt.want {
				t.Errorf("got %q, want %q", text, tt.want)
			}
		})
	}
}

// TestUnaryAndPostfix verifica unarios y % postfijo.
func TestUnaryAndPostfix(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"-2^2", "4"},
		{"2!", "2"},
		{"50%", "1/2"},
		{"2pi", "6.283185307"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			v, err := parse(tt.input)
			if err != nil {
				t.Fatalf("parse error: %v", err)
			}
			text, _ := v.format()
			if text != tt.want {
				t.Errorf("got %q, want %q", text, tt.want)
			}
		})
	}
}

// TestImplicitMultiplication verifica multiplicación implícita.
func TestImplicitMultiplication(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"2(3+4)", "14"},
		{"2pi", "6.283185307"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			v, err := parse(tt.input)
			if err != nil {
				t.Fatalf("parse error: %v", err)
			}
			text, _ := v.format()
			if text != tt.want {
				t.Errorf("got %q, want %q", text, tt.want)
			}
		})
	}
}

// TestFracCommand verifica LaTeX \frac.
func TestFracCommand(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"\\frac 2 4", "1/2"},
		{"\\frac{1+1}{4}", "1/2"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			v, err := parse(tt.input)
			if err != nil {
				t.Fatalf("parse error: %v", err)
			}
			text, _ := v.format()
			if text != tt.want {
				t.Errorf("got %q, want %q", text, tt.want)
			}
		})
	}
}

// TestInvalidInput verifica entradas inválidas: vacío, paréntesis desbalanceados, token inválido.
func TestInvalidInput(t *testing.T) {
	tests := []struct {
		input    string
		wantErr  string
	}{
		{"", "Expresión inválida"},
		{"(", "Expresión inválida"},
		{")", "Expresión inválida"},
		{"2+", "Expresión inválida"},
		{"abc", "Función desconocida: abc"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			_, err := parse(tt.input)
			if err == nil {
				t.Error("se esperaba error")
			} else if tt.wantErr != "" && !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("error %q no contiene %q", err.Error(), tt.wantErr)
			}
		})
	}
}

// TestConstants verifica las constantes pi, e, tau, phi.
func TestConstants(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"pi", "3.141592654"},
		{"e", "2.718281828"},
		{"tau", "6.283185307"},
		{"phi", "1.618033989"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			v, err := parse(tt.input)
			if err != nil {
				t.Fatalf("parse error: %v", err)
			}
			text, _ := v.format()
			if text != tt.want {
				t.Errorf("got %q, want %q", text, tt.want)
			}
		})
	}
}

// TestFunctions verifica algunas funciones: sin, sqrt, ln.
func TestFunctions(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"sin 0", "0"},
		{"sqrt 4", "2"},
		{"ln e", "1"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			v, err := parse(tt.input)
			if err != nil {
				t.Fatalf("parse error: %v", err)
			}
			text, _ := v.format()
			if text != tt.want {
				t.Errorf("got %q, want %q", text, tt.want)
			}
		})
	}
}

// TestExactVsInexact verifica si exact/inexact está bien.
func TestExactVsInexact(t *testing.T) {
	tests := []struct {
		input string
		exact bool
		frac  bool
	}{
		{"1/3", true, true},
		{"2", true, false},
		{"sqrt 2", false, false},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			v, err := parse(tt.input)
			if err != nil {
				t.Fatalf("parse error: %v", err)
			}
			_, exact := v.format()
			if exact != tt.exact {
				t.Errorf("exact mismatch: got %v want %v", exact, tt.exact)
			}
			if tt.frac {
				if v.rat == nil {
					t.Error("esperaba rat para fracción no entera")
				}
			} else {
				if v.rat != nil && !v.rat.IsInt() {
					t.Error("esperaba float para valor no fracción")
				}
			}
		})
	}
}

// TestFuzzParse asegura que parse nunca entre en pánico.
func TestFuzzParse(t *testing.T) {
	inputs := []string{"0", "-1", "+2", "1+2", "3*4", "5/2", "6%", "7!", "8^2", "9pi", "10{11}", "12(13)", "\\frac{14}{15}", "sin 0", "cos pi", "sqrt 16", "ln e", "1/0"}
	for _, in := range inputs {
		func() {
			defer func() {
				if r := recover(); r != nil {
					t.Errorf("parse pánico en input %q: %v", in, r)
				}
			}()
			v, err := parse(in)
			if err != nil && v != (Value{}) {
				t.Errorf("error con valor inesperado para %q", in)
			}
		}()
	}
}

// TestNumDenAndApprox verifica numDen y approxOf.
func TestNumDenAndApprox(t *testing.T) {
	tests := []struct {
		input string
		num   string
		den   string
		approx string
	}{
		{"1/3", "1", "3", "0.3333333333"},
		{"2/6", "1", "3", "0.3333333333"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			v, err := parse(tt.input)
			if err != nil {
				t.Fatalf("parse error: %v", err)
			}
			num, den, ok := numDen(v)
			if !ok {
				t.Errorf("numDen debería ser true para %s", tt.input)
			}
			if num != tt.num || den != tt.den {
				t.Errorf("numDen: got %s/%s want %s/%s", num, den, tt.num, tt.den)
			}
			approx := approxOf(v)
			if approx != tt.approx {
				t.Errorf("approx: got %q want %q", approx, tt.approx)
			}
		})
	}
}