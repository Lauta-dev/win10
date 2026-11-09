#!/bin/bash

# Construir todos los binarios de Go a bin/
mkdir -p bin

# A services
cd ./services/

# Daemons (binario único que despacha a diferentes servicios)
echo "Construyendo daemon..."
cd daemons && go build -o ../../bin/daemon; cd ..

# Calculadora
echo "Construyendo calc-eval..."
cd calc && go build -o ../../bin/calc-eval; cd ..

# Themando (gtk-apply, shell-theme, matugen-apply)
echo "Construyendo theming..."
cd theming && go build -o ../../bin/gtk-apply ./cmd/gtk-apply; cd .. 
cd theming && go build -o ../../bin/shell-theme ./cmd/shell-theme; cd ..
cd theming && go build -o ../../bin/matugen-apply ./cmd/matugen-apply; cd ..

# Helpers sueltos
echo "Construyendo list-dirs..."
cd list-dirs && go build -o ../../bin/list-dirs; cd ..

echo "Construyendo list-monitors..."
cd list-monitors && go build -o ../../bin/list-monitors; cd ..

echo "Construyendo resolve-icons..."
cd resolve-icons && go build -o ../../bin/resolve-icons; cd ..

# Otros módulos (qsipc)
echo "Construyendo qsipc..."
cd qsipc && go build -o ../../bin/qsipc; cd ..

echo "Construyendo wp-helper"
cd wp-helper && go build -o ../../bin/wp-helper; cd ..

echo "¡Todos los binarios construidos!"
