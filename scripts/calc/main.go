// calc-eval: evaluador aritmético one-shot para el Command Palette.
//
// Uso: calc-eval "EXPR"
// Sale por stdout una sola línea JSON (exit 0 siempre; el error viaja
// en el JSON para que QML no tenga que inferirlo del exit code):
//
//	{"ok":true,"result":"65","exact":""}
//	{"ok":false,"error":"División por cero"}
//
// "result" es lo que va al Display; "exact" trae la fracción "a/b"
// cuando el cálculo fue exacto ("" si fue por float).
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

type response struct {
	Ok     bool    `json:"ok"`
	Result string  `json:"result,omitempty"`
	Exact  string  `json:"exact,omitempty"`
	Num    string  `json:"num,omitempty"`
	Den    string  `json:"den,omitempty"`
	Approx string  `json:"approx,omitempty"`
	Ratio  float64 `json:"ratio,omitempty"`
	Error  string  `json:"error,omitempty"`
}

func main() {
	expr := strings.TrimSpace(strings.Join(os.Args[1:], " "))
	var res response
	if expr == "" {
		res = response{Ok: false, Error: ""}
	} else if v, err := parse(expr); err != nil {
		res = response{Ok: false, Error: err.Error()}
	} else if emsg := v.evalErr(); emsg != "" {
		res = response{Ok: false, Error: emsg}
	} else {
		text, exact := v.format()
		res = response{Ok: true, Result: text, Ratio: v.float64()}
		if exact {
			res.Exact = text
			if num, den, ok := numDen(v); ok {
				res.Num, res.Den = num, den
				res.Approx = approxOf(v)
			}
		}
	}
	out, _ := json.Marshal(res)
	fmt.Println(string(out))
}

// numDen devuelve (numerador, denominador) cuando el valor es una
// fracción exacta no entera, para renderizarla apilada estilo \frac.
func numDen(v Value) (string, string, bool) {
	if v.rat == nil || v.rat.IsInt() {
		return "", "", false
	}
	return v.rat.Num().String(), v.rat.Denom().String(), true
}

// approxOf devuelve el decimal aproximado de un valor exacto.
func approxOf(v Value) string {
	text, _ := inexact(v.float64()).format()
	return text
}
