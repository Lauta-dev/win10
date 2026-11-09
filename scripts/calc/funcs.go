// Registro de funciones y constantes.
//
// PARA EXTENDER: agregar una entrada a funcs (o a consts). Nada de
// gramática, nada de QML. Cada función recibe los args como float64 y
// devuelve float64 o error en español.
package main

import (
	"fmt"
	"math"
	"math/big"
)

type mathFunc func(args []float64) (float64, error)

func one(f func(float64) float64) mathFunc {
	return func(args []float64) (float64, error) { return f(args[0]), nil }
}

var funcs = map[string]struct {
	nargs int
	fn    mathFunc
}{
	"sin":  {1, one(math.Sin)},
	"cos":  {1, one(math.Cos)},
	"tan":  {1, one(math.Tan)},
	"sinh": {1, one(math.Sinh)},
	"cosh": {1, one(math.Cosh)},
	"tanh": {1, one(math.Tanh)},
	"asin": {1, func(a []float64) (float64, error) {
		if a[0] < -1 || a[0] > 1 {
			return 0, fmt.Errorf("asin fuera de rango")
		}
		return math.Asin(a[0]), nil
	}},
	"acos": {1, func(a []float64) (float64, error) {
		if a[0] < -1 || a[0] > 1 {
			return 0, fmt.Errorf("acos fuera de rango")
		}
		return math.Acos(a[0]), nil
	}},
	"atan": {1, one(math.Atan)},
	"sqrt": {1, func(a []float64) (float64, error) {
		if a[0] < 0 {
			return 0, fmt.Errorf("raíz de número negativo")
		}
		return math.Sqrt(a[0]), nil
	}},
	"cbrt": {1, one(math.Cbrt)},
	"ln": {1, func(a []float64) (float64, error) {
		if a[0] <= 0 {
			return 0, fmt.Errorf("log de número no positivo")
		}
		return math.Log(a[0]), nil
	}},
	"log": {1, func(a []float64) (float64, error) {
		if a[0] <= 0 {
			return 0, fmt.Errorf("log de número no positivo")
		}
		return math.Log10(a[0]), nil
	}},
	"log2": {1, func(a []float64) (float64, error) {
		if a[0] <= 0 {
			return 0, fmt.Errorf("log de número no positivo")
		}
		return math.Log2(a[0]), nil
	}},
	"exp":   {1, one(math.Exp)},
	"abs":   {1, one(math.Abs)},
	"floor": {1, one(math.Floor)},
	"ceil":  {1, one(math.Ceil)},
	"round": {1, one(math.Round)},
	"trunc": {1, one(math.Trunc)},
}

// fact es exacto (big.Int) para enteros 0..170.
func factorial(v Value) (Value, error) {
	n, ok := v.isInt()
	if !ok || n < 0 || n > 170 {
		return Value{}, fmt.Errorf("fact solo enteros 0..170")
	}
	r := big.NewInt(1)
	for i := int64(2); i <= n; i++ {
		r.Mul(r, big.NewInt(i))
	}
	return exactRat(new(big.Rat).SetInt(r)), nil
}

var consts = map[string]float64{
	"pi":  math.Pi,
	"e":   math.E,
	"tau": 2 * math.Pi,
	"phi": (1 + math.Sqrt(5)) / 2,
}

func isFunc(name string) bool {
	_, ok := funcs[name]
	return ok || name == "fact"
}

func isConst(name string) bool {
	_, ok := consts[name]
	return ok
}
