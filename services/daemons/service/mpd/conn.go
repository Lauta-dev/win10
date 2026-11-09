package mpd

import (
	"bufio"
	"fmt"
	"net"
	"strings"
	"sync"
	"time"
)

// Conn es una conexión al servidor MPD (protocolo de texto, una
// respuesta por comando). Cada comando se ejecuta entero bajo lock,
// así la misma conexión sirve desde un solo hilo de uso.
type Conn struct {
	mu   sync.Mutex
	conn net.Conn
	rd   *bufio.Reader
}

// Dial abre la conexión y valida el saludo inicial del servidor.
func Dial(network, addr string, timeout time.Duration) (*Conn, error) {
	nc, err := net.DialTimeout(network, addr, timeout)
	if err != nil {
		return nil, err
	}
	c := &Conn{conn: nc, rd: bufio.NewReader(nc)}
	line, err := c.readLine(timeout)
	if err != nil {
		nc.Close()
		return nil, err
	}
	if !strings.HasPrefix(line, "OK MPD ") {
		nc.Close()
		return nil, fmt.Errorf("saludo inesperado del servidor: %q", line)
	}
	return c, nil
}

// Close cierra la conexión. Se puede llamar más de una vez.
func (c *Conn) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.conn != nil {
		c.conn.Close()
		c.conn = nil
	}
}

func (c *Conn) readLine(timeout time.Duration) (string, error) {
	if timeout > 0 {
		c.conn.SetReadDeadline(time.Now().Add(timeout))
	}
	line, err := c.rd.ReadString('\n')
	if err != nil {
		return "", err
	}
	return strings.TrimRight(line, "\r\n"), nil
}

// Exec envía un comando y junta sus líneas hasta el OK final.
// Acepta varias líneas (se ejecutan en orden). Si el servidor rechaza
// el comando devuelve el ACK como error.
func (c *Conn) Exec(cmd string, timeout time.Duration) (lines []string, ack string, err error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.conn == nil {
		return nil, "", fmt.Errorf("conexión cerrada")
	}
	if timeout > 0 {
		c.conn.SetWriteDeadline(time.Now().Add(timeout))
	}
	if !strings.HasSuffix(cmd, "\n") {
		cmd += "\n"
	}
	if _, err := c.conn.Write([]byte(cmd)); err != nil {
		return nil, "", err
	}
	for {
		line, err := c.readLine(timeout)
		if err != nil {
			return nil, "", err
		}
		switch {
		case line == "list_OK":
			continue
		case line == "OK":
			return lines, "", nil
		case strings.HasPrefix(line, "ACK "):
			return lines, line, fmt.Errorf("%s", line)
		case strings.HasPrefix(line, "OK MPD "):
			continue
		default:
			lines = append(lines, line)
		}
	}
}

// WaitChange se suscribe a cambios y bloquea hasta que el servidor avisa
// cuáles hubo. Es para una conexión dedicada: no mezclar con Exec.
func (c *Conn) WaitChange(subs string) ([]string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.conn == nil {
		return nil, fmt.Errorf("conexión cerrada")
	}
	if _, err := c.conn.Write([]byte("idle " + subs + "\n")); err != nil {
		return nil, err
	}
	var changed []string
	for {
		// Sin deadline: la espera es el trabajo.
		line, err := c.readLine(0)
		if err != nil {
			return nil, err
		}
		if line == "OK" {
			return changed, nil
		}
		if strings.HasPrefix(line, "ACK ") {
			return changed, fmt.Errorf("%s", line)
		}
		if strings.HasPrefix(line, "changed:") {
			changed = append(changed, strings.TrimSpace(strings.TrimPrefix(line, "changed:")))
		}
	}
}

// Quote escapa un valor para usarlo como argumento en el protocolo.
func Quote(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `"`, `\"`)
	return `"` + s + `"`
}
