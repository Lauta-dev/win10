package keepass

import (
	"crypto/rand"
	"encoding/base32"
	"fmt"
	"math/big"
	"net/url"
	"os"
	"strings"

	gokeepasslib "github.com/tobischo/gokeepasslib/v3"
	w "github.com/tobischo/gokeepasslib/v3/wrappers"
)

// Escritura de la base (alta de entradas y TOTP). Labura sobre la base
// cacheada del daemon (ver getDB) y guarda atómica (temporal + rename)
// para no corromper ante un corte; el caller refresca el cache con
// syncCache.

const pwCharset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*-_=+?"

// genPassword genera una contraseña aleatoria (crypto/rand) de n
// caracteres. Sin sesgo de módulo.
func genPassword(n int) (string, error) {
	if n <= 0 {
		n = 20
	}
	out := make([]byte, n)
	max := big.NewInt(int64(len(pwCharset)))
	for i := range out {
		r, err := rand.Int(rand.Reader, max)
		if err != nil {
			return "", fmt.Errorf("no se pudo generar: %v", err)
		}
		out[i] = pwCharset[r.Int64()]
	}
	return string(out), nil
}

// genTotpSecret genera un secreto TOTP (20 bytes aleatorios en base32
// sin padding, formato que KeePassXC acepta en el campo otp).
func genTotpSecret() (string, error) {
	raw := make([]byte, 20)
	if _, err := rand.Read(raw); err != nil {
		return "", fmt.Errorf("no se pudo generar: %v", err)
	}
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(raw), nil
}

// saveDB cifra y guarda la base en forma atómica. Deja la base
// utilizable en memoria (la vuelve a descifrar) para quien la siga
// usando en el mismo pedido.
func saveDB(db *gokeepasslib.Database, dbPath string) error {
	if err := db.LockProtectedEntries(); err != nil {
		return fmt.Errorf("no se pudo cifrar: %v", err)
	}
	tmp := dbPath + ".tmp"
	f, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		_ = db.UnlockProtectedEntries()
		return fmt.Errorf("no se pudo guardar: %v", err)
	}
	encErr := gokeepasslib.NewEncoder(f).Encode(db)
	closeErr := f.Close()
	if encErr != nil || closeErr != nil {
		os.Remove(tmp)
		_ = db.UnlockProtectedEntries()
		if encErr != nil {
			return fmt.Errorf("no se pudo guardar: %v", encErr)
		}
		return fmt.Errorf("no se pudo guardar: %v", closeErr)
	}
	if err := os.Rename(tmp, dbPath); err != nil {
		os.Remove(tmp)
		_ = db.UnlockProtectedEntries()
		return fmt.Errorf("no se pudo guardar: %v", err)
	}
	if err := db.UnlockProtectedEntries(); err != nil {
		return fmt.Errorf("no se pudo descifrar: %v", err)
	}
	return nil
}

// setEntryValue escribe (o agrega) un campo de la entrada. protected
// en true lo marca cifrado, como Password.
func setEntryValue(e *gokeepasslib.Entry, key, value string, protected bool) {
	for i := range e.Values {
		if e.Values[i].Key == key {
			e.Values[i].Value.Content = value
			if protected {
				e.Values[i].Value.Protected = w.NewBoolWrapper(true)
			}
			return
		}
	}
	vd := gokeepasslib.ValueData{Key: key, Value: gokeepasslib.V{Content: value}}
	if protected {
		vd.Value.Protected = w.NewBoolWrapper(true)
	}
	e.Values = append(e.Values, vd)
}

// addEntry crea una entrada con título, usuario, contraseña y URL en el
// grupo raíz. Los vacíos quedan vacíos; si password viene vacío genera
// una aleatoria (20 caracteres). Devuelve la contraseña final y si fue
// generada. Valida título y duplicados por ruta exacta, igual que
// findEntry.
func addEntry(db *gokeepasslib.Database, dbPath, title, username, password, urlStr string) (finalPw string, generated bool, err error) {
	if title == "" {
		return "", false, fmt.Errorf("título vacío")
	}
	if strings.Contains(title, "/") {
		return "", false, fmt.Errorf("el título no puede contener /")
	}
	if db.Content == nil || db.Content.Root == nil || len(db.Content.Root.Groups) == 0 {
		return "", false, fmt.Errorf("base sin grupo raíz")
	}
	if findEntry(db, title) != nil {
		return "", false, fmt.Errorf("ya existe una entrada con ese título")
	}
	if password == "" {
		password, err = genPassword(20)
		if err != nil {
			return "", false, err
		}
		generated = true
	}
	e := gokeepasslib.NewEntry()
	setEntryValue(&e, "Title", title, false)
	setEntryValue(&e, "UserName", username, false)
	setEntryValue(&e, "Password", password, true)
	setEntryValue(&e, "URL", urlStr, false)
	setEntryValue(&e, "Notes", "", false)
	root := &db.Content.Root.Groups[0]
	root.Entries = append(root.Entries, e)
	if err := saveDB(db, dbPath); err != nil {
		return "", false, err
	}
	return password, generated, nil
}

// storeTotpURL guarda el secreto (ya canónico) como URL otpauth en el
// campo otp de la entrada.
func storeTotpURL(db *gokeepasslib.Database, dbPath, path, secret string) error {
	e := findEntry(db, path)
	if e == nil {
		return fmt.Errorf("no existe la entrada")
	}
	otpURL := "otpauth://totp/" + url.PathEscape(e.GetTitle()) +
		"?secret=" + secret + "&period=30&digits=6"
	setEntryValue(e, "otp", otpURL, false)
	return saveDB(db, dbPath)
}

// setTotpSeed genera un secreto nuevo y lo guarda como URL otpauth en
// el campo otp de la entrada. Devuelve el secreto en crudo (para
// copiarlo al portapapeles y registrarlo en el servicio).
func setTotpSeed(db *gokeepasslib.Database, dbPath, path string) (secret string, err error) {
	secret, err = genTotpSecret()
	if err != nil {
		return "", err
	}
	if err := storeTotpURL(db, dbPath, path, secret); err != nil {
		return "", err
	}
	return secret, nil
}

// setTotpSecret guarda un secreto pegado por el usuario (lo normaliza
// y valida igual que al calcular códigos). Devuelve el secreto
// canónico, listo para copiar al portapapeles.
func setTotpSecret(db *gokeepasslib.Database, dbPath, path, secret string) (string, error) {
	norm, err := normalizeTotpSecret(strings.TrimSpace(secret))
	if err != nil {
		return "", err
	}
	if err := storeTotpURL(db, dbPath, path, norm); err != nil {
		return "", err
	}
	return norm, nil
}

// removeEntry elimina la entrada de la ruta exacta y guarda. Error si
// no existe.
func removeEntry(db *gokeepasslib.Database, dbPath, path string) error {
	if db.Content == nil || db.Content.Root == nil {
		return fmt.Errorf("no existe la entrada")
	}
	for i := range db.Content.Root.Groups {
		if removeFromGroup(&db.Content.Root.Groups[i], path, "") {
			return saveDB(db, dbPath)
		}
	}
	return fmt.Errorf("no existe la entrada")
}

// removeFromGroup busca path dentro del grupo (y subgrupos, con prefix
// de ruta) y lo quita.
func removeFromGroup(g *gokeepasslib.Group, path, prefix string) bool {
	for j := range g.Entries {
		title := g.Entries[j].GetTitle()
		if title == "" {
			title = "(sin título)"
		}
		p := title
		if prefix != "" {
			p = prefix + "/" + title
		}
		if p == path {
			g.Entries = append(g.Entries[:j], g.Entries[j+1:]...)
			return true
		}
	}
	for i := range g.Groups {
		sub := &g.Groups[i]
		subPrefix := sub.Name
		if prefix != "" {
			subPrefix = prefix + "/" + sub.Name
		}
		if removeFromGroup(sub, path, subPrefix) {
			return true
		}
	}
	return false
}

// groupPrefixOf devuelve el prefijo de ruta del grupo que contiene a
// la entrada ("" en la raíz), con la misma convención que
// collectEntries: el grupo raíz no aparece en las rutas.
func groupPrefixOf(db *gokeepasslib.Database, target *gokeepasslib.Entry) string {
	prefix := ""
	if db.Content == nil || db.Content.Root == nil {
		return prefix
	}
	var walk func(groups []gokeepasslib.Group, p string) bool
	walk = func(groups []gokeepasslib.Group, p string) bool {
		for i := range groups {
			g := &groups[i]
			for j := range g.Entries {
				if &g.Entries[j] == target {
					prefix = p
					return true
				}
			}
			for k := range g.Groups {
				sub := g.Groups[k].Name
				if p != "" {
					sub = p + "/" + g.Groups[k].Name
				}
				if walk(g.Groups[k:k+1], sub) {
					return true
				}
			}
		}
		return false
	}
	walk(db.Content.Root.Groups, "")
	return prefix
}

// editEntry actualiza título, usuario y URL (vacíos quedan vacíos). La
// contraseña solo se toca si viene no vacía o se pide generar: vacía
// sin gen = mantener la actual. Devuelve la contraseña cuando cambió
// (manual o generada), la ruta nueva y si hubo cambio de clave.
func editEntry(db *gokeepasslib.Database, dbPath, path, title, username, password, urlStr string, gen bool) (finalPw string, pwChanged bool, newPath string, err error) {
	if title == "" {
		return "", false, "", fmt.Errorf("título vacío")
	}
	if strings.Contains(title, "/") {
		return "", false, "", fmt.Errorf("el título no puede contener /")
	}
	e := findEntry(db, path)
	if e == nil {
		return "", false, "", fmt.Errorf("no existe la entrada")
	}
	prefix := groupPrefixOf(db, e)
	newPath = title
	if prefix != "" {
		newPath = prefix + "/" + title
	}
	if other := findEntry(db, newPath); other != nil && other != e {
		return "", false, "", fmt.Errorf("ya existe una entrada con ese título")
	}
	setEntryValue(e, "Title", title, false)
	setEntryValue(e, "UserName", username, false)
	setEntryValue(e, "URL", urlStr, false)
	if gen {
		password, err = genPassword(20)
		if err != nil {
			return "", false, "", err
		}
		pwChanged = true
	} else if password != "" {
		pwChanged = true
	}
	if pwChanged {
		setEntryValue(e, "Password", password, true)
		finalPw = password
	}
	if err := saveDB(db, dbPath); err != nil {
		return "", false, "", err
	}
	return finalPw, pwChanged, newPath, nil
}
