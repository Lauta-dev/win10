// Tokenizer de expresiones aritméticas.
// Soporta agrupación con (), {} y [] (intercambiables, pero el cierre
// debe matchear la apertura: "{...]" es error).
package main

import (
	"fmt"
	"strings"
)

type tokKind int

const (
	tEOF tokKind = iota
	tNum
	tIdent
	tCmd // comando LaTeX: \frac (text = nombre sin backslash)
	tPlus
	tMinus
	tStar
	tSlash
	tPercent
	tCaret
	tBang
	tComma
	tOpen
	tClose
)

type token struct {
	kind  tokKind
	text  string // literal (número o identificador)
	open  rune   // para tOpen: '(' '{' '['
	close rune   // para tClose: ')' '}' ']'
}

func matchingClose(open rune) rune {
	switch open {
	case '(':
		return ')'
	case '{':
		return '}'
	case '[':
		return ']'
	}
	return 0
}

// normalize reemplaza símbolos Unicode comunes por sus ASCII.
func normalize(s string) string {
	r := strings.NewReplacer(
		"×", "*",
		"÷", "/",
		"−", "-", "–", "-", "—", "-",
		"π", "pi",
	)
	return r.Replace(s)
}

func lex(input string) ([]token, error) {
	s := normalize(input)
	var toks []token
	i := 0
	for i < len(s) {
		c := s[i]
		switch {
		case c == ' ' || c == '\t' || c == '\n':
			i++
		case c >= '0' && c <= '9' || c == '.':
			j, dots := i, 0
			for j < len(s) && (s[j] >= '0' && s[j] <= '9' || s[j] == '.') {
				if s[j] == '.' {
					dots++
				}
				j++
			}
			if dots > 1 {
				return nil, fmt.Errorf("Número inválido")
			}
			lit := s[i:j]
			if lit == "." {
				return nil, fmt.Errorf("Número inválido")
			}
			toks = append(toks, token{kind: tNum, text: lit})
			i = j
		case c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c == '_':
			j := i
			for j < len(s) && (s[j] >= 'a' && s[j] <= 'z' || s[j] >= 'A' && s[j] <= 'Z' || s[j] >= '0' && s[j] <= '9' || s[j] == '_') {
				j++
			}
			toks = append(toks, token{kind: tIdent, text: strings.ToLower(s[i:j])})
			i = j
		case c == '*' && i+1 < len(s) && s[i+1] == '*':
			toks = append(toks, token{kind: tCaret})
			i += 2
		case c == '\\':
			j := i + 1
			for j < len(s) && (s[j] >= 'a' && s[j] <= 'z' || s[j] >= 'A' && s[j] <= 'Z') {
				j++
			}
			if j == i+1 {
				return nil, fmt.Errorf("Comando inválido: \\")
			}
			toks = append(toks, token{kind: tCmd, text: strings.ToLower(s[i+1 : j])})
			i = j
		default:
			var t token
			switch c {
			case '+':
				t = token{kind: tPlus}
			case '-':
				t = token{kind: tMinus}
			case '*':
				t = token{kind: tStar}
			case '/':
				t = token{kind: tSlash}
			case '%':
				t = token{kind: tPercent}
			case '^':
				t = token{kind: tCaret}
			case '!':
				t = token{kind: tBang}
			case ',':
				t = token{kind: tComma}
			case '(', '{', '[':
				t = token{kind: tOpen, open: rune(c)}
			case ')', '}', ']':
				t = token{kind: tClose, close: rune(c)}
			default:
				return nil, fmt.Errorf("Carácter inválido: %c", c)
			}
			toks = append(toks, t)
			i++
		}
	}
	return append(toks, token{kind: tEOF}), nil
}
