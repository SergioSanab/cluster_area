#!/bin/bash
# Detecta los esclavos que ya arrancaron por red y genera nodos.txt
# (una IP por linea, el MAESTRO SIEMPRE PRIMERO, luego los esclavos en orden).
#
# Ejecutalo despues de pelican_setup, cuando los esclavos ya esten encendidos.
# Si enciendes un esclavo mas tarde, vuelve a ejecutarlo.
#
# Si el maestro tuviera mas de una tarjeta de red, indica la IP del cluster:
#     MI_IP=10.11.12.1 ./detectar_nodos.sh
cd "$(dirname "$0")"
SALIDA=nodos.txt

if [ -z "$MI_IP" ]; then
  if command -v ip >/dev/null; then
    MI_IP=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)
  else
    MI_IP=$(hostname -I | awk '{print $1}')
  fi
fi
[ -z "$MI_IP" ] && { echo "No pude averiguar la IP del maestro. Usa MI_IP=..."; exit 1; }

SUBRED=${SUBRED:-${MI_IP%.*}}
echo "IP del maestro : $MI_IP"
echo "Red escaneada  : $SUBRED.0/24  (tarda unos segundos)"

TMP=$(mktemp)
for i in $(seq 1 254); do
  IPX="$SUBRED.$i"
  [ "$IPX" = "$MI_IP" ] && continue
  ( ping -c1 -W1 "$IPX" >/dev/null 2>&1 && echo "$IPX" >> "$TMP" ) &
done
wait

echo "$MI_IP" > "$SALIDA"
echo
echo "  MAESTRO  $MI_IP  ($(hostname), $(nproc) nucleos)"

EXE="$(pwd)/area_simpson"
for IPX in $(sort -t. -k4,4n "$TMP"); do
  INFO=$(ssh -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=no \
             "$IPX" "echo \$(hostname) \$(nproc); test -x '$EXE' && echo EXE_OK" 2>/dev/null)
  if [ -z "$INFO" ]; then
    echo "  --       $IPX responde ping pero no acepta SSH sin clave (se ignora)"
    continue
  fi
  NOMBRE_NUC=$(echo "$INFO" | head -n1)
  if echo "$INFO" | grep -q EXE_OK; then
    echo "$IPX" >> "$SALIDA"
    echo "  ESCLAVO  $IPX  ($(echo $NOMBRE_NUC | awk '{print $1", "$2" nucleos"}'))"
  else
    echo "  ESCLAVO  $IPX  ($NOMBRE_NUC) NO ve $EXE -> ¿compilaste dentro de $HOME? (se ignora)"
  fi
done
rm -f "$TMP"

TOTAL=$(wc -l < "$SALIDA")
echo
echo "Nodos utilizables: $TOTAL (guardados en $SALIDA)"
[ "$TOTAL" -lt 5 ] && echo "Aun faltan nodos para llegar a 5. Revisa que los esclavos hayan terminado de arrancar."
exit 0
