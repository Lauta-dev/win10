# calc-eval

Motor aritmético del modo `calc` del Command Palette. Evaluación async
con generación anti-race del lado QML, binario propio con protocolo
JSON.

## Protocolo

One-shot por stdin de expresión: el QML lo invoca como
`calc-eval "EXPR"` (argv, sin shell) y lee **una línea JSON** por stdout.
Exit 0 siempre; el error viaja en el JSON:

```text
$ calc-eval "200 - { 50 + 6 * (20 - (3 + 7)) + 25 }"
{"ok":true,"result":"65","ratio":65}
$ calc-eval "1/3"
{"ok":true,"result":"1/3","exact":"1/3","num":"1","den":"3","approx":"0.3333333333","ratio":0.3333333333333333}
$ calc-eval "2/0"
{"ok":false,"error":"División por cero"}
```

`result` va al Display; `ratio` (siempre en `ok`) alimenta el chart
pie. `exact` trae la fracción `"a/b"` cuando el cálculo fue exacto
(racionales `+ - * / % ^` entera y `%`/`!` postfijos). Si además es no
entera, `num`/`den` traen numerador y denominador (para renderizarla
apilada estilo `\frac`) y `approx` el decimal aproximado.

## Sintaxis

- Operadores: `+ - * / % ^` (`**` = `^`), unarios, `%` postfijo
  (`50%` → `1/2`), `!` factorial (`5!`).
- Agrupación con `()`, `{}` y `[]` (el cierre debe matchear).
- Multiplicación implícita: `2pi`, `2(3+4)`.
- Funciones: `sin cos tan asin acos atan sinh cosh tanh sqrt cbrt ln
  log log2 exp abs floor ceil round trunc fact` (con o sin paréntesis).
- Comando LaTeX: `\frac a b` o `\frac{a}{b}` (divide exacto).
- Constantes: `pi e tau phi`. Símbolos `× ÷ − π` normalizados.

## Para extender

Agregar una función = 1 entrada en el mapa de `funcs.go` (+ 1 caso en
`eval_test.go`). Operadores nuevos = 1 caso en `parser.go`. QML intacto.

## Build

```sh
cd services/calc && go build -o ../../bin/calc-eval .
```
