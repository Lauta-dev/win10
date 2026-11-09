package bright

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"
)

// Poll del watcher: sysfs no emite inotify confiable, así que se compara
// el valor cada 500ms. Sin forks (lectura directa), costo despreciable.
const watchInterval = 500 * time.Millisecond

// Daemon atiende pedidos JSON y empuja cambios externos del brillo
// (teclas Fn, brightnessctl manual, etc.) sin que se le pregunte.
type Daemon struct {
	bl *Backlight

	enc   *json.Encoder
	outMu sync.Mutex

	last int
	mu   sync.Mutex
}

func NewDaemon(bl *Backlight) *Daemon {
	d := &Daemon{bl: bl, enc: json.NewEncoder(os.Stdout)}
	d.enc.SetEscapeHTML(false)
	if v, err := bl.percent(); err == nil {
		d.last = v
	}
	return d
}

// emit escribe un evento por stdout (serializado).
func (d *Daemon) emit(ev Event) {
	d.outMu.Lock()
	defer d.outMu.Unlock()
	_ = d.enc.Encode(ev)
}

// current lee el porcentaje actual; en error devuelve el último conocido.
func (d *Daemon) current() int {
	if v, err := d.bl.percent(); err == nil {
		return v
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.last
}

func (d *Daemon) setLast(v int) {
	d.mu.Lock()
	d.last = v
	d.mu.Unlock()
}

// watchLoop avisa con push {"type":"bright"} (sin id) cuando el valor
// cambia por fuera (teclas Fn u otro proceso).
func (d *Daemon) watchLoop() {
	t := time.NewTicker(watchInterval)
	defer t.Stop()
	for range t.C {
		v, err := d.bl.percent()
		if err != nil {
			continue
		}
		d.mu.Lock()
		changed := v != d.last
		if changed {
			d.last = v
		}
		d.mu.Unlock()
		if changed {
			d.emit(Event{Type: "bright", OK: true, Value: v})
		}
	}
}

// handle atiende un pedido. Corre de a uno en orden (ver main.go).
func (d *Daemon) handle(req Request) {
	ok := func() {
		d.emit(Event{Type: "ack", ID: req.ID, OK: true})
	}
	fail := func(typ string, err error) {
		d.emit(Event{Type: typ, ID: req.ID, OK: false, Error: err.Error()})
		d.emit(Event{Type: "ack", ID: req.ID, OK: false})
	}

	switch req.Cmd {
	case "ping":
		ok()

	case "get":
		v := d.current()
		d.emit(Event{Type: "bright", ID: req.ID, OK: true, Value: v, Min: 0, Max: 100})
		ok()

	case "set":
		v := clampPct(intArg(req.Args, "value", d.current()))
		if err := d.bl.set(v); err != nil {
			fail("bright", err)
			return
		}
		// Confirmar con lectura real (brightnessctl redondea por pasos).
		actual := d.current()
		d.setLast(actual)
		d.emit(Event{Type: "bright", ID: req.ID, OK: true, Value: actual, Min: 0, Max: 100})
		ok()

	case "inc", "dec":
		step := intArg(req.Args, "step", 5)
		if step <= 0 {
			step = 5
		}
		if req.Cmd == "dec" {
			step = -step
		}
		v := clampPct(d.current() + step)
		if err := d.bl.set(v); err != nil {
			fail("bright", err)
			return
		}
		actual := d.current()
		d.setLast(actual)
		d.emit(Event{Type: "bright", ID: req.ID, OK: true, Value: actual, Min: 0, Max: 100})
		ok()

	default:
		fail(req.Cmd, fmt.Errorf("comando desconocido: %s", req.Cmd))
	}
}
