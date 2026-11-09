// Parser por descenso recursivo con evaluación directa.
//
// Gramática:
//
//	expr   := term (("+" | "-") term)*
//	term   := impl (("*" | "/" | "%") impl)*      (% binario: módulo)
//	impl   := power (power)*                       (multiplicación implícita: 2pi, 2(3+1))
//	power  := unary ("^" power)?                   (asociativo a derecha)
//	unary  := ("-" | "+") unary | postfix
//	postfix:= primary ("!" | "%")*                 (! factorial, % postfijo => /100)
//	primary:= número | const | func "(" expr ")" | func unary | "(" "{" "[" expr ")" "}" "]"
package main

import (
	"fmt"
	"math/big"
)

type parser struct {
	toks []token
	pos  int
}

func parse(input string) (Value, error) {
	toks, err := lex(input)
	if err != nil {
		return Value{}, err
	}
	p := &parser{toks: toks}
	v, err := p.expr()
	if err != nil {
		return Value{}, err
	}
	if p.peek().kind != tEOF {
		return Value{}, fmt.Errorf("Expresión incompleta")
	}
	return v, nil
}

func (p *parser) peek() token { return p.toks[p.pos] }
func (p *parser) peekAt(n int) token {
	if p.pos+n < len(p.toks) {
		return p.toks[p.pos+n]
	}
	return token{kind: tEOF}
}
func (p *parser) next() token {
	t := p.toks[p.pos]
	p.pos++
	return t
}

// startsPrimary dice si el token puede iniciar un operando (para la
// multiplicación implícita y para decidir % binario vs postfijo).
func startsPrimary(t token) bool {
	return t.kind == tNum || t.kind == tIdent || t.kind == tOpen || t.kind == tCmd
}

func (p *parser) expr() (Value, error) {
	v, err := p.term()
	if err != nil {
		return Value{}, err
	}
	for {
		t := p.peek()
		if t.kind != tPlus && t.kind != tMinus {
			return v, nil
		}
		p.next()
		r, err := p.term()
		if err != nil {
			return Value{}, err
		}
		if t.kind == tPlus {
			v = v.add(r)
		} else {
			v = v.sub(r)
		}
	}
}

func (p *parser) term() (Value, error) {
	v, err := p.impl()
	if err != nil {
		return Value{}, err
	}
	for {
		t := p.peek()
		if t.kind != tStar && t.kind != tSlash && t.kind != tPercent {
			return v, nil
		}
		// % postfijo (50% / (50%)) lo consume postfix; acá solo % binario.
		if t.kind == tPercent && !startsPrimary(p.peekAt(1)) {
			return v, nil
		}
		p.next()
		r, err := p.impl()
		if err != nil {
			return Value{}, err
		}
		switch t.kind {
		case tStar:
			v = v.mul(r)
		case tSlash:
			v, err = v.div(r)
		case tPercent:
			v, err = v.mod(r)
		}
		if err != nil {
			return Value{}, err
		}
	}
}

func (p *parser) impl() (Value, error) {
	v, err := p.power()
	if err != nil {
		return Value{}, err
	}
	for startsPrimary(p.peek()) {
		r, err := p.power()
		if err != nil {
			return Value{}, err
		}
		v = v.mul(r)
	}
	return v, nil
}

func (p *parser) power() (Value, error) {
	base, err := p.unary()
	if err != nil {
		return Value{}, err
	}
	if p.peek().kind == tCaret {
		p.next()
		exp, err := p.power()
		if err != nil {
			return Value{}, err
		}
		return base.pow(exp)
	}
	return base, nil
}

func (p *parser) unary() (Value, error) {
	t := p.peek()
	if t.kind == tMinus || t.kind == tPlus {
		p.next()
		v, err := p.unary()
		if err != nil {
			return Value{}, err
		}
		if t.kind == tMinus {
			return v.neg(), nil
		}
		return v, nil
	}
	return p.postfix()
}

func (p *parser) postfix() (Value, error) {
	v, err := p.primary()
	if err != nil {
		return Value{}, err
	}
	for {
		t := p.peek()
		switch t.kind {
		case tBang:
			p.next()
			v, err = factorial(v)
			if err != nil {
				return Value{}, err
			}
		case tPercent:
			// Postfijo solo si no hay operando a la derecha.
			if startsPrimary(p.peekAt(1)) {
				return v, nil
			}
			p.next()
			v = v.percent()
		default:
			return v, nil
		}
	}
}

func (p *parser) primary() (Value, error) {
	t := p.next()
	switch t.kind {
	case tNum:
		r, ok := new(big.Rat).SetString(t.text)
		if !ok {
			return Value{}, fmt.Errorf("Número inválido")
		}
		return exactRat(r), nil
	case tOpen:
		v, err := p.expr()
		if err != nil {
			return Value{}, err
		}
		c := p.next()
		if c.kind != tClose || c.close != matchingClose(t.open) {
			return Value{}, fmt.Errorf("Falta cerrar paréntesis")
		}
		return v, nil
	case tIdent:
		name := t.text
		if isConst(name) {
			return inexact(consts[name]), nil
		}
		if isFunc(name) {
			var arg Value
			var err error
			if p.peek().kind == tOpen {
				p.next() // (
				arg, err = p.expr()
				if err != nil {
					return Value{}, err
				}
				c := p.next()
				if c.kind != tClose {
					return Value{}, fmt.Errorf("Falta cerrar paréntesis")
				}
				// Llamadas multi-arg todavía no soportadas.
				if p.peek().kind == tComma {
					return Value{}, fmt.Errorf("Demasiados argumentos")
				}
			} else {
				arg, err = p.unary()
				if err != nil {
					return Value{}, err
				}
			}
			return applyFunc(name, arg)
		}
		return Value{}, fmt.Errorf("Función desconocida: %s", name)
	case tCmd:
		if t.text != "frac" {
			return Value{}, fmt.Errorf("Comando desconocido: \\%s", t.text)
		}
		num, err := p.fracArg()
		if err != nil {
			return Value{}, err
		}
		den, err := p.fracArg()
		if err != nil {
			return Value{}, err
		}
		return num.div(den)
	}
	return Value{}, fmt.Errorf("Expresión inválida")
}

// fracArg parsea un argumento de \frac: grupo "{...}" o valor pelado
// (\frac 2 4, \frac{1+1}{4}).
func (p *parser) fracArg() (Value, error) {
	if p.peek().kind == tOpen {
		open := p.next()
		v, err := p.expr()
		if err != nil {
			return Value{}, err
		}
		c := p.next()
		if c.kind != tClose || c.close != matchingClose(open.open) {
			return Value{}, fmt.Errorf("Falta cerrar paréntesis")
		}
		return v, nil
	}
	return p.unary()
}

func applyFunc(name string, arg Value) (Value, error) {
	if name == "fact" {
		return factorial(arg)
	}
	f, ok := funcs[name]
	if !ok {
		return Value{}, fmt.Errorf("Función desconocida: %s", name)
	}
	r, err := f.fn([]float64{arg.float64()})
	if err != nil {
		return Value{}, err
	}
	return inexact(r), nil
}
