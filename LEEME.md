# Clúster PelicanHPC de 5 nodos: área bajo la curva con MPI

Cinco PCs del laboratorio, cada uno con VirtualBox y una VM. PC1 es el **maestro**
(arranca desde la ISO de PelicanHPC) y PC2–PC5 son **esclavos** (arrancan por red
desde el maestro).

## Qué hay en esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `area_simpson.cpp` | Programa MPI (Simpson 1/3) para f(x) = x(2 + sen x) + 100e^(−x/100) en [0, 1000] |
| `compilar.sh` | Compila en el maestro y hace una prueba rápida |
| `detectar_nodos.sh` | Encuentra los esclavos encendidos y crea `nodos.txt` (maestro primero) |
| `calibrar.sh` | Encuentra el `n` que hace que 1 nodo tarde ~40 s |
| `correr_experimento.sh K` | 10 corridas con K nodos → agrega a `resultados.csv` |
| `correr_todo.sh` | Hace K = 1, 2, 3, 4, 5 seguidos |

Los esclavos **no se configuran por dentro**: arrancan por PXE desde el maestro y
ven `/home/user` por NFS, así que el ejecutable compilado en el maestro les llega solo.

---

## 1. Antes del laboratorio (con internet)

1. Descarga la ISO de PelicanHPC en el PC1 (sourceforge.net/projects/pelicanhpc).
2. Copia `cluster_simpson.iso` (el paquete con estos archivos) al PC1.
3. Si los PCs no son idénticos, anota el modelo de CPU de cada uno para el reporte.

## 2. Aislamiento de la red (ANTES de encender el maestro)

El maestro levanta un servidor DHCP/PXE. Conectado a la red del laboratorio,
puede repartir IPs a otros equipos o hacer que otros PCs arranquen desde él.

**Opción A (recomendada): switch dedicado.** Desconecta el cable de red de los 5 PCs
de la toma del laboratorio y conéctalos a un switch aparte que no tenga nada más
conectado (sin cable hacia la red del lab ni router). Los PCs se quedan sin internet
durante la práctica.

**Opción B: VLAN.** Si el switch del laboratorio es administrable, el administrador
de red puede poner esos 5 puertos en una VLAN propia sin salida.

**Opción C: segunda tarjeta USB-Ethernet** en cada PC, conectadas a un switch
dedicado. La VM se hace puente sobre esa tarjeta y el PC conserva su red normal por
la tarjeta principal. En Windows, en las propiedades de la tarjeta USB, desmarca
"Protocolo de Internet versión 4 (TCP/IPv4)" y deja marcado
"VirtualBox NDIS6 Bridged Networking Driver".

> La "Red interna" de VirtualBox no sirve aquí: solo comunica VMs dentro del mismo PC.

**Comprobación:** con el switch aislado, en cada PC `ipconfig` debe mostrar en la
tarjeta cableada una IP 169.254.x.x (o ninguna). Eso indica que no le llega el DHCP
del laboratorio. Usa siempre la tarjeta **cableada**, nunca Wi-Fi.

## 3. VM del maestro (PC1)

- **Nueva VM:** Linux / Debian (64-bit). Selecciona la ISO de PelicanHPC y marca
  **"Omitir instalación desatendida"**. Sin disco duro virtual.
- **Memoria:** 4096 MB (mínimo 2048).
- **Procesadores:** hasta el número de núcleos **físicos** del PC, no más.
- **Sistema > Placa base:** EFI desactivado. Orden de arranque: Óptica primero.
- **Almacenamiento:** en el controlador IDE, "Añade unidad óptica" y selecciona
  `cluster_simpson.iso`. La ISO de PelicanHPC queda en la primera unidad.
- **Red:** solo el Adaptador 1.
  - Conectado a: **Adaptador puente**, sobre la tarjeta Ethernet cableada.
  - Avanzadas > Tipo de adaptador: **Intel PRO/1000 MT Desktop (82540EM)**.
  - Modo promiscuo: **Permitir todo**. Cable conectado: sí.
  - Adaptadores 2–4 deshabilitados.

## 4. VMs de los esclavos (PC2–PC5)

- **Nueva VM:** Linux / Debian (64-bit), **sin ISO y sin disco duro**.
- **Memoria:** 4096 MB (mínimo 2048). **Procesadores:** igual que el maestro.
- **Sistema > Placa base:** EFI desactivado. Orden de arranque: marca **Red** y
  súbela al primer lugar.
- **Red:** igual que el maestro (puente sobre la cableada, Intel PRO/1000 MT
  Desktop, promiscuo "Permitir todo").
- **Si clonaste o importaste la misma VM en varios PCs:** en Red > Avanzadas pulsa
  el botón de **regenerar dirección MAC**. Dos VMs con la misma MAC recibirán la
  misma IP y el clúster fallará.

## 5. Arrancar el clúster

1. Enciende la VM del maestro, elige la opción de arranque normal e inicia sesión
   como `user`.
2. Ejecuta `pelican_setup` y sigue las preguntas. Cuando pida confirmar el
   servidor de arranque por red, acepta **solo si ya verificaste el aislamiento**.
3. Enciende las 4 VMs esclavas. Verás el arranque PXE y luego cargarán solas.
4. Espera a que `pelican_setup` termine de detectarlas.

Lo más cómodo es encender los 5 desde el inicio: los scripts usan solo los primeros
K nodos, así que para K = 2 los otros tres quedan encendidos pero sin trabajar. Si tu
profesor exige ir encendiendo esclavos uno por uno, no hay problema: cada vez que
enciendas uno, vuelve a correr `./detectar_nodos.sh`.

## 6. Copiar los archivos al maestro

```bash
lsblk                                  # busca la unidad pequeña (menos de 1 MB), normalmente sr1
sudo mkdir -p /mnt/datos
sudo mount /dev/sr1 /mnt/datos
cp -r /mnt/datos/cluster_simpson ~/
chmod +x ~/cluster_simpson/*.sh
cd ~/cluster_simpson
```

La carpeta **debe** quedar dentro de `/home/user`, porque es la que ven los esclavos.

## 7. Preparar

```bash
./compilar.sh          # compila y hace una prueba rápida
./detectar_nodos.sh    # debe listar MAESTRO + 4 ESCLAVOS
./calibrar.sh 40       # te dice qué N usar
export N=<el valor que te dio calibrar>
```

**Procesos por nodo (PPN).** Por defecto se usa 1 proceso MPI por nodo, así "K nodos"
significa exactamente K procesos y el tiempo con 1 nodo es el secuencial. Si quieres
aprovechar todos los núcleos de cada VM, usa `export PPN=<vCPUs de la VM>` **antes**
de calibrar. Lo importante es usar el mismo PPN y el mismo N en todo el experimento
y anotarlos en el reporte.

## 8. Experimento

Paso a paso, como lo planeaste:

```bash
./correr_experimento.sh 1      # 10 corridas: solo maestro
./correr_experimento.sh 2      # maestro + 1 esclavo
./correr_experimento.sh 3
./correr_experimento.sh 4
./correr_experimento.sh 5
```

O todo de una vez: `./correr_todo.sh`

Cada K hace además 1 corrida de calentamiento que no se guarda. Si aparece
"OJO: solo participaron X nodos distintos", esa corrida no usó los nodos que pediste:
revisa `nodos.txt`.

**Columnas de `resultados.csv`:** fecha, nodos, ppn, procesos, repetición, n, área,
error relativo, tiempo total (s), tiempo de cálculo del proceso más lento y del más
rápido, y nodos distintos que participaron. El separador es coma y el decimal es
punto. En Excel usa Datos > Desde texto/CSV y elige esa configuración.

Para que los tiempos sean comparables: no uses los PCs durante las corridas, déjalos
conectados a la corriente y cierra otros programas en los anfitriones.

## 9. Sacar `resultados.csv` del maestro

- **Memoria USB:** en VirtualBox, Configuración > USB, habilita el controlador y
  agrega la memoria. Dentro de la VM: `lsblk`, luego
  `sudo mount /dev/sdX1 /mnt` (usa la letra que muestre `lsblk`) y
  `cp ~/cluster_simpson/resultados.csv /mnt/`, y por último `sudo umount /mnt`.
- **Por la red aislada:** en el maestro, `cd ~/cluster_simpson && python3 -m http.server 8000`.
  En el PC1, ponle a la tarjeta cableada una IP fija de la misma red del clúster
  (la muestra `detectar_nodos.sh`, por ejemplo terminada en .200) y abre
  `http://<IP del maestro>:8000` en el navegador.

## 10. Problemas comunes

| Síntoma | Causa probable |
|---|---|
| El esclavo dice "No bootable medium" o no hace PXE | Red no es la primera en el orden de arranque, EFI activado, o el adaptador no es Intel PRO/1000 |
| El esclavo no recibe IP | El puente está sobre la tarjeta equivocada (o Wi-Fi), o el cable no llega al switch del clúster |
| Dos esclavos con la misma IP | MAC duplicada: regenérala |
| `detectar_nodos.sh` dice "NO ve area_simpson" | Compilaste fuera de `/home/user` |
| mpirun se queda colgado | El maestro tiene más de un adaptador de red: deja solo el puente |
| Tiempos muy dispersos | Otros programas corriendo en los anfitriones, o más vCPUs que núcleos físicos |
