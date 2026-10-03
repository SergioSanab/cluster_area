#!/bin/bash
# Corre el programa REPS veces usando los primeros K nodos de nodos.txt
# (K=1 es solo el maestro, K=2 maestro + 1 esclavo, etc.) y agrega los
# tiempos a resultados.csv.
#
# Uso:
#     ./correr_experimento.sh K [REPS]
# Ejemplos:
#     ./correr_experimento.sh 1          # 10 corridas solo con el maestro
#     ./correr_experimento.sh 3          # 10 corridas con maestro + 2 esclavos
#
# Variables opcionales :
#     N=2000000000   subintervalos
#     PPN=1          procesos MPI por nodo (el MISMO en todo el experimento)
#     CALENTAR=1     hace 1 corrida previa que NO se guarda (0 para omitirla)
#     EXTRA_MPI=""   opciones adicionales para mpirun
cd "$(dirname "$0")"

K=${1:?"Uso: $0 K [REPS]   (K = numero de nodos, 1..5)"}
REPS=${2:-10}
N=${N:-2000000000}
PPN=${PPN:-1}
CALENTAR=${CALENTAR:-1}
CSV=resultados.csv

[ -x ./area_simpson ] || { echo "Falta compilar: ./compilar.sh"; exit 1; }
[ -f nodos.txt ]      || { echo "Falta nodos.txt: ./detectar_nodos.sh"; exit 1; }

DISP=$(grep -c . nodos.txt)
if [ "$K" -gt "$DISP" ]; then
  echo "Pediste $K nodos pero nodos.txt solo tiene $DISP. Enciende mas esclavos y corre ./detectar_nodos.sh"
  exit 1
fi

NP=$((K * PPN))
HOSTS="hosts_${K}nodos.txt"
head -n "$K" nodos.txt | awk -v s="$PPN" 'NF {print $1" slots="s}' > "$HOSTS"

MAESTRO=$(head -n1 nodos.txt)
RED="${MAESTRO%.*}.0/24"
MPIRUN="mpirun -np $NP --hostfile $HOSTS --mca btl_tcp_if_include $RED $EXTRA_MPI"

mkdir -p logs
[ -f "$CSV" ] || echo "fecha,nodos,ppn,procesos,repeticion,n,area,error_rel,t_total_s,t_calculo_max_s,t_calculo_min_s,nodos_distintos" > "$CSV"

echo "=============================================================="
echo " Experimento: $K nodo(s), $PPN proceso(s) por nodo = $NP procesos"
echo " n = $N   repeticiones = $REPS"
echo " Hosts usados:"; sed 's/^/    /' "$HOSTS"
echo "=============================================================="

if [ "$CALENTAR" = "1" ]; then
  echo "Corrida de calentamiento (no se guarda)..."
  $MPIRUN ./area_simpson "$N" > "logs/${K}nodos_calentamiento.log" 2>&1 \
    || { echo "Fallo el calentamiento. Revisa logs/${K}nodos_calentamiento.log"; exit 1; }
fi

TIEMPOS=""
for r in $(seq 1 "$REPS"); do
  LOG="logs/${K}nodos_rep${r}.log"
  $MPIRUN ./area_simpson "$N" > "$LOG" 2>&1
  LINEA=$(grep '^CSV,' "$LOG" | tail -n1)
  if [ -z "$LINEA" ]; then
    echo "  Rep $r: ERROR (revisa $LOG)"
    continue
  fi
  # LINEA = CSV,procesos,nodos_distintos,n,area,error,t_total,t_max,t_min
  IFS=, read -r _ P ND NN AREA ERR TT TMAX TMIN <<< "$LINEA"
  echo "$(date '+%Y-%m-%d %H:%M:%S'),$K,$PPN,$P,$r,$NN,$AREA,$ERR,$TT,$TMAX,$TMIN,$ND" >> "$CSV"
  AVISO=""
  [ "$ND" != "$K" ] && AVISO="   <-- OJO: solo participaron $ND nodos distintos"
  printf "  Rep %2d/%d: %10.4f s%s\n" "$r" "$REPS" "$TT" "$AVISO"
  TIEMPOS="$TIEMPOS $TT"
  sleep 2
done

echo "--------------------------------------------------------------"
echo "$TIEMPOS" | tr ' ' '\n' | grep . | awk '
  {s+=$1; if(NR==1||$1<mn)mn=$1; if(NR==1||$1>mx)mx=$1}
  END{ if(NR) printf " Resumen rapido (%d corridas): prom %.4f s | min %.4f s | max %.4f s\n", NR, s/NR, mn, mx }'
echo " Datos agregados a $CSV   (salidas completas en logs/)"
