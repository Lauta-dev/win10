package keepass

import (
	"crypto/hmac"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/base32"
	"fmt"
	"hash"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// normalizeTotpSecret normaliza (mayúsculas, sin espacios ni padding)
// y valida un secreto en crudo por round-trip canónico: un secreto
// malformado falla acá, no genera un código verosímil pero incorrecto.
func normalizeTotpSecret(raw string) (string, error) {
	norm := strings.ToUpper(raw)
	norm = strings.ReplaceAll(norm, " ", "")
	norm = strings.ReplaceAll(norm, "=", "")
	if norm == "" {
		return "", fmt.Errorf("TOTP sin secreto")
	}
	decoded, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(norm)
	if err != nil || len(decoded) == 0 ||
		base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(decoded) != norm {
		return "", fmt.Errorf("TOTP con secreto inválido")
	}
	return norm, nil
}

// totpNow calcula el código TOTP actual desde el campo "otp" de KeePassXC
// (una URL otpauth://). Todo stdlib, sin dependencias.
func totpNow(otpURL string) (string, error) {
	return totpAt(otpURL, time.Now())
}

func totpAt(otpURL string, now time.Time) (string, error) {
	u, err := url.Parse(strings.TrimSpace(otpURL))
	if err != nil || u.Scheme != "otpauth" {
		return "", fmt.Errorf("TOTP inválido")
	}
	q := u.Query()
	norm, err := normalizeTotpSecret(q.Get("secret"))
	if err != nil {
		return "", err
	}
	raw, _ := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(norm)
	digits := atoiOr(q.Get("digits"), 6)
	period := atoiOr(q.Get("period"), 30)
	var newHash func() hash.Hash
	switch strings.ToUpper(q.Get("algorithm")) {
	case "", "SHA1":
		newHash = sha1.New
	case "SHA256":
		newHash = sha256.New
	case "SHA512":
		newHash = sha512.New
	default:
		return "", fmt.Errorf("TOTP con algoritmo no soportado")
	}
	counter := uint64(now.Unix() / int64(period))
	var msg [8]byte
	for i := 7; i >= 0; i-- {
		msg[i] = byte(counter)
		counter >>= 8
	}
	mac := hmac.New(newHash, raw)
	mac.Write(msg[:])
	sum := mac.Sum(nil)
	off := sum[len(sum)-1] & 0x0F
	code := (uint32(sum[off])&0x7F)<<24 | uint32(sum[off+1])<<16 |
		uint32(sum[off+2])<<8 | uint32(sum[off+3])
	mod := uint32(1)
	for i := 0; i < digits; i++ {
		mod *= 10
	}
	out := strconv.FormatUint(uint64(code%mod), 10)
	for len(out) < digits {
		out = "0" + out
	}
	return out, nil
}

func atoiOr(s string, def int) int {
	if n, err := strconv.Atoi(strings.TrimSpace(s)); err == nil && n > 0 {
		return n
	}
	return def
}
