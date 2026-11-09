package keepass

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	gokeepasslib "github.com/tobischo/gokeepasslib/v3"
)

// Daemon atiende pedidos JSON sobre una base KeePassXC abierta con
// gokeepasslib (nativo, sin keepassxc-cli). Guarda la contraseña y la
// base descifrada en memoria: se re-abre solo si el archivo cambió
// desde el último pedido (mtime, vale por Syncthing), así no se paga
// el KDF en cada comando. El proceso muere al lock manual o al
// auto-bloqueo por inactividad y libera todo con él.
type Daemon struct {
	dbPath   string
	idle     time.Duration
	password string

	// Cache de la base descifrada, sincronizada por mtime (getDB/syncCache).
	dbCache    *gokeepasslib.Database
	dbCacheMod time.Time

	enc   *json.Encoder
	outMu sync.Mutex
	timer *time.Timer
}

func NewDaemon(dbPath string, idle time.Duration) *Daemon {
	d := &Daemon{dbPath: dbPath, idle: idle, enc: json.NewEncoder(os.Stdout)}
	d.enc.SetEscapeHTML(false)
	d.armIdle()
	return d
}

// emit escribe un evento. Normaliza nil→[] porque la UI usa .length sin
// chequear null.
func (d *Daemon) emit(ev Event) {
	if ev.Entries == nil {
		ev.Entries = []Entry{}
	}
	d.outMu.Lock()
	defer d.outMu.Unlock()
	_ = d.enc.Encode(ev)
}

// armIdle (re)arma el auto-bloqueo: sin pedidos por el lapso, avisa y
// termina (la memoria se libera con el proceso).
func (d *Daemon) armIdle() {
	if d.timer != nil {
		d.timer.Stop()
	}
	d.timer = time.AfterFunc(d.idle, func() {
		d.emit(Event{Type: "locked", OK: true})
		os.Exit(0)
	})
}

func (d *Daemon) unlocked() bool {
	return d.password != ""
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
		d.armIdle()
		ok()

	case "unlock":
		d.armIdle()
		pw := strArg(req.Args, "password")
		if pw == "" {
			fail("entries", fmt.Errorf("Contraseña vacía"))
			return
		}
		db, err := openDB(d.dbPath, pw)
		if err != nil {
			fail("entries", err)
			return
		}
		d.password = pw
		d.syncCache(db)
		d.emit(Event{Type: "entries", ID: req.ID, OK: true, Entries: collectEntries(db)})
		ok()

	case "list":
		d.armIdle()
		if !d.unlocked() {
			fail("entries", fmt.Errorf("Desbloqueá la base primero"))
			return
		}
		db, err := d.getDB()
		if err != nil {
			fail("entries", err)
			return
		}
		d.emit(Event{Type: "entries", ID: req.ID, OK: true, Entries: collectEntries(db)})
		ok()

	case "copy":
		d.armIdle()
		if !d.unlocked() {
			fail("copy", fmt.Errorf("Desbloqueá la base primero"))
			return
		}
		path := strArg(req.Args, "path")
		attr := strArg(req.Args, "attr")
		isTotp := boolArg(req.Args, "totp")
		if path == "" {
			fail("copy", fmt.Errorf("path vacío"))
			return
		}
		db, err := d.getDB()
		if err != nil {
			fail("copy", err)
			return
		}
		e := findEntry(db, path)
		if e == nil {
			fail("copy", fmt.Errorf("no existe la entrada"))
			return
		}
		label, value, err := entrySecret(e, attr, isTotp)
		if err != nil {
			fail("copy", err)
			return
		}
		if value == "" && !isTotp {
			fail("copy", fmt.Errorf("%s vacío en %s", label, path))
			return
		}
		if err := wlCopy(value); err != nil {
			fail("copy", err)
			return
		}
		d.emit(Event{Type: "copy", ID: req.ID, OK: true, Label: label})
		ok()

	case "add":
		d.armIdle()
		if !d.unlocked() {
			fail("added", fmt.Errorf("Desbloqueá la base primero"))
			return
		}
		title := strings.TrimSpace(strArg(req.Args, "title"))
		pw := strArg(req.Args, "password")
		username := strArg(req.Args, "username")
		urlStr := strArg(req.Args, "url")
		if title == "" {
			fail("added", fmt.Errorf("título vacío"))
			return
		}
		if strings.Contains(title, "/") {
			fail("added", fmt.Errorf("el título no puede contener /"))
			return
		}
		db, err := d.getDB()
		if err != nil {
			fail("added", err)
			return
		}
		finalPw, _, err := addEntry(db, d.dbPath, title, username, pw, urlStr)
		if err != nil {
			fail("added", err)
			return
		}
		d.syncCache(db)
		entries := collectEntries(db)
		// La contraseña (manual o generada) va al portapapeles: la
		// generada no tiene otra forma de conocerse y el secreto
		// nunca vuelve por stdout.
		if err := wlCopy(finalPw); err != nil {
			d.emit(Event{Type: "added", ID: req.ID, OK: false, Error: "Creada, pero no se pudo copiar: " + err.Error(), Entries: entries, Label: title})
			d.emit(Event{Type: "ack", ID: req.ID, OK: false, Entries: []Entry{}})
			return
		}
		d.emit(Event{Type: "added", ID: req.ID, OK: true, Entries: entries, Label: title})
		ok()

	case "totp-new":
		d.armIdle()
		if !d.unlocked() {
			fail("totp", fmt.Errorf("Desbloqueá la base primero"))
			return
		}
		path := strArg(req.Args, "path")
		if path == "" {
			fail("totp", fmt.Errorf("path vacío"))
			return
		}
		db, err := d.getDB()
		if err != nil {
			fail("totp", err)
			return
		}
		secret, err := setTotpSeed(db, d.dbPath, path)
		if err != nil {
			fail("totp", err)
			return
		}
		d.syncCache(db)
		entries := collectEntries(db)
		// El secreto en crudo va al portapapeles para registrarlo
		// en el servicio; a la base solo va la URL otpauth.
		if err := wlCopy(secret); err != nil {
			d.emit(Event{Type: "totp", ID: req.ID, OK: false, Error: "TOTP guardado, pero no se pudo copiar el secreto: " + err.Error(), Entries: entries, Label: path})
			d.emit(Event{Type: "ack", ID: req.ID, OK: false, Entries: []Entry{}})
			return
		}
		d.emit(Event{Type: "totp", ID: req.ID, OK: true, Entries: entries, Label: path})
		ok()

	case "totp-set":
		d.armIdle()
		if !d.unlocked() {
			fail("totp", fmt.Errorf("Desbloqueá la base primero"))
			return
		}
		path := strArg(req.Args, "path")
		secret := strArg(req.Args, "secret")
		if path == "" {
			fail("totp", fmt.Errorf("path vacío"))
			return
		}
		db, err := d.getDB()
		if err != nil {
			fail("totp", err)
			return
		}
		norm, err := setTotpSecret(db, d.dbPath, path, secret)
		if err != nil {
			fail("totp", err)
			return
		}
		d.syncCache(db)
		entries := collectEntries(db)
		// El secreto canónico va al portapapeles para registrarlo
		// en el servicio; a la base solo va la URL otpauth.
		if err := wlCopy(norm); err != nil {
			d.emit(Event{Type: "totp", ID: req.ID, OK: false, Error: "TOTP guardado, pero no se pudo copiar el secreto: " + err.Error(), Entries: entries, Label: path})
			d.emit(Event{Type: "ack", ID: req.ID, OK: false, Entries: []Entry{}})
			return
		}
		d.emit(Event{Type: "totp", ID: req.ID, OK: true, Entries: entries, Label: path})
		ok()

	case "genpass":
		d.armIdle()
		if !d.unlocked() {
			fail("genpass", fmt.Errorf("Desbloqueá la base primero"))
			return
		}
		n := intArg(req.Args, "length")
		if n <= 0 {
			n = 20
		}
		if n > 128 {
			n = 128
		}
		pw, err := genPassword(n)
		if err != nil {
			fail("genpass", err)
			return
		}
		d.emit(Event{Type: "genpass", ID: req.ID, OK: true, Password: pw})
		ok()

	case "del":
		d.armIdle()
		if !d.unlocked() {
			fail("deleted", fmt.Errorf("Desbloqueá la base primero"))
			return
		}
		path := strArg(req.Args, "path")
		if path == "" {
			fail("deleted", fmt.Errorf("path vacío"))
			return
		}
		db, err := d.getDB()
		if err != nil {
			fail("deleted", err)
			return
		}
		if err := removeEntry(db, d.dbPath, path); err != nil {
			fail("deleted", err)
			return
		}
		d.syncCache(db)
		d.emit(Event{Type: "deleted", ID: req.ID, OK: true, Entries: collectEntries(db), Label: path})
		ok()

	case "edit":
		d.armIdle()
		if !d.unlocked() {
			fail("edited", fmt.Errorf("Desbloqueá la base primero"))
			return
		}
		path := strArg(req.Args, "path")
		title := strings.TrimSpace(strArg(req.Args, "title"))
		if path == "" {
			fail("edited", fmt.Errorf("path vacío"))
			return
		}
		db, err := d.getDB()
		if err != nil {
			fail("edited", err)
			return
		}
		finalPw, pwChanged, newPath, err := editEntry(db, d.dbPath, path,
			title, strArg(req.Args, "username"), strArg(req.Args, "password"),
			strArg(req.Args, "url"), boolArg(req.Args, "gen"))
		if err != nil {
			fail("edited", err)
			return
		}
		d.syncCache(db)
		entries := collectEntries(db)
		// Si la clave cambió (manual o generada) va al portapapeles;
		// si se mantuvo no hay nada que copiar.
		if pwChanged {
			if err := wlCopy(finalPw); err != nil {
				d.emit(Event{Type: "edited", ID: req.ID, OK: false, Error: "Guardada, pero no se pudo copiar: " + err.Error(), Entries: entries, Label: newPath})
				d.emit(Event{Type: "ack", ID: req.ID, OK: false, Entries: []Entry{}})
				return
			}
		}
		d.emit(Event{Type: "edited", ID: req.ID, OK: true, Entries: entries, Label: newPath})
		ok()

	default:
		fail(req.Cmd, fmt.Errorf("comando desconocido: %s", req.Cmd))
	}
}

// entrySecret extrae el valor a copiar: Password, UserName (reintenta
// Username, como lo escribe alguna gente) o el TOTP actual.
func entrySecret(e entryLike, attr string, isTotp bool) (label, value string, err error) {
	if isTotp {
		code, err := totpNow(e.GetContent("otp"))
		if err != nil {
			return "TOTP", "", fmt.Errorf("Esta entrada no tiene TOTP")
		}
		return "TOTP", code, nil
	}
	switch attr {
	case "UserName":
		if v := e.GetContent("UserName"); v != "" {
			return "usuario", v, nil
		}
		return "usuario", e.GetContent("Username"), nil
	case "Password":
		return "contraseña", e.GetContent("Password"), nil
	default:
		return "", "", fmt.Errorf("atributo desconocido: %s", attr)
	}
}

// entryLike es lo justo que se usa de una entrada (facilita probar sin
// abrir una base real).
type entryLike interface {
	GetContent(key string) string
}

// wlCopy lleva texto al portapapeles por stdin (nunca en argv, donde lo
// vería `ps`). Única excepción a "sin procesos": Wayland no expone otra
// API para el portapapeles.
//
// Con --foreground no bifurca: un solo proceso que sirve hasta que otro
// copy lo reemplace. Se lo larga en segundo plano y se considera éxito
// si sigue vivo al segundo (o si terminó en 0); si muere con error se
// reporta. Una gorutina lo espera para no dejar zombies.
func wlCopy(value string) error {
	cmd := exec.Command("wl-copy", "--foreground")
	cmd.Stdin = strings.NewReader(value)
	var errBuf bytes.Buffer
	cmd.Stderr = &errBuf
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("no se pudo copiar al portapapeles (%v)", err)
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		if err != nil {
			if msg := strings.TrimSpace(errBuf.String()); msg != "" {
				return fmt.Errorf("no se pudo copiar: %s", msg)
			}
			return fmt.Errorf("no se pudo copiar al portapapeles (%v)", err)
		}
		return nil
	case <-time.After(time.Second):
		return nil
	}
}
