package keepass

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"
)

func run(dbPath string, idle time.Duration) int {
	if dbPath == "" {
		fmt.Fprintln(os.Stderr, "keepass-daemon: falta --db")
		return 2
	}
	d := NewDaemon(expandHome(dbPath), idle)
	d.emit(Event{Type: "ready", OK: true})

	// Los pedidos se atienden de a uno en el orden que llegan.
	sc := bufio.NewScanner(os.Stdin)
	sc.Buffer(make([]byte, 1024*1024), 16*1024*1024)
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
		d.handle(req)
	}
	return 0
}

func expandHome(p string) string {
	if strings.HasPrefix(p, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			return home + p[1:]
		}
	}
	return p
}

// Main es el entry del servicio dentro del binario unificado daemons:
// recibe los args posteriores a `daemons keepass` y devuelve exit code.
func Main(args []string) int {
	if len(args) >= 1 && args[0] == "version" {
		fmt.Println("keepass-daemon 1.0.0")
		return 0
	}
	fs := flag.NewFlagSet("keepass-daemon", flag.ContinueOnError)
	dbPath := fs.String("db", "", "ruta a la base .kdbx")
	idleStr := fs.String("idle", "15m", "auto-bloqueo tras inactividad (ej: 15m, 90s)")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	idle, err := time.ParseDuration(*idleStr)
	if err != nil || idle <= 0 {
		fmt.Fprintln(os.Stderr, "keepass-daemon: --idle inválido")
		return 2
	}
	return run(*dbPath, idle)
}
