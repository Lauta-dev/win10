#!/bin/bash

# Construir todos los binarios de Go a bin/
mkdir -p bin

# Daemons (binario único que despacha a diferentes servicios)
echo "Construyendo daemon..."
cd services/daemons && go build -o ../../bin/daemon

# Calculadora
echo "Construyendo calc-eval..."
cd services/calc && go build -o ../../bin/calc-eval

# Themando (gtk-apply, shell-theme, matugen-apply)
echo "Construyendo theming..."
cd services/theming && go build -o ../../bin/gtk-apply ./cmd/gtk-apply
cd services/theming && go build -o ../../bin/shell-theme ./cmd/shell-theme
cd services/theming && go build -o ../../bin/matugen-apply ./cmd/matugen-apply

# Helpers sueltos
echo "Construyendo list-dirs..."
cd services/list-dirs && go build -o ../../bin/list-dirs

echo "Construyendo list-monitors..."
cd services/list-monitors && go build -o ../../bin/list-monitors

echo "Construyendo resolve-icons..."
cd services/resolve-icons && go build -o ../../bin/resolve-icons

# Otros módulos (qsipc)
echo "Construyendo qsipc..."
cd services/qsipc && go build -o ../../bin/qsipc

echo "¡Todos los binarios construidos!"