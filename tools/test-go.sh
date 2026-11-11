#!/usr/bin/env bash
set -euo pipefail

# script para recorrer cada módulo de servicios/ con go.mod y correr go test
# filtrar módulos con tests por ahora (calc, qsipc, args)

workspace="/home/lautaro/.config/quickshell/win10"
modules=(
    "$workspace/services/calc"
    "$workspace/services/qsipc"
    "$workspace/services/theming/internal/args"
)

echo "Módulo | Tests | Cobertura | Resultado"
echo "-------|-------|-----------|--------"

for mod in "${modules[@]}"; do
    echo "Corriendo pruebas para $mod"
    cd "$mod"
    # ejecutar go test -count=1 -cover ./... (sin race por rapidez)
    output=$(go test -count=1 -cover ./... 2>&1)
    exit_code=$?
    # extraer número de tests y cobertura del final de la salida
    tests_run=$(echo "$output" | awk '/^ok/ {print $2}')
    if [[ -z "$tests_run" ]]; then
        tests_run="N/A"
    fi
    # cobertura por paquete
    coverage=$(echo "$output" | awk '/coverage:/ {print $5}')
    if [[ -z "$coverage" ]]; then
        coverage="0%"
    fi
    if [[ $exit_code -eq 0 ]]; then
        result="ÉXITO"
    else
        result="FALLA"
    fi
    first_line=$(echo "$output" | head -1)
    printf "%s | %s | %s | %s\n" "$(basename $mod)" "$first_line" "$coverage" "$result"
    cd "$workspace"
done