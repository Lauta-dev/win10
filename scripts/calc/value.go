// Valores numéricos duales: racional exacto (big.Rat) o float64.
//
// Las operaciones + - * / % ^ entre racionales se mantienen exactas
// (1/3 sigue siendo 1/3); al tocar una función trascendente se promueve
// a float. Así el Display puede mostrar fracciones exactas "a/b".
package main

import (
	"fmt"
	"math"
	"math/big"
	"strconv"
)

type Value struct {
	rat *big.Rat // non-nil => exacto
	f   float64  // válido cuando rat == nil
}

func exactRat(r *big.Rat) Value { return Value{rat: r} }
func inexact(f float64) Value   { return Value{f: f} }

func ratOf(n int64) Value { return Value{rat: big.NewRat(n, 1)} }

// float64 convierte el valor a float (los exactos vía Rat.Float64).
func (v Value) float64() float64 {
	if v.rat != nil {
		f, _ := v.rat.Float64()
		return f
	}
	return v.f
}

// isInt dice si el valor es un entero (los float solo si son enteros).
func (v Value) isInt() (int64, bool) {
	if v.rat != nil {
		if !v.rat.IsInt() {
			return 0, false
		}
		n := v.rat.Num()
		if !n.IsInt64() {
			return 0, false
		}
		return n.Int64(), true
	}
	if v.f == math.Trunc(v.f) && math.Abs(v.f) < 9e15 {
		return int64(v.f), true
	}
	return 0, false
}

func (v Value) neg() Value {
	if v.rat != nil {
		return exactRat(new(big.Rat).Neg(v.rat))
	}
	return inexact(-v.f)
}

func (v Value) add(o Value) Value {
	if v.rat != nil && o.rat != nil {
		return exactRat(new(big.Rat).Add(v.rat, o.rat))
	}
	return inexact(v.float64() + o.float64())
}

func (v Value) sub(o Value) Value {
	if v.rat != nil && o.rat != nil {
		return exactRat(new(big.Rat).Sub(v.rat, o.rat))
	}
	return inexact(v.float64() - o.float64())
}

func (v Value) mul(o Value) Value {
	if v.rat != nil && o.rat != nil {
		return exactRat(new(big.Rat).Mul(v.rat, o.rat))
	}
	return inexact(v.float64() * o.float64())
}

// divZero es el error canónico de división por cero.
func divZero() (Value, error) { return Value{}, fmt.Errorf("División por cero") }

func (v Value) div(o Value) (Value, error) {
	if v.rat != nil && o.rat != nil {
		if o.rat.Sign() == 0 {
			return divZero()
		}
		return exactRat(new(big.Rat).Quo(v.rat, o.rat)), nil
	}
	d := o.float64()
	if d == 0 {
		return divZero()
	}
	return inexact(v.float64() / d), nil
}

// mod es el resto con truncamiento hacia cero (como % en C/JS).
// Entre racionales se mantiene exacto: a - trunc(a/b)*b.
func (v Value) mod(o Value) (Value, error) {
	if v.rat != nil && o.rat != nil {
		if o.rat.Sign() == 0 {
			return divZero()
		}
		q := new(big.Rat).Quo(v.rat, o.rat)
		qi, _ := new(big.Int).QuoRem(q.Num(), q.Denom(), new(big.Int))
		r := new(big.Rat).Sub(v.rat, new(big.Rat).Mul(new(big.Rat).SetInt(qi), o.rat))
		return exactRat(r), nil
	}
	d := o.float64()
	if d == 0 {
		return divZero()
	}
	return inexact(math.Mod(v.float64(), d)), nil
}

// pow: exponente entero => exacto (potenciación binaria); si no, float.
func (v Value) pow(e Value) (Value, error) {
	if n, ok := e.isInt(); ok {
		if v.rat != nil {
			if n == 0 {
				return ratOf(1), nil // 0^0 = 1 (igual que math.Pow)
			}
			if v.rat.Sign() == 0 && n < 0 {
				return divZero()
			}
			base := new(big.Rat).Set(v.rat)
			if n < 0 {
				base.Inv(base)
				n = -n
			}
			if n > 100000 {
				return inexact(math.Pow(v.float64(), e.float64())), nil
			}
			res := big.NewRat(1, 1)
			for n > 0 {
				if n&1 == 1 {
					res.Mul(res, base)
				}
				base.Mul(base, base)
				n >>= 1
			}
			return exactRat(res), nil
		}
	}
	r := math.Pow(v.float64(), e.float64())
	if math.IsNaN(r) {
		return Value{}, fmt.Errorf("Resultado inválido")
	}
	if math.IsInf(r, 0) {
		return Value{}, fmt.Errorf("Resultado inválido")
	}
	return inexact(r), nil
}

// percent interpreta el % postfijo: 50% => 0.5 (exacto si lo era).
func (v Value) percent() Value {
	if v.rat != nil {
		return exactRat(new(big.Rat).Quo(v.rat, big.NewRat(100, 1)))
	}
	return inexact(v.f / 100)
}

// evalErr devuelve el mensaje de error si el valor no es representable.
func (v Value) evalErr() string {
	if v.rat != nil {
		return ""
	}
	if math.IsNaN(v.f) {
		return "Resultado inválido"
	}
	if math.IsInf(v.f, 0) {
		return "División por cero"
	}
	return ""
}

// format devuelve (texto, esExacto). Los exactos no enteros salen "a/b".
func (v Value) format() (string, bool) {
	if v.rat != nil {
		if v.rat.IsInt() {
			return v.rat.Num().String(), true
		}
		return v.rat.RatString(), true // "a/b"
	}
	f := v.f
	if math.IsNaN(f) {
		return "Resultado inválido", false
	}
	if math.IsInf(f, 0) {
		return "División por cero", false
	}
	if f == 0 {
		return "0", false
	}
	return strconv.FormatFloat(f, 'g', 10, 64), false
}
