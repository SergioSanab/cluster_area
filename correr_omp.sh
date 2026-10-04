#!/bin/bash
# Corre el experimento OpenMP: HASTA configuraciones (1, 2, ..., HASTA hilos),
# REPS repeticiones cada una. Imprime los tiempos en pantalla y los guarda
# en resultados_omp.csv
#
# Uso:  ./correr_omp.sh [HASTA] [REPS] [N]
#       por defecto: 5 hilos, 10 repeticiones, n = 300000000
cd "$(dirname "$0")"
HASTA=${1:-5}
REPS=${2:-10}
N=${3:-300000000}
CSV=resultados_omp.csv

[ -x ./area_simpson_omp ] || { echo "Falta compilar:"; echo "  g++ -O2 -fopenmp -o area_simpson_omp area_simpson_omp.cpp -lm"; exit 1; }

NUCLEOS=$(nproc)
echo "Nucleos disponibles en esta maquina: $NUCLEOS"
[ "$HASTA" -gt "$NUCLEOS" ] && echo "AVISO: vas a pedir hasta $HASTA hilos pero solo hay $NUCLEOS nucleos."

[ -f "$CSV" ] || echo "fecha,hilos,nucleos,repeticion,n,area,error_rel,t_total_s,t_hilo_max_s,t_hilo_min_s" > "$CSV"
mkdir -p logs

for H in $(seq 1 "$HASTA"); do
  echo "=============================================================="
  echo " $H hilo(s)   n = $N   repeticiones = $REPS"
  echo "=============================================================="

  ./area_simpson_omp "$H" "$N" > "logs/${H}hilos_calentamiento.log" 2>&1   # no se guarda

  TIEMPOS=""
  for r in $(seq 1 "$REPS"); do
    LOG="logs/${H}hilos_rep${r}.log"
    ./area_simpson_omp "$H" "$N" > "$LOG" 2>&1
    LINEA=$(grep '^CSV,' "$LOG" | tail -n1)
    if [ -z "$LINEA" ]; then
      echo "  Rep $r: ERROR (revisa $LOG)"
      continue
    fi
    IFS=, read -r _ HH NU NN AREA ERR TT TMAX TMIN <<< "$LINEA"
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$HH,$NU,$r,$NN,$AREA,$ERR,$TT,$TMAX,$TMIN" >> "$CSV"
    printf "  Rep %2d/%d: %10.4f s\n" "$r" "$REPS" "$TT"
    TIEMPOS="$TIEMPOS $TT"
    sleep 1
  done

  echo "$TIEMPOS" | tr ' ' '\n' | grep . | awk '
    {s+=$1; if(NR==1||$1<mn)mn=$1; if(NR==1||$1>mx)mx=$1}
    END{ if(NR) printf " Promedio %.4f s | min %.4f s | max %.4f s\n", s/NR, mn, mx }'
  echo
done

echo "Listo. Tiempos en $CSV (salidas completas en logs/)."
exit 0