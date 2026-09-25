#!/bin/bash
# Compila area_simpson.cpp en el nodo maestro.
# Debe estar dentro de /home/user: esa carpeta se comparte por NFS con los
# esclavos, asi que el ejecutable les llega sin copiarlo a mano.
set -e
cd "$(dirname "$0")"

case "$(pwd)" in
  "$HOME"*) ;;
  *) echo "AVISO: esta carpeta no esta dentro de $HOME."
     echo "       Los esclavos no veran el ejecutable. Copiala a $HOME primero."
     exit 1 ;;
esac

command -v mpicxx >/dev/null || { echo "No se encontro mpicxx. ¿Estas en PelicanHPC?"; exit 1; }

mpicxx -O2 -o area_simpson area_simpson.cpp -lm
chmod +x ./*.sh area_simpson
echo "Listo: $(pwd)/area_simpson"
echo "Prueba rapida en el maestro:"
mpirun -np 1 ./area_simpson 1000000 | grep -E "Area calculada|Error relativo|Tiempo total"
