#!/bin/bash
# Busca cuantos subintervalos (n) necesitas para que la corrida con
# SOLO EL MAESTRO dure unos OBJETIVO segundos. Ese n es el que usaras
# en TODAS las corridas (1 a 5 nodos) para que sean comparables.
#
# Uso:  ./calibrar.sh [OBJETIVO_SEGUNDOS]       (por defecto 40)
#       PPN=4 ./calibrar.sh 40                   (si usaras 4 procesos por nodo)
cd "$(dirname "$0")"
OBJ=${1:-40}
PPN=${PPN:-1}
N=100000000

[ -x ./area_simpson ] || { echo "Falta compilar: ./compilar.sh"; exit 1; }

medir() {
  mpirun -np "$PPN" ./area_simpson "$1" | grep '^CSV,' | cut -d, -f7
}

echo "Calibrando con $PPN proceso(s) en el maestro, objetivo ~${OBJ} s"
for intento in 1 2 3; do
  T=$(medir "$N")
  [ -z "$T" ] && { echo "Fallo la ejecucion."; exit 1; }
  printf "  n = %-12s -> %8.3f s\n" "$N" "$T"
  N=$(awk -v n="$N" -v t="$T" -v o="$OBJ" 'BEGIN{
        x = n * o / t; x = int(x / 1000000) * 1000000;
        if (x < 1000000) x = 1000000;
        printf "%.0f", x }')
done

T=$(medir "$N")
printf "  n = %-12s -> %8.3f s\n" "$N" "$T"
echo
echo "Usa este valor en el experimento:"
echo "    export N=$N"
[ "$PPN" != "1" ] && echo "    export PPN=$PPN"
exit 0
