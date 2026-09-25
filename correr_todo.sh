#!/bin/bash
# Corre el experimento completo: 1, 2, ..., HASTA nodos, REPS veces cada uno.
# Requiere que los esclavos ya esten encendidos y en nodos.txt.
#
# Uso:  ./correr_todo.sh [HASTA] [REPS]        (por defecto 5 y 10)
#       N=... PPN=... ./correr_todo.sh
#
# Si prefieres ir agregando un esclavo a la vez, usa en cambio
# ./correr_experimento.sh 1, luego 2, etc. (el resultado es el mismo CSV).
cd "$(dirname "$0")"
HASTA=${1:-5}
REPS=${2:-10}

for K in $(seq 1 "$HASTA"); do
  ./correr_experimento.sh "$K" "$REPS" || { echo "Se detuvo en K=$K"; exit 1; }
  echo
done
echo "Experimento completo. Descarga resultados.csv para tu reporte."
