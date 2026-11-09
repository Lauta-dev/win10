// Command qsipc llama a un IpcHandler de la shell sin spawnear `qs`.
//
// Habla el protocolo IPC de quickshell directo sobre el unix socket de la
// instancia ($XDG_RUNTIME_DIR/quickshell/by-pid/<pid>/ipc.sock): evita el
// bootstrap Qt (~40ms) que paga `qs -p … ipc call` en cada keypress.
// Si el socket falla, cae a `qs -p <config> ipc call …`.
//
// Uso: qsipc [--config DIR] [--pid PID] [--socket PATH] [--no-fallback]
//            <target> <function> [args...]
package main

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"unicode/utf16"
)

// Protocolo espejado de quickshell src/io/ipccomm.cpp: mantener en sync
// con la versión de quickshell instalada (`qs --version`).
const (
	commandStringCall = 3

	responseNotReady         = 1
	responseTargetNotFound   = 2
	responseFunctionNotFound = 3
	responseArgumentMismatch = 4
	responseCompleted        = 5
	maxStringLength          = 1 << 20
)

var (
	ErrNotReady            = errors.New("quickshell IPC not ready")
	ErrTargetNotFound      = errors.New("quickshell IPC target not found")
	ErrFunctionNotFound    = errors.New("quickshell IPC function not found")
	ErrArgumentMismatch    = errors.New("quickshell IPC argument mismatch")
	ErrUnsupportedResponse = errors.New("unsupported Quickshell IPC response")
	ErrNoInstance          = errors.New("no live quickshell instance found")
)

// call invoca target/function sobre un socket ya localizado.
func call(socketPath, target, function string, args []string) (string, bool, error) {
	conn, err := net.DialTimeout("unix", socketPath, 2*time.Second)
	if err != nil {
		return "", false, fmt.Errorf("connect: %w", err)
	}
	defer conn.Close()

	_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
	if err := writeCall(conn, target, function, args); err != nil {
		return "", false, fmt.Errorf("write: %w", err)
	}
	return readResponse(bufio.NewReader(conn))
}

func writeCall(w io.Writer, target, function string, args []string) error {
	var buf bytes.Buffer
	if err := buf.WriteByte(commandStringCall); err != nil {
		return err
	}
	if err := writeQString(&buf, target); err != nil {
		return err
	}
	if err := writeQString(&buf, function); err != nil {
		return err
	}
	if err := binary.Write(&buf, binary.BigEndian, uint32(len(args))); err != nil {
		return err
	}
	for _, arg := range args {
		if err := writeQString(&buf, arg); err != nil {
			return err
		}
	}
	_, err := w.Write(buf.Bytes())
	return err
}

func readResponse(r io.Reader) (string, bool, error) {
	var index uint8
	if err := binary.Read(r, binary.BigEndian, &index); err != nil {
		return "", false, fmt.Errorf("read response: %w", err)
	}
	switch index {
	case responseNotReady:
		return "", false, ErrNotReady
	case responseTargetNotFound:
		return "", false, ErrTargetNotFound
	case responseFunctionNotFound:
		return "", false, ErrFunctionNotFound
	case responseArgumentMismatch:
		return "", false, ErrArgumentMismatch
	case responseCompleted:
		break
	default:
		return "", false, fmt.Errorf("%w: variant index %d", ErrUnsupportedResponse, index)
	}

	var isVoid uint8
	if err := binary.Read(r, binary.BigEndian, &isVoid); err != nil {
		return "", false, fmt.Errorf("read completion: %w", err)
	}
	value, err := readQString(r)
	if err != nil {
		return "", false, fmt.Errorf("read result: %w", err)
	}
	return value, isVoid != 0, nil
}

func writeQString(w io.Writer, value string) error {
	encoded := utf16.Encode([]rune(value))
	byteLength := len(encoded) * 2
	if byteLength > maxStringLength {
		return fmt.Errorf("QString too large: %d bytes", byteLength)
	}
	if err := binary.Write(w, binary.BigEndian, uint32(byteLength)); err != nil {
		return err
	}
	for _, codeUnit := range encoded {
		if err := binary.Write(w, binary.BigEndian, codeUnit); err != nil {
			return err
		}
	}
	return nil
}

func readQString(r io.Reader) (string, error) {
	var length uint32
	if err := binary.Read(r, binary.BigEndian, &length); err != nil {
		return "", err
	}
	if length == ^uint32(0) {
		return "", nil
	}
	if length > maxStringLength || length%2 != 0 {
		return "", fmt.Errorf("invalid QString length: %d bytes", length)
	}
	codeUnits := make([]uint16, length/2)
	for i := range codeUnits {
		if err := binary.Read(r, binary.BigEndian, &codeUnits[i]); err != nil {
			return "", err
		}
	}
	return string(utf16.Decode(codeUnits)), nil
}

// runtimeDir replica XDG_RUNTIME_DIR con los mismos fallbacks de quickshell.
func runtimeDir() string {
	if runtime := os.Getenv("XDG_RUNTIME_DIR"); runtime != "" {
		return runtime
	}
	return filepath.Join("/run/user", strconv.Itoa(os.Getuid()))
}

// alive confirma que el pid sigue corriendo (entradas viejas en by-pid
// quedan colgadas cuando la shell muere).
func alive(pid int) bool {
	data, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "cmdline"))
	if err != nil || len(data) == 0 {
		return false
	}
	return true
}

// findSocket localiza el ipc.sock de nuestra shell: filtra instancias vivas
// cuya línea de comando contenga configDir (el `qs -p <dir>` del login).
// Con una sola instancia viva la usa directo.
func findSocket(configDir string) (string, error) {
	base := filepath.Join(runtimeDir(), "quickshell", "by-pid")
	entries, err := os.ReadDir(base)
	if err != nil {
		return "", err
	}
	type candidate struct {
		pid  int
		sock string
		cmd  string
	}
	var live []candidate
	for _, entry := range entries {
		pid, err := strconv.Atoi(entry.Name())
		if err != nil {
			continue
		}
		if !alive(pid) {
			continue
		}
		sock := filepath.Join(base, entry.Name(), "ipc.sock")
		if st, err := os.Stat(sock); err != nil || st.IsDir() {
			continue
		}
		cmd, _ := os.ReadFile(filepath.Join("/proc", entry.Name(), "cmdline"))
		live = append(live, candidate{pid, sock, string(cmd)})
	}
	if len(live) == 0 {
		return "", ErrNoInstance
	}
	if len(live) == 1 {
		return live[0].sock, nil
	}
	for _, c := range live {
		if configDir != "" && strings.Contains(c.cmd, configDir) {
			return c.sock, nil
		}
	}
	return "", fmt.Errorf("%d instances, none matches %q", len(live), configDir)
}

// fallbackQs re-ejecuta vía `qs -p` heredando stdio; devuelve su exit code.
func fallbackQs(configDir string, args []string) int {
	qs, err := exec.LookPath("qs")
	if err != nil {
		fmt.Fprintln(os.Stderr, "qsipc: no socket and no `qs` in PATH")
		return 1
	}
	cmdArgs := append([]string{"-p", configDir, "ipc", "call"}, args...)
	cmd := exec.Command(qs, cmdArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return exitErr.ExitCode()
		}
		return 1
	}
	return 0
}

func defaultConfigDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".config", "labwc", "b")
}

func main() {
	configDir := flag.String("config", defaultConfigDir(), "config dir to match (`qs -p <dir>`) and for fallback")
	pid := flag.Int("pid", 0, "shell PID (skips discovery)")
	socket := flag.String("socket", "", "ipc.sock path (skips discovery)")
	noFallback := flag.Bool("no-fallback", false, "fail instead of falling back to `qs`")
	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, "Uso: qsipc [--config DIR] [--pid PID] [--socket PATH] [--no-fallback] <target> <function> [args...]")
	}
	flag.Parse()
	args := flag.Args()
	if len(args) < 2 {
		flag.Usage()
		os.Exit(2)
	}

	sock := *socket
	if sock == "" && *pid != 0 {
		sock = filepath.Join(runtimeDir(), "quickshell", "by-pid", strconv.Itoa(*pid), "ipc.sock")
	}
	if sock == "" {
		var err error
		sock, err = findSocket(*configDir)
		if err != nil {
			fmt.Fprintln(os.Stderr, "qsipc:", err)
			if *noFallback {
				os.Exit(1)
			}
			os.Exit(fallbackQs(*configDir, args))
		}
	}

	result, isVoid, err := call(sock, args[0], args[1], args[2:])
	if err != nil {
		fmt.Fprintln(os.Stderr, "qsipc:", err)
		if *noFallback {
			os.Exit(1)
		}
		os.Exit(fallbackQs(*configDir, args))
	}
	if !isVoid {
		fmt.Println(result)
	}
}
