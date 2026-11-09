// Package run ejecuta procesos externos y reporta su salida.
package run

import (
	"bytes"
	"fmt"
	"os/exec"
)

// Out ejecuta name con args y devuelve su stdout. El stderr va al del padre.
func Out(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("%s: %w", name, err)
	}
	return stdout.String(), nil
}

// Fire ejecuta name y descarta su salida. Los errores se propagan con contexto.
func Fire(name string, args ...string) error {
	if err := exec.Command(name, args...).Run(); err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	return nil
}

// Exists dice si name esta en el PATH.
func Exists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}
