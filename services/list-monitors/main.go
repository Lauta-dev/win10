// list-monitors — Lista monitores via wlr-randr --json.
// Uso: list-monitors
// Salida: {"monitors":[...]} en una sola línea.
// Solo stdlib.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"sort"
	"time"
)

type rawMode struct {
	Width     int     `json:"width"`
	Height    int     `json:"height"`
	Refresh   float64 `json:"refresh"`
	Preferred bool    `json:"preferred"`
	Current   bool    `json:"current"`
}

type rawOutput struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Enabled     bool           `json:"enabled"`
	Position    map[string]int `json:"position"`
	Scale       float64        `json:"scale"`
	Transform   string         `json:"transform"`
	Modes       []rawMode      `json:"modes"`
}

type outMode struct {
	Width      int     `json:"width"`
	Height     int     `json:"height"`
	Refresh    float64 `json:"refresh"`
	RefreshMhz float64 `json:"refresh_mhz"`
	Preferred  bool    `json:"preferred"`
	Current    bool    `json:"current"`
}

type outMonitor struct {
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Enabled     bool           `json:"enabled"`
	Position    map[string]int `json:"position"`
	Scale       float64        `json:"scale"`
	Transform   string         `json:"transform"`
	Modes       []outMode      `json:"modes"`
	CurrentMode *outMode       `json:"current_mode"`
}

func round3(v float64) float64 {
	// Equivalente a round(x/1000, 3) de Python manteniendo compatibilidad.
	v = v / 1000.0
	return float64(int(v*1000+0.5)) / 1000.0
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	raw := []byte{}
	cmd := exec.CommandContext(ctx, "wlr-randr", "--json")
	var buf bytes.Buffer
	cmd.Stdout = &buf
	if err := cmd.Run(); err == nil {
		raw = bytes.TrimSpace(buf.Bytes())
	}

	monitors := []outMonitor{}
	if len(raw) > 0 {
		var data []rawOutput
		if err := json.Unmarshal(raw, &data); err == nil {
			for _, out := range data {
				modes := make([]outMode, 0, len(out.Modes))
				for _, m := range out.Modes {
					modes = append(modes, outMode{
						Width:      m.Width,
						Height:     m.Height,
						Refresh:    round3(m.Refresh),
						RefreshMhz: m.Refresh,
						Preferred:  m.Preferred,
						Current:    m.Current,
					})
				}
				sort.Slice(modes, func(a, b int) bool {
						pa, pb := modes[a], modes[b]
						// preferred/current primero, luego resolución desc, refresh desc
						if pa.Preferred != pb.Preferred {
							return pa.Preferred && !pb.Preferred
						}
						if pa.Current != pb.Current {
							return pa.Current && !pb.Current
						}
						ra, rb := pa.Width*pa.Height, pb.Width*pb.Height
						if ra != rb {
							return ra > rb
						}
						return pa.Refresh > pb.Refresh
					})
				pos := out.Position
				if pos == nil {
					pos = map[string]int{"x": 0, "y": 0}
				}
				scale := out.Scale
				if scale == 0 {
					scale = 1.0
				}
				tr := out.Transform
				if tr == "" {
					tr = "normal"
				}
				mon := outMonitor{
					Name:        out.Name,
					Description: out.Description,
					Enabled:     out.Enabled,
					Position:    pos,
					Scale:       scale,
					Transform:   tr,
					Modes:       modes,
				}
				for i := range modes {
					if modes[i].Current {
						c := modes[i]
						mon.CurrentMode = &c
						break
					}
				}
				monitors = append(monitors, mon)
			}
		}
	}
	}
	}
	res := map[string]any{"monitors": monitors}
	enc, _ := json.Marshal(res)
	fmt.Println(string(enc))
}