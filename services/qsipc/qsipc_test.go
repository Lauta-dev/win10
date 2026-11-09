// Package main: tests unitarios para qsipc.
// Estos tests están incompletos; se necesitan más para cumplir con los requisitos.
package main

import (
    "bytes"
    "testing"
    _ "unicode/utf16" // importado para readQString; no usado directamente
)

// TestWriteQStringRoundtrip verifica que writeQString and readQString preservan la entrada.
func TestWriteQStringRoundtrip(t *testing.T) {
    tests := []string{"hello", "world", "", "áéíóú", "🐍", "\x00\x01"}
    for _, input := range tests {
        buf := &bytes.Buffer{}
        if err := writeQString(buf, input); err != nil {
            t.Fatalf("writeQString falló para %q: %v", input, err)
        }
        // Extraer bytes escritos para leerString
        data := buf.Bytes()
        reader := bytes.NewReader(data)
        output, err := readQString(reader)
        if err != nil {
            t.Fatalf("readQString falló para %q: %v", input, err)
        }
        if output != input {
            t.Errorf("roundtrip: got %q, want %q", output, input)
        }
    }
}