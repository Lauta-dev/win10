package mpd

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"
)

const (
	// Tiempos de red: todo va por socket local, sobran.
	dialTimeout = 5 * time.Second
	cmdTimeout  = 10 * time.Second
	// A partir de acá un comando avisa por stderr (diagnóstico).
	slowAfter = 300 * time.Millisecond
)

// socketAddr resuelve a dónde conectarse: TCP si hay host, si no el
// socket unix de MPD del usuario actual.
func socketAddr(sockPath, host string, port int) (network, addr string) {
	if host != "" {
		return "tcp", fmt.Sprintf("%s:%d", host, port)
	}
	if sockPath == "" {
		rt := os.Getenv("XDG_RUNTIME_DIR")
		if rt == "" {
			rt = fmt.Sprintf("/run/user/%d", os.Getuid())
		}
		sockPath = rt + "/mpd/socket"
	}
	return "unix", sockPath
}

func run(sockPath, host string, port int, musicDir string) int {
	network, addr := socketAddr(sockPath, host, port)
	d := NewDaemon(network, addr, musicDir)
	d.emit(Event{Type: "ready"})
	go d.idleLoop()
	// El burst inicial va en segundo plano para no frenar los pedidos.
	go d.burst()

	// Los pedidos se atienden de a uno en el orden que llegan: como
	// ningún comando es lento, así se preserva el orden sin locks extra.
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
		t0 := time.Now()
		d.handle(req)
		if dt := time.Since(t0); dt > slowAfter {
			fmt.Fprintf(os.Stderr, "mpd: comando lento %s (%.1fs)\n", req.Cmd, dt.Seconds())
		}
	}
	return 0
}

// Main es el entry del servicio dentro del binario unificado daemons:
// recibe los args posteriores a `daemons mpd` y devuelve exit code.
func Main(args []string) int {
	if len(args) >= 1 && args[0] == "version" {
		fmt.Println("mpd-daemon 2.0.0")
		return 0
	}
	// El subcomando va primero: flag deja de parsear ante el primer
	// posicional, así que se extrae "run" antes de Parse.
	rest := args
	if len(rest) > 0 && rest[0] == "run" {
		rest = rest[1:]
	} else if len(rest) > 0 && !strings.HasPrefix(rest[0], "-") {
		fmt.Fprintln(os.Stderr, "uso: daemons mpd [run] [--socket PATH] [--host H --port P]")
		return 2
	}
	fs := flag.NewFlagSet("run", flag.ContinueOnError)
	sockPath := fs.String("socket", "", "socket unix de MPD (defecto: $XDG_RUNTIME_DIR/mpd/socket)")
	host := fs.String("host", "", "host TCP de MPD (alternativa al socket)")
	port := fs.Int("port", 6600, "puerto TCP de MPD")
	music := fs.String("music", "", "music_directory (defecto: se descubre de mpd.conf)")
	if err := fs.Parse(rest); err != nil {
		return 2
	}
	if fs.NArg() > 0 {
		fmt.Fprintln(os.Stderr, "uso: daemons mpd [run] [--socket PATH] [--host H --port P]")
		return 2
	}
	return run(*sockPath, *host, *port, *music)
}
