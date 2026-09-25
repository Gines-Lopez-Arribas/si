#!/usr/bin/env bash
# =====================================================================
# Sistemas Informaticos (0483) - 1o DAM - Curso 2026/2027
# Preparacion de datos de la Unidad 2 (AP2, AP3, AEV2)
#
# Ejecutar EN LA VM INVITADA (Ubuntu), como usuario normal, SIN sudo:
#     bash preparar_datos_u2.sh
#
# Crea:
#   ~/si/datos/acceso.log            (registro web ficticio, 60 lineas)
#   ~/si/datos/proyecto/src/app.js   (codigo JavaScript, 24 lineas)
#   ~/si/practicas/u2/parte_a        (vacio)
#   ~/si/practicas/u2/parte_b        (vacio)
#
# Es seguro ejecutarlo varias veces: regenera los datos, no toca
# el contenido de las carpetas de practicas.
# Todos los datos son ficticios (IP privadas, usuarios inventados).
#
# El log es identico en todos los equipos: se genera con un generador
# pseudoaleatorio de semilla fija, no con $RANDOM. Asi la correccion
# estandar de AP3/AEV2 sirve para todo el grupo.
# =====================================================================

set -e

if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: no ejecutes este script con sudo ni como root."
    echo "       Ejecutalo como tu usuario: bash preparar_datos_u2.sh"
    exit 1
fi

BASE="$HOME/si"
DATOS="$BASE/datos"

mkdir -p "$DATOS/proyecto/src" "$BASE/practicas/u2/parte_a" "$BASE/practicas/u2/parte_b"

# ---------------------------------------------------------------------
# 1. acceso.log - formato tipo Apache (common log format)
#
#    Cada entrada combina metodo, ruta, codigo y usuario de forma
#    coherente: no hay DELETE sobre una imagen ni 404 sobre una pagina
#    que existe. Los codigos 304 y 204 llevan tamano 0 (no "-") para que
#    las sumas con awk de AP3 no necesiten filtrar el guion.
# ---------------------------------------------------------------------

# Generador congruencial lineal de semilla fija -> salida reproducible.
# Deja el resultado en $ALEA: no usa 'echo' dentro de $( ) porque eso
# abre una subshell y la semilla actualizada se perderia.
SEMILLA=20262027
ALEA=0
aleatorio() {                       # aleatorio N -> deja en $ALEA un entero [0, N)
    SEMILLA=$(( (SEMILLA * 1103515245 + 12345) % 2147483648 ))
    ALEA=$(( SEMILLA / 65536 % $1 ))
}

# Tabla de sucesos plausibles: metodo|ruta|codigo|usuario|tamano_base
# usuario "-" = peticion anonima; tamano_base 0 = respuesta sin cuerpo
sucesos=(
    'GET|/index.html|200|-|4200'
    'GET|/index.html|304|-|0'
    'GET|/css/estilo.css|200|-|1800'
    'GET|/css/estilo.css|304|-|0'
    'GET|/img/logo.png|200|-|8600'
    'GET|/contacto.html|200|-|3100'
    'GET|/favicon.ico|404|-|490'
    'GET|/login|200|-|2400'
    'POST|/login|302|-|0'
    'POST|/login|401|-|510'
    'GET|/admin|403|ana.lopez|520'
    'GET|/admin|200|marta.soler|6700'
    'GET|/api/pedidos|200|ana.lopez|1500'
    'GET|/api/pedidos|500|jorge.ruiz|640'
    'POST|/api/pedidos|201|jorge.ruiz|310'
    'GET|/api/pedidos/17|200|ana.lopez|420'
    'GET|/api/pedidos/99|404|ana.lopez|480'
    'DELETE|/api/pedidos/17|204|marta.soler|0'
)
n_sucesos=${#sucesos[@]}

ips=(192.168.10.23 192.168.10.45 192.168.10.99 10.0.2.15 10.0.2.20 172.16.5.8)
n_ips=${#ips[@]}

instante=28800                      # 08:00:00 en segundos desde medianoche

: > "$DATOS/acceso.log"
for i in $(seq 1 60); do
    aleatorio $n_sucesos
    IFS='|' read -r met ruta cod usr base <<< "${sucesos[$ALEA]}"
    aleatorio $n_ips
    ip=${ips[$ALEA]}

    # Tamano: el base mas/menos hasta un 25 %, salvo respuestas sin cuerpo
    if [ "$base" -eq 0 ]; then
        tam=0
    else
        aleatorio $(( base / 2 + 1 ))
        tam=$(( base - base / 4 + ALEA ))
    fi

    # Separacion irregular entre peticiones: de 5 s a 6 min
    aleatorio 355
    instante=$(( instante + 5 + ALEA ))
    h=$(( instante / 3600 )); m=$(( instante % 3600 / 60 )); s=$(( instante % 60 ))

    printf '%s - %s [21/Sep/2026:%02d:%02d:%02d +0200] "%s %s HTTP/1.1" %s %s\n' \
        "$ip" "$usr" "$h" "$m" "$s" "$met" "$ruta" "$cod" "$tam" >> "$DATOS/acceso.log"
done

# ---------------------------------------------------------------------
# 2. proyecto/src/app.js - fichero de texto JavaScript
#    Apartado 16 de la AP2: 'file' debe revelar que es texto, no binario.
# ---------------------------------------------------------------------
cat > "$DATOS/proyecto/src/app.js" << 'EOF'
// app.js - servidor de ejemplo para la practica de Sistemas Informaticos
// Datos ficticios. No ejecutar en produccion.

const http = require('http');

const PUERTO = 8080;
const pedidos = [
  { id: 1, cliente: 'Cliente A', total: 120.5 },
  { id: 2, cliente: 'Cliente B', total: 89.9 },
  { id: 3, cliente: 'Cliente C', total: 42.0 }
];

function responder(res, codigo, cuerpo) {
  res.writeHead(codigo, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(cuerpo));
}

const servidor = http.createServer((req, res) => {
  if (req.url === '/api/pedidos') return responder(res, 200, pedidos);
  responder(res, 404, { error: 'No encontrado' });
});

servidor.listen(PUERTO, () => console.log('Escuchando en ' + PUERTO));
// fin de app.js
EOF

# ---------------------------------------------------------------------
# 3. Verificacion
# ---------------------------------------------------------------------
echo "Datos preparados en $DATOS"
echo "  acceso.log : $(wc -l < "$DATOS/acceso.log") lineas (esperado: 60)"
echo "  app.js     : $(wc -l < "$DATOS/proyecto/src/app.js") lineas (esperado: 24)"
echo "Carpetas de practica listas en $BASE/practicas/u2"
echo
echo "Comprueba que ves las dos rutas siguientes:"
echo "  $DATOS/acceso.log"
echo "  $DATOS/proyecto/src/app.js"
