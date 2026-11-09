package bright

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"
)

const slowAfter = 300 * time.Millisecond

func run(device string) int {
	bl, err := discoverBacklight(device)
	if err != nil {
		// Sin backlight (desktop sin panel): avisar y salir con código 2
		// para que QML lo detecte y deshabilite el slider en vez de
		// reintentar en loop.
		fmt.Fprintln(os.Stderr, "bright-daemon:", err)
		return 2
	}
	d := NewDaemon(bl)
	d.emit(Event{Type: "ready", OK: true, Value: d.current(), Min: 0, Max: 100})
	go d.watchLoop()

	// Los pedidos se atienden de a uno en el orden que llegan.
	sc := bufio.NewScanner(os.Stdin)
	sc.Buffer(make([]byte, 64*1024), 64*1024)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var req Request
		if err := json.Unmarshal([]byte(line), &req); err != nil {
			d.emit(Event{Type: "error", Error: "json inválido: " + err.Error()})
			continue
		}
		if req.Args == nil {
			req.Args = map[string]any{}
		}
		t0 := time.Now()
		d.handle(req)
		if dt := time.Since(t0); dt > slowAfter {
			fmt.Fprintf(os.Stderr, "bright-daemon: comando lento %s (%.1fs)\n", req.Cmd, dt.Seconds())
		}
	}
	return 0
}

// Main es el entry del servicio dentro del binario unificado daemons:
// recibe los args posteriores a `daemons bright` y devuelve exit code.
func Main(args []string) int {
	if len(args) >= 1 && args[0] == "version" {
		fmt.Println("bright-daemon 1.0.0")
		return 0
	}
	rest := args
	if len(rest) > 0 && rest[0] == "run" {
		rest = rest[1:]
	} else if len(rest) > 0 && !strings.HasPrefix(rest[0], "-") {
		fmt.Fprintln(os.Stderr, "uso: daemons bright [run] [--device NAME]")
		return 2
	}
	fs := flag.NewFlagSet("run", flag.ContinueOnError)
	device := fs.String("device", "", "dispositivo backlight (defecto: el de mayor max_brightness)")
	if err := fs.Parse(rest); err != nil {
		return 2
	}
	if fs.NArg() > 0 {
		fmt.Fprintln(os.Stderr, "uso: daemons bright [run] [--device NAME]")
		return 2
	}
	return run(*device)
}
