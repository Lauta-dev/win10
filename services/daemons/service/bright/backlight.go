package bright

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// Backlight maneja un dispositivo de /sys/class/backlight.
// La lectura es directa por sysfs (sin forks); la escritura va por
// brightnessctl porque el sysfs suele ser root:root 644 y brightnessctl
// resuelve los permisos (udev/logind).
type Backlight struct {
	device string
	max    int
}

func readIntFile(path string) (int, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(strings.TrimSpace(string(b)))
}

// discoverBacklight elige el dispositivo con mayor max_brightness
// (criterio estable si hay más de uno). Si want no es vacío, lo usa.
func discoverBacklight(want string) (*Backlight, error) {
	if want != "" {
		max, err := readIntFile(filepath.Join("/sys/class/backlight", want, "max_brightness"))
		if err != nil {
			return nil, fmt.Errorf("backlight %q no disponible: %v", want, err)
		}
		return &Backlight{device: want, max: max}, nil
	}
	entries, err := filepath.Glob("/sys/class/backlight/*")
	if err != nil || len(entries) == 0 {
		return nil, fmt.Errorf("sin backlight en /sys/class/backlight")
	}
	best := ""
	bestMax := -1
	for _, e := range entries {
		max, err := readIntFile(filepath.Join(e, "max_brightness"))
		if err != nil {
			continue
		}
		if max > bestMax {
			bestMax = max
			best = filepath.Base(e)
		}
	}
	if best == "" {
		return nil, fmt.Errorf("sin backlight legible")
	}
	return &Backlight{device: best, max: bestMax}, nil
}

func clampPct(v int) int {
	if v < 0 {
		return 0
	}
	if v > 100 {
		return 100
	}
	return v
}

// percent lee actual_brightness (fallback a brightness) y lo pasa a 0-100.
func (b *Backlight) percent() (int, error) {
	raw, err := readIntFile(filepath.Join("/sys/class/backlight", b.device, "actual_brightness"))
	if err != nil {
		raw, err = readIntFile(filepath.Join("/sys/class/backlight", b.device, "brightness"))
		if err != nil {
			return 0, err
		}
	}
	if b.max <= 0 {
		return 0, fmt.Errorf("max_brightness inválido")
	}
	return clampPct((raw*100 + b.max/2) / b.max), nil
}

// set escribe el porcentaje vía brightnessctl (sin shell).
func (b *Backlight) set(pct int) error {
	pct = clampPct(pct)
	cmd := exec.Command("brightnessctl", "-d", b.device, "set", strconv.Itoa(pct)+"%")
	// brightnessctl avisa por stdout; si falla, propagar el stderr.
	var sb strings.Builder
	cmd.Stdout = &sb
	cmd.Stderr = &sb
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("brightnessctl: %v (%s)", err, strings.TrimSpace(sb.String()))
	}
	return nil
}
