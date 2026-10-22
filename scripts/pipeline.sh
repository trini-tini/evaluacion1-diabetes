
# Evaluacion 1 Dataset: Diabetes
set -eu                       
export LC_ALL=C               
cd "$(dirname "$0")/.."       

mkdir -p data data/interim data/tablas report/figuras
TAB=data/tablas
INT=data/interim
REPO_URL=https://github.com/trini-tini/evaluacion1-diabetes    
paso() { echo; echo "=== $* ==="; }

# Variables del modelo 
NUMVARS="time_in_hospital num_lab_procedures num_procedures num_medications number_outpatient number_emergency number_inpatient number_diagnoses"
CATVARS="age gender admission_type_id admission_source_id discharge_disposition_id A1Cresult insulin change diabetesMed"

# indice (1..n) de una columna por su nombre
colidx() { head -n 1 "$1" | tr ',' '\n' | grep -n -x "$2" | cut -d: -f1; }


# obtener los datos
paso "0. Obtencion de datos"
if [ ! -s data/diabetic_data.csv ]; then
  
  curl -fsSL -o data/diabetes130.zip \
    "https://archive.ics.uci.edu/static/public/296/diabetes+130-us+hospitals+for+years+1999-2008.zip"
  unzip -o -q data/diabetes130.zip -d data/
fi
ls -l data/diabetic_data.csv data/IDS_mapping.csv

# 1. limpieza de datos
paso "1.1 Inspeccion de los archivos (head, file, cat -A)"
{
  echo "## file";                                  file data/diabetic_data.csv data/IDS_mapping.csv || true
  
  echo "## head -n 1 diabetic_data.csv | cat -A (encabezado, 110 primeros caracteres)"
  head -n 1 data/diabetic_data.csv | cat -A | cut -c1-110
  echo "## fin del encabezado y de la fila 2 con cat -A (se ve ^M = retorno de carro antes de \$)"
  head -n 1 data/diabetic_data.csv | cat -A | rev | cut -c1-24 | rev
  head -n 2 data/diabetic_data.csv | tail -n 1 | cat -A | rev | cut -c1-24 | rev
  echo "## lineas con CR en diabetic_data.csv: $(grep -c $'\r' data/diabetic_data.csv || true)"
  echo "## numero de campos por linea (separador coma)"
  awk -F, '{c[NF]++} END{for(k in c) print "  " k " campos: " c[k] " lineas"}' data/diabetic_data.csv
  echo "## lineas con comillas en diabetic_data.csv: $(grep -c '"' data/diabetic_data.csv || true)"
  echo "## IDS_mapping.csv con cat -A (primeras 12 lineas): tres tablas en un archivo, CRLF"
  head -n 12 data/IDS_mapping.csv | cat -A
} > $TAB/01_inspeccion.txt
cat $TAB/01_inspeccion.txt

paso "1.2 Terminadores de linea: CRLF -> LF (si no, el ultimo campo 'readmitted' trae un \\r oculto)"
tr -d '\r' < data/diabetic_data.csv > $INT/raw_lf.csv
tr -d '\r' < data/IDS_mapping.csv   > $INT/ids_lf.csv
for spec in gender:4 admission_type_id:7 discharge_disposition_id:8 admission_source_id:9 readmitted:50; do
  test "$(colidx $INT/raw_lf.csv ${spec%%:*})" = "${spec##*:}" || { echo "ERROR: la columna ${spec%%:*} no esta en la posicion ${spec##*:}"; exit 1; }
done
echo "OK: gender=\$4, admission_type_id=\$7, discharge_disposition_id=\$8, admission_source_id=\$9, readmitted=\$50"

paso "1.3 IDS_mapping.csv -> una tabla por tipo de codigo"
awk '
  /^,*$/ { next }                                   # linea vacia o "," = separador entre tablas
  /^[a-z_]+,description$/ {                         # encabezado => empieza una tabla nueva
    split($0, h, ","); out = "data/mapa_" h[1] ".csv"; print $0 > out; next }
  { i = index($0, ","); cod = substr($0, 1, i-1); d = substr($0, i+1)
    gsub(/^"|"$/, "", d); gsub(/^ +| +$/, "", d)   # quita comillas y espacios sobrantes
    if (d ~ /,/) d = "\"" d "\""                    # vuelve a citar si lleva comas
    print cod "," d > out }' $INT/ids_lf.csv
for t in admission_type_id discharge_disposition_id admission_source_id; do
  printf "%-26s %2d codigos\n" "mapa_$t.csv" "$(( $(wc -l < data/mapa_$t.csv) - 1 ))"
done
# diccionario en formato largo para etiquetar codigos en las tablas
{ echo "variable,codigo,descripcion"
  for t in admission_type_id discharge_disposition_id admission_source_id; do
    tail -n +2 data/mapa_$t.csv | awk -v t=$t '{ i=index($0,","); d=substr($0,i+1); gsub(/^"|"$/,"",d); gsub(/,/,";",d); print t "," substr($0,1,i-1) "," d }'
  done; } > $INT/diccionario_largo.csv

paso "1.4 Valores faltantes por columna en el archivo original"
# Se cuentan '?' (marcador de faltante del dataset), celdas vacias, 'None' y 'Unknown/Invalid'
awk -F, '
  NR==1 { for (i=1;i<=NF;i++) h[i]=$i; nc=NF; next }
  { for (i=1;i<=NF;i++) { if ($i=="?") q[i]++; else if ($i=="") e[i]++
                          else if ($i=="None") nn[i]++; else if ($i=="Unknown/Invalid") u[i]++ } n++ }
  END { print "columna,signo_pregunta,vacio,None,Unknown_Invalid,pct_signo_pregunta"
        for (i=1;i<=nc;i++) printf "%s,%d,%d,%d,%d,%.2f\n", h[i], q[i], e[i], nn[i], u[i], 100*q[i]/n }
' $INT/raw_lf.csv > $TAB/faltantes_raw.csv
echo "Columnas con alguna celda '?' (de mas a menos):"
{ head -n 1 $TAB/faltantes_raw.csv; awk -F, 'NR>1 && $2>0' $TAB/faltantes_raw.csv | sort -t, -k2,2nr; } \
  | csvcut -c columna,signo_pregunta,pct_signo_pregunta | csvlook
echo "Columnas con 'None' (en examenes de laboratorio significa: examen NO realizado):"
{ head -n 1 $TAB/faltantes_raw.csv; awk -F, 'NR>1 && $4>0' $TAB/faltantes_raw.csv; } | csvcut -c columna,None | csvlook

paso "1.5 Codigos del diccionario que significan 'ausente' o 'fallecido/paliativo'"
{
  echo "tabla,codigo,descripcion,clase,filas_en_datos"
  for spec in admission_type_id:7 discharge_disposition_id:8 admission_source_id:9; do
    t=${spec%%:*}; c=${spec##*:}
    awk -F, -v t="$t" -v c="$c" -v OFS=, '
      FNR==NR { n[$c]++; next }                     # 1er archivo: cuantas filas hay por codigo
      FNR==1  { next }
      { i = index($0, ","); cod = substr($0, 1, i-1); d = substr($0, i+1); gsub(/^"|"$/, "", d)
        cl = ""
        if (d ~ /NULL|Not Available|Not Mapped|Unknown\/Invalid/) cl = "ausente"
        if (t == "discharge_disposition_id" && d ~ /Expired|Hospice/) cl = "fallecido_o_paliativo"
        if (cl != "") { gsub(/,/, ";", d); print t, cod, d, cl, n[cod]+0 } }
    ' $INT/raw_lf.csv data/mapa_$t.csv
  done
} > $TAB/codigos_especiales.csv
csvlook -I --blanks $TAB/codigos_especiales.csv
lista() { awk -F, -v t="$1" -v cl="$2" '$1==t && $4==cl {printf "%s ", $2}' $TAB/codigos_especiales.csv; }
AUS_TIPO=$(lista admission_type_id ausente)
AUS_ALTA=$(lista discharge_disposition_id ausente)
AUS_FUENTE=$(lista admission_source_id ausente)
FALLECIDOS=$(lista discharge_disposition_id fallecido_o_paliativo)
echo "ausentes admission_type_id: $AUS_TIPO| discharge_disposition_id: $AUS_ALTA| admission_source_id: $AUS_FUENTE"
echo "alta por fallecimiento/cuidados paliativos: $FALLECIDOS"

paso "1.6 Paso A: recodificar faltantes ('?', codigos 'ausente', gender invalido) como celda vacia"
awk -F, -v OFS=, -v at="$AUS_TIPO" -v ad="$AUS_ALTA" -v af="$AUS_FUENTE" '
  BEGIN { n=split(at,a," "); for(i=1;i<=n;i++) SA[a[i]]=1
          n=split(ad,a," "); for(i=1;i<=n;i++) SD[a[i]]=1
          n=split(af,a," "); for(i=1;i<=n;i++) SF[a[i]]=1 }
  NR==1 { print; next }
  { for (i=1;i<=NF;i++) if ($i=="?") { $i=""; q++ }
    if ($7 in SA) { $7=""; ct++ }
    if ($8 in SD) { $8=""; cd++ }
    if ($9 in SF) { $9=""; cf++ }
    if ($4=="Unknown/Invalid") { $4=""; cg++ }
    print }
  END { f="data/tablas/recodificacion.csv"
        print "regla,celdas_recodificadas" > f
        print "? -> vacío (todas las columnas)," q+0 > f
        print "admission_type_id con código ausente," ct+0 > f
        print "discharge_disposition_id con código ausente," cd+0 > f
        print "admission_source_id con código ausente," cf+0 > f
        print "gender Unknown/Invalid -> vacío," cg+0 > f }
' $INT/raw_lf.csv > $INT/pasoA.csv
csvlook -I --blanks $TAB/recodificacion.csv

paso "1.7 Paso B: excluir altas por fallecimiento o cuidados paliativos"
awk -F, -v OFS=, -v fl="$FALLECIDOS" '
  BEGIN { n=split(fl,a," "); for(i=1;i<=n;i++) F[a[i]]=1 }
  NR==1 { print; next }
  ($8 in F) { c[$8]++; if ($50=="<30") r[$8]++; next }   # se descarta y se cuenta por codigo
  { print }
  END { for (k in c) print k "," c[k] "," r[k]+0 > "data/interim/excl.tmp" }
' $INT/pasoA.csv > $INT/pasoB.csv
# tabla de excluidos: codigo, descripcion del diccionario, tipo, filas y cuantas de ellas tienen readmitted = <30
# (tipo: 'fallecimiento' si la descripcion dice Expired; si no, 'hospicio')
{ echo "codigo,descripcion,tipo,filas_excluidas,con_reingreso_lt30"
  awk -F, -v OFS=, 'NR==FNR { if ($1=="discharge_disposition_id" && $4=="fallecido_o_paliativo") d[$2]=$3; next }
                    { print $1, d[$1], (d[$1] ~ /Expired/ ? "fallecimiento" : "hospicio"), $2, $3 }' $TAB/codigos_especiales.csv <(sort -t, -k1,1n $INT/excl.tmp)
  echo "TOTAL,,,$(awk -F, '{s+=$2; r+=$3} END{print s "," r}' $INT/excl.tmp)"
} > $TAB/excluidos_por_codigo.csv
csvlook -I --blanks $TAB/excluidos_por_codigo.csv
# tasa de reingreso <30 (por hospitalizacion) antes y despues de excluir
TASA_POST_EXCL=$(tail -n +2 $INT/pasoB.csv | awk -F, '{s+=($50=="<30")} END{printf "%.2f", 100*s/NR}')
echo "tasa <30 por hospitalizacion tras excluir: $TASA_POST_EXCL%"

paso "1.8 Paso C: un solo registro por paciente (primera hospitalizacion = menor encounter_id)"
head -n 1 $INT/pasoB.csv > $INT/hdr.csv
tail -n +2 $INT/pasoB.csv | sort -t, -k2,2n -k1,1n | awk -F, '!visto[$2]++' | sort -t, -k1,1n > $INT/cuerpoC.csv
cat $INT/hdr.csv $INT/cuerpoC.csv > $INT/pasoC.csv
# Sensibilidad al orden excluir y luego deduplicar
tail -n +2 $INT/raw_lf.csv | sort -t, -k2,2n -k1,1n | awk -F, -v fl="$FALLECIDOS" '
  BEGIN { n=split(fl,a," "); for(i=1;i<=n;i++) F[a[i]]=1 }
  { cnt[$2]++ }
  !vistos[$2]++ { primero[$2]=$8 }
  END { for (p in primero) if (primero[p] in F) { m++; if (cnt[p]>1) mm++ }
        print "pacientes cuyo PRIMER encuentro termino en fallecimiento/paliativo: " m
        print "  de ellos con mas de un encuentro registrado (se conserva uno posterior): " mm+0 }
' > $TAB/sensibilidad_orden.txt
cat $TAB/sensibilidad_orden.txt

paso "1.9 Paso D: columnas constantes y variable Reingreso30"
awk -F, -v OFS=, '
  NR==FNR { if (FNR>1) for (i=1;i<=NF;i++) if (!((i,$i) in vis)) { vis[i,$i]=1; nd[i]++ }; next }
  FNR==1  { for (i=1;i<=NF;i++) { keep[i] = (nd[i] > 1)
                                  if (!keep[i]) print "columna constante eliminada: " $i > "/dev/stderr" }
            out=""; for (i=1;i<=NF;i++) if (keep[i]) out = out (out==""?"":OFS) $i
            print out, "Reingreso30"; next }
  { out=""; for (i=1;i<=NF;i++) if (keep[i]) out = out (out==""?"":OFS) $i
    print out, ($50=="<30") ? 1 : 0 }
' $INT/pasoC.csv $INT/pasoC.csv > data/diab_clean.csv

paso "1.10 Resumen de filas antes y despues de cada paso -> $TAB/limpieza_pasos.csv"
nf() { echo $(( $(wc -l < "$1") - 1 )); }
npac() { tail -n +2 "$1" | cut -d, -f2 | sort -u | wc -l; }
ncol() { head -n 1 "$1" | awk -F, '{print NF}'; }
{
  echo "paso,descripcion,filas_antes,filas_despues,pacientes_unicos,columnas"
  echo "0,Archivo original (CRLF -> LF),$(nf $INT/raw_lf.csv),$(nf $INT/raw_lf.csv),$(npac $INT/raw_lf.csv),$(ncol $INT/raw_lf.csv)"
  echo "A,Recodificar faltantes como vacío,$(nf $INT/raw_lf.csv),$(nf $INT/pasoA.csv),$(npac $INT/pasoA.csv),$(ncol $INT/pasoA.csv)"
  echo "B,Excluir fallecidos y cuidados paliativos,$(nf $INT/pasoA.csv),$(nf $INT/pasoB.csv),$(npac $INT/pasoB.csv),$(ncol $INT/pasoB.csv)"
  echo "C,Un registro por paciente (primer encounter_id),$(nf $INT/pasoB.csv),$(nf $INT/pasoC.csv),$(npac $INT/pasoC.csv),$(ncol $INT/pasoC.csv)"
  echo "D,Quitar columnas constantes y crear Reingreso30,$(nf $INT/pasoC.csv),$(nf data/diab_clean.csv),$(npac data/diab_clean.csv),$(ncol data/diab_clean.csv)"
} > $TAB/limpieza_pasos.csv
csvlook -I --blanks $TAB/limpieza_pasos.csv

# Verificaciones automaticas del resultado
test "$(nf data/diab_clean.csv)" -eq "$(npac data/diab_clean.csv)"   || { echo "ERROR: pacientes repetidos"; exit 1; }
test "$(grep -c $'\r' data/diab_clean.csv || true)" -eq 0            || { echo "ERROR: quedan CR"; exit 1; }
test "$(tail -n +2 data/diab_clean.csv | awk -F, '{print $NF}' | sort -u | tr -d '\n')" = "01" || { echo "ERROR: Reingreso30 no es 0/1"; exit 1; }
echo "OK: data/diab_clean.csv -> $(nf data/diab_clean.csv) filas, un registro por paciente, Reingreso30 binaria"


# 2. ANALISIS EXPLORATORIO

paso "2.1 Distribucion de readmitted (original, 3 categorias) y Reingreso30 (limpio)"
RCOL=$(colidx data/diab_clean.csv readmitted)
{
  echo "base,variable,categoria,n,porcentaje"
  tail -n +2 $INT/raw_lf.csv | awk -F, '{c[$50]++; n++} END{for(k in c) printf "original,readmitted,%s,%d,%.2f\n", k, c[k], 100*c[k]/n}' | sort -t, -k3,3
  tail -n +2 data/diab_clean.csv | awk -F, -v r="$RCOL" '{c[$r]++; n++} END{for(k in c) printf "limpia,readmitted,%s,%d,%.2f\n", k, c[k], 100*c[k]/n}' | sort -t, -k3,3
  tail -n +2 data/diab_clean.csv | awk -F, '{c[$NF]++; n++} END{for(k in c) printf "limpia,Reingreso30,%s,%d,%.2f\n", k, c[k], 100*c[k]/n}' | sort -t, -k3,3
} > $TAB/dist_readmitted.csv
csvlook -I --blanks $TAB/dist_readmitted.csv

paso "2.2 Las cinco columnas con mas datos faltantes (celdas vacias tras la limpieza)"
awk -F, -v OFS=, '
  NR==1 { for (i=1;i<=NF;i++) h[i]=$i; nc=NF; next }
  { for (i=1;i<=nc;i++) if ($i=="") e[i]++; n++ }
  END { print "columna,faltantes,pct_faltante"; for (i=1;i<=nc;i++) printf "%s,%d,%.2f\n", h[i], e[i], 100*e[i]/n }
' data/diab_clean.csv > $TAB/faltantes_limpio_todas.csv
{ echo "columna,faltantes,pct_faltante"; tail -n +2 $TAB/faltantes_limpio_todas.csv | sort -t, -k3,3nr | head -n 5; } > $TAB/faltantes_top5.csv
csvlook -I --blanks $TAB/faltantes_top5.csv
# 'None' en examenes de laboratorio = examen NO realizado (no es dato faltante)
{
  echo "columna,filas_con_None,pct_examen_no_realizado"
  for v in A1Cresult max_glu_serum; do
    c=$(colidx data/diab_clean.csv $v)
    tail -n +2 data/diab_clean.csv | awk -F, -v c="$c" -v v="$v" '$c=="None"{k++} END{printf "%s,%d,%.2f\n", v, k, 100*k/NR}'
  done
} > $TAB/examenes_no_realizados.csv
csvlook -I --blanks $TAB/examenes_no_realizados.csv

paso "2.3 Estadisticos descriptivos"
{
  echo "variable,n,media,desv_est,min,Q1,mediana,Q3,max"
  for v in time_in_hospital num_lab_procedures num_medications number_diagnoses; do
    csvcut -c "$v" data/diab_clean.csv | tail -n +2 | sort -n | awk -v v="$v" '
      function q(p,   pos, lo) { pos=(n-1)*p+1; lo=int(pos); return x[lo] + (pos-lo)*(x[(lo<n)?lo+1:lo]-x[lo]) }
      { x[NR]=$1; s+=$1; ss+=$1*$1 }
      END { n=NR; m=s/n; sd=sqrt((ss-n*m*m)/(n-1))
            printf "%s,%d,%.2f,%.2f,%d,%.1f,%.1f,%.1f,%d\n", v, n, m, sd, x[1], q(0.25), q(0.5), q(0.75), x[n] }'
  done
} > $TAB/descriptivos.csv
csvlook -I --blanks $TAB/descriptivos.csv

paso "2.4 Tasa de reingreso <30 dias segun variables clave"
# tasa_por <columna>: categoria,n,reingresos,tasa_pct
tasa_por() {
  csvcut -c "$1",Reingreso30 data/diab_clean.csv | tail -n +2 | awk -F, -v OFS=, '
    { k = ($1=="" ? "NA" : $1); n[k]++; r[k] += $2 }
    END { for (k in n) printf "%s,%d,%d,%.2f\n", k, n[k], r[k], 100*r[k]/n[k] }'
}
{ echo "grupo_edad,n,reingresos,tasa_pct"; tasa_por age | sort -t, -k1,1; } > $TAB/tasa_edad.csv
# ingresos hospitalarios previos 
IC=$(colidx data/diab_clean.csv number_inpatient)
{ echo "ingresos_previos,n,reingresos,tasa_pct"
  tail -n +2 data/diab_clean.csv | awk -F, -v OFS=, -v c="$IC" '
    { k = ($c>=4) ? "4+" : $c; n[k]++; r[k] += $NF }
    END { for (k in n) printf "%s,%d,%d,%.2f\n", k, n[k], r[k], 100*r[k]/n[k] }' | sort -t, -k1,1; } > $TAB/tasa_inpatient.csv
{ echo "A1Cresult,n,reingresos,tasa_pct";     tasa_por A1Cresult  | sort -t, -k1,1; } > $TAB/tasa_A1C.csv
{ echo "change,n,reingresos,tasa_pct";        tasa_por change     | sort -t, -k1,1; } > $TAB/tasa_change.csv
{ echo "diabetesMed,n,reingresos,tasa_pct";   tasa_por diabetesMed | sort -t, -k1,1; } > $TAB/tasa_diabetesMed.csv
for f in tasa_edad tasa_inpatient tasa_A1C tasa_change tasa_diabetesMed; do csvlook -I --blanks $TAB/$f.csv; echo; done

paso "2.5 Los 10 diagnosticos principales (diag_1, codigos ICD-9) y su tasa de reingreso"
# descripcion de las categorias ICD-9-CM 
DIAG_DESC='414|Otras formas de cardiopatía isquémica crónica;428|Insuficiencia cardiaca;786|Síntomas respiratorios y del tórax;410|Infarto agudo de miocardio;486|Neumonía (organismo no especificado);427|Arritmias cardiacas;715|Osteoartrosis;434|Oclusión de arterias cerebrales;682|Celulitis y absceso;780|Síntomas generales;491|Bronquitis crónica;996|Complicaciones de dispositivos y procedimientos;276|Trastornos hidroelectrolíticos y ácido-base;599|Otros trastornos de uretra y vías urinarias'
{ echo "diag_1,descripcion,n,reingresos,tasa_pct"
  tasa_por diag_1 | sort -t, -k2,2nr -k1,1 | head -n 10 | awk -F, -v OFS=, -v dd="$DIAG_DESC" '
    BEGIN { n=split(dd,a,";"); for (i=1;i<=n;i++) { split(a[i],b,"|"); D[b[1]]=b[2] } }
    { print $1, (($1 in D) ? D[$1] : ""), $2, $3, $4 }'
} > $TAB/top10_diag1.csv
csvlook -I --blanks $TAB/top10_diag1.csv

DX250=$(tasa_por diag_1 | awk -F, '$1!="NA" { split($1, p, "."); n[p[1]]+=$2; r[p[1]]+=$3 }
  END { for (k in n) if (n[k] > n["250"]) pos++; printf "%d,%.2f,%d\n", n["250"], 100*r["250"]/n["250"], pos+1 }')
NCOD250=$(tail -n +2 data/diab_clean.csv | cut -d, -f$(colidx data/diab_clean.csv diag_1) | grep '^250' | sort -u | wc -l)
echo "diag_1 agrupado 250.xx: $DX250 (n,tasa,lugar) en $NCOD250 subcodigos distintos"

# 3. MODELACION PREDICTIVA CON VOWPAL WABBIT



# formato vw (awk). Numericas estandarizadas con media y desv. est.
# del ENTRENAMIENTO (file 1 = estadisticas); categoricas como variable=valor.
CSV2VW='
  BEGIN { nn=split(nums,NV," "); nc=split(cats,CV," ") }
  FNR==NR { if (FNR>1) { mu[$1]=$2; sd[$1]=$3 }; next }
  FNR==1  { for (i=1;i<=NF;i++) col[$i]=i; next }
  { y = ($(col["Reingreso30"])==1) ? 1 : -1
    line = y " |num"
    for (j=1;j<=nn;j++) line = line " " NV[j] ":" sprintf("%.5f", ($(col[NV[j]]) - mu[NV[j]]) / sd[NV[j]])
    if (model=="B") {
      line = line " |cat"
      for (j=1;j<=nc;j++) { v=$(col[CV[j]]); if (v=="") v="NA"; gsub(/[^A-Za-z0-9_.]/, "_", v)
                            line = line " " CV[j] "=" v } }
    print line }'

# Flujo infinito de bytes pseudoaleatorios y reproducibles 

fuente_aleatoria() {
  python3 -c '
import random, sys
r = random.Random(int(sys.argv[1])); w = sys.stdout.buffer
while True:
    w.write(r.getrandbits(8 * 4096).to_bytes(4096, "big"))' "$1" 2>/dev/null
}

# Generador congruencial (Park-Miller)
AWK_RND='function rnd() { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }'

# AUC
auc() {
  tail -n +2 "$1" | sort -t, -k2,2g | awk -F, '
    function cerrar() { s += gp*(cn + gn/2); cn += gn; gp=0; gn=0 }
    NR>1 && $2!=prev { cerrar() }
    { if ($1==1) { gp++; P++ } else { gn++; Q++ }; prev=$2 }
    END { cerrar(); printf "%.3f", s/(P*Q) }'
}

# metricas <real,prob>: capturados,total,sensibilidad%,precision%,lift,auc,exactitud%@0.5
# Reingresos capturados en el 20% de mayor riesgo 
metricas() {
  local f=$1 NT K TOT CAP A ACC
  NT=$(tail -n +2 "$f" | wc -l)
  K=$(( NT / 5 ))
  TOT=$(tail -n +2 "$f" | awk -F, '{s+=$1} END{print s}')
  CAP=$(tail -n +2 "$f" | sort -t, -k2,2gr | head -n "$K" | awk -F, '{s+=$1} END{print s}')
  A=$(auc "$f")
  ACC=$(tail -n +2 "$f" | awk -F, '{ if (($2>=0.5)==($1==1)) ok++ } END{printf "%.2f", 100*ok/NR}')
  awk -v nt=$NT -v k=$K -v tot=$TOT -v c=$CAP -v a=$A -v acc=$ACC \
    'BEGIN{ printf "%d,%d,%.2f,%.2f,%.2f,%s,%s\n", c, tot, 100*c/tot, 100*c/k, (c/k)/(tot/nt), a, acc }'
}

# 1000 selecciones aleatorias del 20%: media, desv. est., minimo y maximo de la sensibilidad (%)
simular_azar() {
  tail -n +2 "$1" | awk -F, "$AWK_RND"'
    { y[NR]=$1; idx[NR]=NR; tot+=$1 }
    END { n=NR; k=int(n/5); seed=42; B=1000
          for (b=1;b<=B;b++) { c=0
            for (i=1;i<=k;i++) { j=i+int(rnd()*(n-i+1)); t=idx[i]; idx[i]=idx[j]; idx[j]=t; c+=y[idx[i]] }
            s=100*c/tot; S+=s; SS+=s*s; if (b==1||s<mn) mn=s; if (b==1||s>mx) mx=s }
          m=S/B; printf "%.2f,%.2f,%.2f,%.2f\n", m, sqrt((SS-B*m*m)/(B-1)), mn, mx }'
}

# sensibilidad (%) al contactar 5%,10%,...,100% de los pacientes mejor puntuados
curva() {
  tail -n +2 "$1" | sort -t, -k2,2gr | awk -F, '
    { c+=$1; cum[NR]=c }
    END { n=NR; for (p=5;p<=100;p+=5) { k=int(n*p/100+0.5); printf "%.2f\n", 100*cum[k]/c } }'
}

# entrena los Modelos A y B
ajustar() {
  local D=$1 M S

  #  3.2 estandarizacion con estadisticos del entrenamiento
  awk -F, -v nums="$NUMVARS" '
    BEGIN { nv=split(nums,V," ") }
    NR==1 { for (i=1;i<=NF;i++) c[$i]=i; next }
    { for (j=1;j<=nv;j++) { x=$(c[V[j]]); s[j]+=x; ss[j]+=x*x }; n++ }
    END { print "variable,media,desv_est"
          for (j=1;j<=nv;j++) { m=s[j]/n; printf "%s,%.6f,%.6f\n", V[j], m, sqrt((ss[j]-n*m*m)/(n-1)) } }
  ' $D/train.csv > $D/train_stats.csv

  # 3.3 conversion a formato vw 
  for M in A B; do
    for S in train test; do
      awk -F, -v model=$M -v nums="$NUMVARS" -v cats="$CATVARS" "$CSV2VW" $D/train_stats.csv $D/$S.csv > $D/${S}_$M.vw
    done
  done

  #  3.4 entrenamiento (logistica) y prediccion 
  for M in A B; do
    vw -d $D/train_$M.vw -f $D/model_$M.vw --loss_function logistic --passes 10 -c -k --holdout_off --l2 1e-6 -b 22 --random_seed 42 --quiet
    vw -t -d $D/train_$M.vw -i $D/model_$M.vw --invert_hash $D/pesos_$M.txt --quiet
    vw -t -d $D/test_$M.vw  -i $D/model_$M.vw -p $D/score_$M.txt --quiet
  done
  tail -n +2 $D/test.csv | awk -F, '{print $NF}' > $D/real_test.txt
  for M in A B; do      # probabilidad = 1/(1+exp(-score))
    { echo "real,prob"; paste -d, $D/real_test.txt <(awk '{printf "%.8f\n", 1/(1+exp(-$1))}' $D/score_$M.txt); } > $D/test_pred_$M.csv
  done
}

# modelar
modelar() {
  local TAGM=$1 OUT=$2 D=data/part_$1
  local NT K TOT NTR NTEST M
  mkdir -p "$D" "$OUT"

  #  3.1 particion 70/30 con semilla 42 
  head -n 1 data/diab_clean.csv > $D/header.csv
  if [ "$TAGM" = "enunciado" ]; then
    tail -n +2 data/diab_clean.csv | shuf --random-source=<(yes 42) > $D/diab_shuf.csv
  else
    tail -n +2 data/diab_clean.csv | shuf --random-source=<(fuente_aleatoria 42) > $D/diab_shuf.csv
  fi
  NTR=$(( $(wc -l < $D/diab_shuf.csv) * 7 / 10 ))
  (cat $D/header.csv; head -n $NTR $D/diab_shuf.csv) > $D/train.csv
  (cat $D/header.csv; tail -n +$((NTR+1)) $D/diab_shuf.csv) > $D/test.csv

  ajustar $D

  # 3.5 evaluacion en el 20% de mayor riesgo 
  NTEST=$(( $(wc -l < $D/test.csv) - 1 ))
  K=$(( NTEST / 5 ))
  TOT=$(awk '{s+=$1} END{print s}' $D/real_test.txt)
  local TASA_TRAIN TASA_TEST
  TASA_TRAIN=$(tail -n +2 $D/train.csv | awk -F, '{s+=$NF} END{printf "%.2f", 100*s/NR}')
  TASA_TEST=$(awk -v t=$TOT -v n=$NTEST 'BEGIN{printf "%.2f", 100*t/n}')
  local AZ
  AZ=$(simular_azar $D/test_pred_B.csv)
  {
    echo "modelo,capturados_top20,reingresos_test,sensibilidad_pct,precision_pct,lift,auc,exactitud_pct"
    awk -v k=$K -v tot=$TOT -v nt=$NTEST 'BEGIN{ printf "Selección aleatoria (esperado),%.1f,%d,20.00,%.2f,1.00,0.500,-\n", k*tot/nt, tot, 100*tot/nt }'
    echo "Modelo A,$(metricas $D/test_pred_A.csv)"
    echo "Modelo B,$(metricas $D/test_pred_B.csv)"
    awk -v tot=$TOT -v nt=$NTEST 'BEGIN{ printf "Siempre no reingreso,0,%d,0.00,-,-,-,%.2f\n", tot, 100*(1-tot/nt) }'
  } > $OUT/resultados_modelos.csv
  echo "$AZ" | awk -F, 'BEGIN{print "media_sens_pct,desv_est,minimo,maximo"} {print}' > $OUT/aleatorio_simulacion.csv

  #  3.6 curva de ganancia acumulada 
  { echo "pct_contactado,aleatorio,modelo_A,modelo_B"
    paste -d, <(seq 5 5 100) <(seq 5 5 100) <(curva $D/test_pred_A.csv) <(curva $D/test_pred_B.csv); } > $OUT/curva_ganancia.csv

  #3.7 pesos de los modelos 
  for M in A B; do awk -F: 'NF==3 {print $1 "," $3}' $D/pesos_$M.txt > $D/pesos_$M.csv; done
  { echo "variable,peso_por_DE"
    awk -F, -v nums="$NUMVARS" 'BEGIN{n=split(nums,V," ")} {w[$1]=$2} END{for(j=1;j<=n;j++) printf "%s,%.3f\n", V[j], w["num^" V[j]]}' $D/pesos_A.csv; } > $OUT/pesos_A.csv
  awk -F, -v nums="$NUMVARS" -v cats="$CATVARS" '
    BEGIN { nn=split(nums,NV," "); nc=split(cats,CV," ") }
    function etiqueta(var, lev) { if (var=="age") { gsub(/^_/,"[",lev); sub(/_$/,")",lev); sub(/_/,"-",lev) }; return lev }
    FILENAME==ARGV[1] {                                   # train.csv: frecuencia de cada nivel
      if (FNR==1) { for (i=1;i<=NF;i++) col[$i]=i; next }
      for (j=1;j<=nc;j++) { v=$(col[CV[j]]); if (v=="") v="NA"; gsub(/[^A-Za-z0-9_.]/,"_",v)
                            k=CV[j] SUBSEP v; cnt[k]++
                            if (cnt[k] > best[CV[j]]) { best[CV[j]]=cnt[k]; ref[CV[j]]=v } }
      next }
    FILENAME==ARGV[2] { w[$1]=$2; next }                  # pesos de vw (nombre,peso)
    FILENAME==ARGV[3] { if (FNR>1) desc[$1 SUBSEP $2]=$3; next }   # diccionario largo
    END { print "variable,nivel,descripcion,referencia,n_train,peso,tipo"
          for (j=1;j<=nn;j++) printf "%s,,,,,%.3f,numérica (por 1 DE)\n", NV[j], w["num^" NV[j]]
          for (k in cnt) { split(k, a, SUBSEP); var=a[1]; lev=a[2]; if (lev==ref[var]) continue
            printf "%s,%s,%s,%s,%d,%.3f,categórica vs referencia\n", var, etiqueta(var,lev), desc[var SUBSEP lev], etiqueta(var,ref[var]), cnt[k], w["cat^" var "=" lev] - w["cat^" var "=" ref[var]] } }
  ' $D/train.csv $D/pesos_B.csv $INT/diccionario_largo.csv > $D/pesos_B_todos.csv
  # top 15 por peso entre numericas y categorias con al menos 300 pacientes en el entrenamiento
  { echo "variable,nivel,descripcion,referencia,n_train,peso,tipo"
    tail -n +2 $D/pesos_B_todos.csv | awk -F, '$5=="" || $5>=300 {a=($6<0)?-$6:$6; print a "," $0}' | sort -t, -k1,1gr | head -n 15 | cut -d, -f2- \
      | awk -F, -v OFS=, '{ if (length($3)>46) $3=substr($3,1,43) "..."; print }'; } > $OUT/pesos_B_top15.csv

  { echo "variable,peso_por_DE"; tail -n +2 $D/pesos_B_todos.csv | awk -F, '$7 ~ /^num/ {print $1 "," $6}'; } > $OUT/pesos_B_numericas.csv

  # verificar queningun paciente aparece en entrenamiento y prueba a la vez 
  local COMPARTIDOS
  COMPARTIDOS=$(comm -12 <(tail -n +2 $D/train.csv | cut -d, -f2 | sort) <(tail -n +2 $D/test.csv | cut -d, -f2 | sort) | wc -l)
  echo "pacientes compartidos entre train y test: $COMPARTIDOS"
  test "$COMPARTIDOS" -eq 0 || { echo "ERROR: fuga de pacientes entre train y test"; exit 1; }

  #  3.8 revisar  equidad por raza 
  # pct_seleccionado = % del grupo incluido en el 20% de mayor riesgo; sensibilidad = % de sus reingresos capturados.
  # IC 95% de Wald.
  local RC
  RC=$(colidx $D/test.csv race)
  { echo "raza,n,pct_muestra,tasa_reingreso_pct,pct_seleccionado,ic95_seleccionado,sensibilidad_pct,ic95_sensibilidad,precision_pct"
    paste -d, <(tail -n +2 $D/test.csv | cut -d, -f$RC) <(tail -n +2 $D/test_pred_B.csv) | sort -t, -k3,3gr | awk -F, -v K=$K '
      function ic(p, m,   se, lo, hi) { if (m<=0) return "-"; se=sqrt(p*(1-p)/m); lo=100*(p-1.96*se); hi=100*(p+1.96*se)
                                        if (lo<0) lo=0; if (hi>100) hi=100; return sprintf("%.1f-%.1f", lo, hi) }
      { g=($1==""?"NA":$1); n[g]++; r[g]+=$2; N++; if (NR<=K) { f[g]++; cp[g]+=$2 } }
      END { for (g in n) printf "%s,%d,%.2f,%.2f,%.2f,%s,%.2f,%s,%.2f\n", g, n[g], 100*n[g]/N, 100*r[g]/n[g], 100*f[g]/n[g], ic(f[g]/n[g], n[g]), (r[g]>0?100*cp[g]/r[g]:0), ic(cp[g]/r[g], r[g]), (f[g]>0?100*cp[g]/f[g]:0) }' | sort -t, -k2,2nr
  } > $OUT/equidad_raza.csv

  # 3.8b bootstrap (1000 remuestras del test)
  if [ "${3:-}" = "bootstrap" ]; then
    local TA TB
    TA=$(tail -n +2 $D/test_pred_A.csv | cut -d, -f2 | sort -gr | sed -n "${K}p")
    TB=$(tail -n +2 $D/test_pred_B.csv | cut -d, -f2 | sort -gr | sed -n "${K}p")
    paste -d, $D/real_test.txt <(tail -n +2 $D/test_pred_A.csv | cut -d, -f2) <(tail -n +2 $D/test_pred_B.csv | cut -d, -f2) | awk -F, -v ta=$TA -v tb=$TB "$AWK_RND"'
      { y[NR]=$1; sa[NR]=($2>=ta); sb[NR]=($3>=tb) }
      END { n=NR; seed=42; B=1000
            for (b=1;b<=B;b++) { t=0; ca=0; cb=0; na=0; nb=0
              for (i=1;i<=n;i++) { j=1+int(rnd()*n); t+=y[j]; ca+=y[j]*sa[j]; cb+=y[j]*sb[j]; na+=sa[j]; nb+=sb[j] }
              la=(ca/na)/(t/n); lb=(cb/nb)/(t/n)
              printf "%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n", 100*ca/t, 100*cb/t, la, lb, 100*(cb-ca)/t, lb-la } }' > $D/bootstrap.txt
    { echo "metrica,ic95_inf,mediana,ic95_sup"
      local i=1 m
      for m in sensibilidad_A sensibilidad_B lift_A lift_B dif_sensibilidad_B_menos_A dif_lift_B_menos_A; do
        cut -d, -f$i $D/bootstrap.txt | sort -g | awk -v m=$m '{x[NR]=$1} END{printf "%s,%.2f,%.2f,%.2f\n", m, x[int(0.025*NR)+1], x[int(0.5*NR)], x[int(0.975*NR)]}'
        i=$((i+1))
      done; } > $OUT/bootstrap_ic.csv
  fi

  #  3.9 valores importantes de esta particion 
  local CAP_A TOT_A SENS_A PREC_A LIFT_A AUC_A ACC_A CAP_B TOT_B SENS_B PREC_B LIFT_B AUC_B ACC_B
  IFS=, read -r CAP_A TOT_A SENS_A PREC_A LIFT_A AUC_A ACC_A <<< "$(metricas $D/test_pred_A.csv)"
  IFS=, read -r CAP_B TOT_B SENS_B PREC_B LIFT_B AUC_B ACC_B <<< "$(metricas $D/test_pred_B.csv)"
  {
    echo "NTRAIN=$(( $(wc -l < $D/train.csv) - 1 ))"; echo "NTEST=$NTEST"; echo "K=$K"; echo "TOT_TEST=$TOT"
    echo "TASA_TRAIN=$TASA_TRAIN"; echo "TASA_TEST=$TASA_TEST"
    echo "CAP_A=$CAP_A"; echo "SENS_A=$SENS_A"; echo "PREC_A=$PREC_A"; echo "LIFT_A=$LIFT_A"; echo "AUC_A=$AUC_A"; echo "ACC_A=$ACC_A"
    echo "CAP_B=$CAP_B"; echo "SENS_B=$SENS_B"; echo "PREC_B=$PREC_B"; echo "LIFT_B=$LIFT_B"; echo "AUC_B=$AUC_B"; echo "ACC_B=$ACC_B"
    echo "ACC_BASE=$(awk -v t=$TOT -v n=$NTEST 'BEGIN{printf "%.2f", 100*(1-t/n)}')"
    echo "N05_A=$(tail -n +2 $D/test_pred_A.csv | awk -F, '$2>=0.5{k++} END{print k+0}')"; echo "N05_B=$(tail -n +2 $D/test_pred_B.csv | awk -F, '$2>=0.5{k++} END{print k+0}')"
    echo "AZAR_MEDIA=$(echo $AZ | cut -d, -f1)"; echo "AZAR_DE=$(echo $AZ | cut -d, -f2)"
    echo "AZAR_MIN=$(echo $AZ | cut -d, -f3)";   echo "AZAR_MAX=$(echo $AZ | cut -d, -f4)"
  } > $OUT/valores_modelo.env

  echo "[$TAGM] train $(( $(wc -l < $D/train.csv) - 1 )) | test $NTEST | tasa train $TASA_TRAIN% | tasa test $TASA_TEST% | top20% = $K pacientes"
  csvlook -I --blanks $OUT/resultados_modelos.csv
}

paso "3. Modelacion con vw: particion principal "
modelar principal $TAB bootstrap
echo " IC 95% bootstrap (1000 remuestras del test) "; csvlook -I --blanks $TAB/bootstrap_ic.csv
paso "3. Analisis de sensibilidad: particion  (shuf --random-source=<(yes 42))"
modelar enunciado $TAB/alt_enunciado
cp data/part_principal/test_pred_B.csv data/test_pred.csv        # test_pred.csv = Modelo B, particion principal

paso "3.10 Comparacion de ambas particiones"
{
  echo "particion,tasa_train_pct,tasa_test_pct,sens_A_pct,lift_A,sens_B_pct,lift_B"
  for P in principal enunciado; do
    f=$TAB/valores_modelo.env; [ "$P" = enunciado ] && f=$TAB/alt_enunciado/valores_modelo.env
    ( . $f; echo "$P,$TASA_TRAIN,$TASA_TEST,$SENS_A,$LIFT_A,$SENS_B,$LIFT_B" )
  done
} > $TAB/comparacion_particiones.csv
csvlook -I --blanks $TAB/comparacion_particiones.csv
echo "--- curva de ganancia (principal) ---";  csvlook -I --blanks $TAB/curva_ganancia.csv
echo "--- 1000 selecciones aleatorias del 20% ---"; csvlook -I --blanks $TAB/aleatorio_simulacion.csv
echo "--- pesos Modelo A (por 1 DE) ---";       csvlook -I --blanks $TAB/pesos_A.csv
echo "--- pesos Modelo B (top 15 por |peso|) ---"; csvlook -I --blanks $TAB/pesos_B_top15.csv
echo "--- equidad por raza (Modelo B, 20% de mayor riesgo) ---"; csvlook -I --blanks $TAB/equidad_raza.csv

paso "3.11 Pregunta (iv): ¿que pasa si se usan todas las hospitalizaciones de cada paciente?"
# solo cambia como se parte en 70/30:
#   - por fila:     cada hospitalizacion va al azar a train o test (un paciente puede quedar en ambos)
#   - por paciente: se sortean los pacientes; todas sus hospitalizaciones van al mismo lado
# Si la particion por fila da mejores metricas, la diferencia es fuga de informacion entre hospitalizaciones.
FT=data/part_todas
mkdir -p $FT/fila $FT/paciente
awk -F, -v OFS=, 'NR==1 { print $0, "Reingreso30"; next } { print $0, ($50=="<30") ? 1 : 0 }' $INT/pasoB.csv > $FT/todas.csv
head -n 1 $FT/todas.csv > $FT/header.csv
NTODAS=$(( $(wc -l < $FT/todas.csv) - 1 ))
# por fila
tail -n +2 $FT/todas.csv | shuf --random-source=<(fuente_aleatoria 42) > $FT/fila/shuf.csv
NTRF=$(( NTODAS * 7 / 10 ))
(cat $FT/header.csv; head -n $NTRF $FT/fila/shuf.csv) > $FT/fila/train.csv
(cat $FT/header.csv; tail -n +$((NTRF+1)) $FT/fila/shuf.csv) > $FT/fila/test.csv
# por paciente (70% de los pacientes a train); las filas de train se mezclan para el aprendizaje en linea de vw
tail -n +2 $FT/todas.csv | cut -d, -f2 | sort -u | shuf --random-source=<(fuente_aleatoria 42) > $FT/paciente/ids.txt
NTRP=$(( $(wc -l < $FT/paciente/ids.txt) * 7 / 10 ))
head -n $NTRP $FT/paciente/ids.txt > $FT/paciente/ids_train.txt
tail -n +2 $FT/todas.csv | awk -F, 'NR==FNR { tr[$1]=1; next } ($2 in tr) { print > "'$FT'/paciente/tr_body.csv"; next } { print }' \
  $FT/paciente/ids_train.txt - > $FT/paciente/te_body.csv
(cat $FT/header.csv; shuf --random-source=<(fuente_aleatoria 42) $FT/paciente/tr_body.csv) > $FT/paciente/train.csv
(cat $FT/header.csv; cat $FT/paciente/te_body.csv) > $FT/paciente/test.csv
rm -f $FT/fila/shuf.csv $FT/paciente/tr_body.csv $FT/paciente/te_body.csv
{
  echo "escenario,n_train,n_test,pct_test_paciente_en_train,tasa_test_pct,sensibilidad_B_pct,precision_B_pct,lift_B,auc_B"
  # el analisis principal (una hospitalizacion por paciente)
  ( . $TAB/valores_modelo.env
    echo "Una hospitalización por paciente (principal),$NTRAIN,$NTEST,0.00,$TASA_TEST,$SENS_B,$PREC_B,$LIFT_B,$AUC_B" )
  for E in fila paciente; do
    ajustar $FT/$E
    PCOMP=$(awk -F, 'NR==FNR { if (FNR>1) tr[$2]=1; next } FNR>1 { n++; if ($2 in tr) c++ } END { printf "%.2f", 100*c/n }' $FT/$E/train.csv $FT/$E/test.csv)
    TT=$(tail -n +2 $FT/$E/test.csv | awk -F, '{s+=$NF} END{printf "%.2f", 100*s/NR}')
    IFS=, read -r CB TB SB PB LB AB XB <<< "$(metricas $FT/$E/test_pred_B.csv)"
    [ $E = fila ] && ETQ="Todas las hospitalizaciones; partición por fila" || ETQ="Todas las hospitalizaciones; partición por paciente"
    echo "$ETQ,$(( $(wc -l < $FT/$E/train.csv) - 1 )),$(( $(wc -l < $FT/$E/test.csv) - 1 )),$PCOMP,$TT,$SB,$PB,$LB,$AB"
  done
} > $TAB/fuga_hospitalizaciones.csv
csvlook -I --blanks $TAB/fuga_hospitalizaciones.csv

paso "3.12 Composicion por raza de los pacientes de prueba (¿de donde viene la brecha de seleccion?)"
# Para cada raza: % con 70+, % con al menos un ingreso previo, % con alta a otra institucion
DP=data/part_principal
paste -d, <(csvcut -c race,age,number_inpatient,discharge_disposition_id $DP/test.csv | tail -n +2) <(tail -n +2 $DP/test_pred_B.csv) \
  | sort -t, -k6,6gr | awk -F, -v K=$(( ($(wc -l < $DP/test.csv) - 1) / 5 )) '
  function ic(p, m,   se, lo, hi) { if (m<=0) return "-"; se=sqrt(p*(1-p)/m); lo=100*(p-1.96*se); hi=100*(p+1.96*se)
                                    if (lo<0) lo=0; if (hi>100) hi=100; return sprintf("%.1f-%.1f", lo, hi) }
  BEGIN { print "raza,n,edad_70_o_mas_pct,ingreso_previo_pct,alta_a_institucion_pct,tasa_reingreso_pct,pct_seleccionado,precision_pct,ic95_precision" }
  { g=($1==""?"NA":$1); n[g]++; r[g]+=$5
    if ($2=="[70-80)" || $2=="[80-90)" || $2=="[90-100)") v[g]++
    if ($3>0) p[g]++
    if ($4=="2" || $4=="3" || $4=="4" || $4=="5" || $4=="22") t[g]++
    if (NR<=K) { f[g]++; c[g]+=$5 } }
  END { for (g in n) printf "%s,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%s\n", g, n[g], 100*v[g]/n[g], 100*p[g]/n[g], 100*t[g]/n[g],
                       100*r[g]/n[g], 100*f[g]/n[g], (f[g]>0?100*c[g]/f[g]:0), ic(c[g]/f[g], f[g]) }' \
  | { IFS= read -r h; echo "$h"; sort -t, -k2,2nr; } > $TAB/equidad_composicion.csv
csvlook -I --blanks $TAB/equidad_composicion.csv


# 4. FICHA DE SEGUIMIENTO POST-ALTA 

paso "4. Ficha de seguimiento post-alta"
PACIENTES=$(tail -n +2 data/diab_clean.csv | wc -l)
TASA=$(tail -n +2 data/diab_clean.csv | awk -F, '{s+=$NF} END{printf "%.2f", 100*s/NR}')    # % reingreso <30 dias 
# reingresos capturados con el Modelo B en el 20% superior 
NTEST=$(tail -n +2 data/test_pred.csv | wc -l)
K=$(( NTEST / 5 ))
TOTAL=$(tail -n +2 data/test_pred.csv | awk -F, '{s+=$1} END{print s}')
CAPT_N=$(tail -n +2 data/test_pred.csv | LC_ALL=C sort -t, -k2,2gr | head -n $K | awk -F, '{s+=$1} END{print s}')
echo "capturados: $CAPT_N de $TOTAL (de $K pacientes contactados)"
CAPT=$(awk -v c=$CAPT_N -v t=$TOTAL 'BEGIN{printf "%.2f", 100*c/t}')                       # % de reingresos capturados
LIFT=$(awk -v c=$CAPT_N -v k=$K -v t=$TOTAL -v n=$NTEST 'BEGIN{printf "%.2f", (c/k)/(t/n)}')  # lift = precision / tasa global del test

echo "Comite de Calidad - Ficha de Seguimiento Post-Alta" > report/ficha.txt
echo "Analista: $(whoami)" >> report/ficha.txt
echo "Pacientes analizados: $PACIENTES" >> report/ficha.txt
echo "Reingreso en <30 dias: $TASA%" >> report/ficha.txt
echo "Reingresos capturados contactando al 20%: $CAPT%" >> report/ficha.txt
echo "Lift del modelo: $LIFT" >> report/ficha.txt
cat report/ficha.txt

# 5. FIGURAS Y TABLAS

paso "5.1 Figuras con python3 + matplotlib"
python3 scripts/graficos.py

paso "5.2 Tablas CSV, LaTeX (booktabs)"
for t in limpieza_pasos codigos_especiales excluidos_por_codigo recodificacion faltantes_top5 examenes_no_realizados \
         dist_readmitted descriptivos tasa_edad tasa_inpatient tasa_A1C tasa_change tasa_diabetesMed top10_diag1 \
         resultados_modelos bootstrap_ic comparacion_particiones pesos_A pesos_B_numericas pesos_B_top15 equidad_raza \
         fuga_hospitalizaciones equidad_composicion; do
  python3 scripts/csv2tex.py $TAB/$t.csv $TAB/$t.tex
done
ls $TAB/*.tex | wc -l


# 6. DIAGNOSTICO DE LA PARTICION, ENTORNO Y VALORES

paso "6.1 ¿mezcla bien 'shuf --random-source=<(yes 42)'?"

NCL=$(nf data/diab_clean.csv); NTRC=$(( NCL * 7 / 10 ))
tail -n +2 data/diab_clean.csv | awk '{print NR}' | shuf --random-source=<(yes 42) | awk -v N=$NCL -v ntr=$NTRC '
  NR>ntr { c[int(($1-1)*10/N)]++; t++ } END { for (d=0; d<10; d++) printf "%.2f\n", 100*c[d]/t }' > $INT/dec_yes.txt
tail -n +2 data/diab_clean.csv | awk '{print NR}' | shuf --random-source=<(fuente_aleatoria 42) | awk -v N=$NCL -v ntr=$NTRC '
  NR>ntr { c[int(($1-1)*10/N)]++; t++ } END { for (d=0; d<10; d++) printf "%.2f\n", 100*c[d]/t }' > $INT/dec_principal.txt
tail -n +2 data/diab_clean.csv | awk -F, -v N=$NCL '{ d=int((NR-1)*10/N); n[d]++; r[d]+=$NF } END { for (d=0; d<10; d++) printf "%.2f\n", 100*r[d]/n[d] }' > $INT/dec_tasa.txt
{ echo "decil_encounter_id,pct_test_yes42,pct_test_principal,tasa_reingreso_pct"
  paste -d, <(seq 1 10) $INT/dec_yes.txt $INT/dec_principal.txt $INT/dec_tasa.txt; } > $TAB/diagnostico_particion.csv
csvlook -I --blanks $TAB/diagnostico_particion.csv
python3 scripts/csv2tex.py $TAB/diagnostico_particion.csv $TAB/diagnostico_particion.tex

paso "6.1b ¿Por que el ultimo decil tiene menos reingresos? Composicion por decil"
# (a) tasa <30 sobre todas las hospitalizaciones, por decil de encounter_id
# (b) primera hospitalizacion de cada paciente, por decil: tasa, hospitalizaciones
#     registradas por paciente en todo el periodo, % con alguna otra hospitalizacion registrada, y tasa
#     de reingreso de quienes tienen una sola hospitalizacion y de quienes tienen mas de una
NB=$(nf $INT/pasoB.csv)
tail -n +2 $INT/pasoB.csv | sort -t, -k1,1n | awk -F, -v N=$NB '{ d=int((NR-1)*10/N); n[d]++; r[d]+=($50=="<30") }
  END { for (d=0; d<10; d++) printf "%.2f\n", 100*r[d]/n[d] }' > $INT/dec_todas.txt
awk -F, -v N=$NCL 'NR==FNR { if (FNR>1) h[$2]++; next }
  FNR>1 { d=int((FNR-2)*10/N); n[d]++; s[d]+=h[$2]; m=(h[$2]>1); o[d]+=m; nm[d,m]++; rm[d,m]+=$NF }
  END { for (d=0; d<10; d++) printf "%.2f,%.2f,%.2f,%.2f\n", s[d]/n[d], 100*o[d]/n[d], 100*rm[d,0]/nm[d,0], 100*rm[d,1]/nm[d,1] }' \
  $INT/pasoB.csv data/diab_clean.csv > $INT/dec_comp.txt
{ echo "decil_encounter_id,tasa_todas_hosp_pct,tasa_primera_hosp_pct,hosp_por_paciente,pct_con_otra_hosp,tasa_una_hosp_pct,tasa_varias_hosp_pct"
  paste -d, <(seq 1 10) $INT/dec_todas.txt $INT/dec_tasa.txt $INT/dec_comp.txt; } > $TAB/composicion_decil.csv
csvlook -I --blanks $TAB/composicion_decil.csv
python3 scripts/csv2tex.py $TAB/composicion_decil.csv $TAB/composicion_decil.tex

paso "6.2 Entorno de ejecucion"
{
  echo "fecha: $(date '+%Y-%m-%d %H:%M')"
  echo "sistema: $(uname -sr)"
  echo "bash: ${BASH_VERSION}"
  echo "awk: $(awk -W version 2>&1 | head -n 1)"     
  echo "shuf: $(shuf --version | head -n 1)"
  echo "vw: $(vw --version 2>&1 | head -n 1)"
  echo "csvkit: $(csvstat --version 2>&1 | head -n 1)"
  echo "python3: $(python3 --version 2>&1) / matplotlib $(python3 -c 'import matplotlib; print(matplotlib.__version__)')"
} > $TAB/entorno.txt
cat $TAB/entorno.txt

paso "6.3 Valores para el archivo"
V=report/valores.env
: > $V
kv() { echo "$1=$2" >> $V; }
cell() { awk -F, -v kc="$2" -v kv="$3" -v rc="$4" 'NR==1 { for (i=1;i<=NF;i++) { if ($i==kc) a=i; if ($i==rc) b=i }; next } $a==kv { print $b; exit }' "$1"; }
dist() { awk -F, -v b="$1" -v v="$2" -v c="$3" -v r="$4" '$1==b && $2==v && $3==c { print $r; exit }' $TAB/dist_readmitted.csv; }
peso_b() { awk -F, -v v="$1" -v n="$2" '$1==v && $2==n { print $6; exit }' data/part_principal/pesos_B_todos.csv; }
pct() { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.2f", 100*a/b}'; }

# limpieza
kv N_RAW        $(cell $TAB/limpieza_pasos.csv paso 0 filas_despues)
kv N_PAC_RAW    $(cell $TAB/limpieza_pasos.csv paso 0 pacientes_unicos)
kv COLS_RAW     $(cell $TAB/limpieza_pasos.csv paso 0 columnas)
kv N_EXCL       $(cell $TAB/excluidos_por_codigo.csv codigo TOTAL filas_excluidas)
kv N_POST_EXCL  $(cell $TAB/limpieza_pasos.csv paso B filas_despues)
kv N_PAC_POST_EXCL $(cell $TAB/limpieza_pasos.csv paso B pacientes_unicos)
kv N_CLEAN      $(cell $TAB/limpieza_pasos.csv paso C filas_despues)
kv N_DUP        $(( $(cell $TAB/limpieza_pasos.csv paso B filas_despues) - $(cell $TAB/limpieza_pasos.csv paso C filas_despues) ))
kv N_PAC_PERDIDOS $(( $(cell $TAB/limpieza_pasos.csv paso 0 pacientes_unicos) - $(cell $TAB/limpieza_pasos.csv paso B pacientes_unicos) ))
kv COLS_FINAL   $(cell $TAB/limpieza_pasos.csv paso D columnas)
kv N_PRIMER_EXCL       $(awk 'NR==1 {print $NF}' $TAB/sensibilidad_orden.txt)
kv N_PRIMER_EXCL_MULTI $(awk 'NR==2 {print $NF}' $TAB/sensibilidad_orden.txt)
kv R_Q      $(awk -F, 'NR==2 {print $NF}' $TAB/recodificacion.csv)
kv R_TIPO   $(awk -F, 'NR==3 {print $NF}' $TAB/recodificacion.csv)
kv R_ALTA   $(awk -F, 'NR==4 {print $NF}' $TAB/recodificacion.csv)
kv R_FUENTE $(awk -F, 'NR==5 {print $NF}' $TAB/recodificacion.csv)
kv R_GEN    $(awk -F, 'NR==6 {print $NF}' $TAB/recodificacion.csv)
for c in weight medical_specialty payer_code race diag_3 diag_2 diag_1; do
  kv PCT_RAW_$c $(cell $TAB/faltantes_raw.csv columna $c pct_signo_pregunta)
done
kv N_A1C_NONE_RAW $(cell $TAB/faltantes_raw.csv columna A1Cresult None)
kv N_GLU_NONE_RAW $(cell $TAB/faltantes_raw.csv columna max_glu_serum None)
kv PCT_A1C_NONE_RAW $(pct $(cell $TAB/faltantes_raw.csv columna A1Cresult None) $(cell $TAB/limpieza_pasos.csv paso 0 filas_despues))
kv PCT_GLU_NONE_RAW $(pct $(cell $TAB/faltantes_raw.csv columna max_glu_serum None) $(cell $TAB/limpieza_pasos.csv paso 0 filas_despues))
# exploracion
kv RAW_LT30  $(dist original readmitted '<30' 5);  kv RAW_GT30  $(dist original readmitted '>30' 5);  kv RAW_NO  $(dist original readmitted NO 5)
kv RAW_N_LT30 $(dist original readmitted '<30' 4)
kv CL_LT30   $(dist limpia readmitted '<30' 5);    kv CL_GT30   $(dist limpia readmitted '>30' 5);    kv CL_NO   $(dist limpia readmitted NO 5)
kv TASA_GLOBAL $(dist limpia Reingreso30 1 5);     kv N_REING $(dist limpia Reingreso30 1 4);         kv PCT_NO_REING $(dist limpia Reingreso30 0 5)
for c in weight medical_specialty payer_code admission_type_id admission_source_id; do kv PCT_MISS_$c $(cell $TAB/faltantes_top5.csv columna $c pct_faltante); done
kv PCT_A1C_NOTEST $(cell $TAB/examenes_no_realizados.csv columna A1Cresult pct_examen_no_realizado)
kv PCT_GLU_NOTEST $(cell $TAB/examenes_no_realizados.csv columna max_glu_serum pct_examen_no_realizado)
for v in time_in_hospital num_lab_procedures num_medications number_diagnoses; do
  kv M_$v   $(cell $TAB/descriptivos.csv variable $v media)
  kv SD_$v  $(cell $TAB/descriptivos.csv variable $v desv_est)
  kv MED_$v $(cell $TAB/descriptivos.csv variable $v mediana)
  kv Q1_$v  $(cell $TAB/descriptivos.csv variable $v Q1)
  kv Q3_$v  $(cell $TAB/descriptivos.csv variable $v Q3)
  kv MAX_$v $(cell $TAB/descriptivos.csv variable $v max)
done
for g in '[0-10)' '[10-20)' '[20-30)' '[30-40)' '[40-50)' '[50-60)' '[60-70)' '[70-80)' '[80-90)' '[90-100)'; do
  k=$(echo "$g" | tr -d '[)' | tr '-' '_'); kv EDAD_$k $(cell $TAB/tasa_edad.csv grupo_edad "$g" tasa_pct); kv EDADN_$k $(cell $TAB/tasa_edad.csv grupo_edad "$g" n)
done
kv PCT_MULTI $(awk -v a=$(awk 'NR==2 {print $NF}' $TAB/sensibilidad_orden.txt) -v b=$(nf data/diab_clean.csv) 'BEGIN{printf "%.2f", 100*a/b}')
for g in 0 1 2 3 4+; do k=${g%+}; kv INP_$k $(cell $TAB/tasa_inpatient.csv ingresos_previos $g tasa_pct); kv INPN_$k $(cell $TAB/tasa_inpatient.csv ingresos_previos $g n); done
kv INP_RATIO $(awk -v a=$(cell $TAB/tasa_inpatient.csv ingresos_previos 4+ tasa_pct) -v b=$(cell $TAB/tasa_inpatient.csv ingresos_previos 0 tasa_pct) 'BEGIN{printf "%.1f", a/b}')
NPREV=$(awk -F, 'NR>1 && $1!="0" {s+=$2} END{print s}' $TAB/tasa_inpatient.csv)
RPREV=$(awk -F, 'NR>1 && $1!="0" {s+=$3} END{print s}' $TAB/tasa_inpatient.csv)
kv PCT_PAC_PREV  $(pct $NPREV $(nf data/diab_clean.csv))
kv PCT_REING_PREV $(pct $RPREV $(dist limpia Reingreso30 1 4))
for g in '>7' '>8' None Norm; do k=$(echo "$g" | tr -d '>'); kv A1C_$k $(cell $TAB/tasa_A1C.csv A1Cresult "$g" tasa_pct); done
kv CH_Ch $(cell $TAB/tasa_change.csv change Ch tasa_pct); kv CH_No $(cell $TAB/tasa_change.csv change No tasa_pct)
kv DM_Yes $(cell $TAB/tasa_diabetesMed.csv diabetesMed Yes tasa_pct); kv DM_No $(cell $TAB/tasa_diabetesMed.csv diabetesMed No tasa_pct)
for d in 414 428 786 410 486 427 715 434 682 780; do kv DX_$d $(cell $TAB/top10_diag1.csv diag_1 $d tasa_pct); kv DXN_$d $(cell $TAB/top10_diag1.csv diag_1 $d n); done
# modelacion (particion principal y del enunciado)
sed 's/^/P_/' $TAB/valores_modelo.env >> $V
sed 's/^/ALT_/' $TAB/alt_enunciado/valores_modelo.env >> $V
kv NOCAPT_B $(awk -v s=$(grep '^SENS_B=' $TAB/valores_modelo.env | cut -d= -f2) 'BEGIN{printf "%.2f", 100-s}')
for m in sensibilidad_A sensibilidad_B lift_A lift_B dif_sensibilidad_B_menos_A dif_lift_B_menos_A; do
  kv BS_${m}_LO  $(cell $TAB/bootstrap_ic.csv metrica $m ic95_inf)
  kv BS_${m}_MED $(cell $TAB/bootstrap_ic.csv metrica $m mediana)
  kv BS_${m}_HI  $(cell $TAB/bootstrap_ic.csv metrica $m ic95_sup)
done
kv DEC10_YES $(awk -F, 'NR==11 {print $2}' $TAB/diagnostico_particion.csv)
kv DEC10_PRINCIPAL $(awk -F, 'NR==11 {print $3}' $TAB/diagnostico_particion.csv)
kv DEC1_TASA  $(awk -F, 'NR==2  {print $4}' $TAB/diagnostico_particion.csv)
kv DEC10_TASA $(awk -F, 'NR==11 {print $4}' $TAB/diagnostico_particion.csv)
for v in number_inpatient time_in_hospital number_diagnoses; do kv WA_$v $(cell $TAB/pesos_A.csv variable $v peso_por_DE); kv WB_$v $(cell $TAB/pesos_B_numericas.csv variable $v peso_por_DE); done
kv W_DC22 $(peso_b discharge_disposition_id 22); kv W_DC5 $(peso_b discharge_disposition_id 5)
kv W_DC2  $(peso_b discharge_disposition_id 2);  kv W_DC3 $(peso_b discharge_disposition_id 3)
kv W_AGE1020 $(peso_b age '[10-20)');            kv W_DMNO $(peso_b diabetesMed No)
kv W_INSDOWN $(peso_b insulin Down)
kv W_AS5 $(peso_b admission_source_id 5)
# rangos  tasa entre 20 y 59, y tasa cuando la HbA1c si se midio (>7, >8, Norm)
kv EDAD_2059_MIN $(awk -F, '$1=="[20-30)"||$1=="[30-40)"||$1=="[40-50)"||$1=="[50-60)" {print $4}' $TAB/tasa_edad.csv | sort -g | head -n 1)
kv EDAD_2059_MAX $(awk -F, '$1=="[20-30)"||$1=="[30-40)"||$1=="[40-50)"||$1=="[50-60)" {print $4}' $TAB/tasa_edad.csv | sort -g | tail -n 1)
kv A1C_MED_MIN $(awk -F, 'NR>1 && $1!="None" && $1!="NA" {print $4}' $TAB/tasa_A1C.csv | sort -g | head -n 1)
kv A1C_MED_MAX $(awk -F, 'NR>1 && $1!="None" && $1!="NA" {print $4}' $TAB/tasa_A1C.csv | sort -g | tail -n 1)
kv REPO_URL $REPO_URL; kv REPO_DIR ${REPO_URL##*/}
# estadia media segun destino al alta: domicilio (1) frente a otra institucion (2, 3, 4, 5, 22)
TIH=$(colidx data/diab_clean.csv time_in_hospital); DDC=$(colidx data/diab_clean.csv discharge_disposition_id)
kv TIH_CASA $(tail -n +2 data/diab_clean.csv | awk -F, -v t=$TIH -v d=$DDC '$d=="1" {s+=$t; n++} END{printf "%.2f", s/n}')
kv TIH_INST $(tail -n +2 data/diab_clean.csv | awk -F, -v t=$TIH -v d=$DDC '$d=="2"||$d=="3"||$d=="4"||$d=="5"||$d=="22" {s+=$t; n++} END{printf "%.2f", s/n}')
for r in Caucasian AfricanAmerican; do
  kv EQ_N_$r    $(cell $TAB/equidad_raza.csv raza $r n)
  kv EQ_TASA_$r $(cell $TAB/equidad_raza.csv raza $r tasa_reingreso_pct)
  kv EQ_SEL_$r  $(cell $TAB/equidad_raza.csv raza $r pct_seleccionado)
  kv EQ_SELIC_$r $(cell $TAB/equidad_raza.csv raza $r ic95_seleccionado)
  kv EQ_SENS_$r $(cell $TAB/equidad_raza.csv raza $r sensibilidad_pct)
  kv EQ_SENSIC_$r $(cell $TAB/equidad_raza.csv raza $r ic95_sensibilidad)
done
# resultado  sobre las brechas por raza: intervalos 'lo-hi' disjuntos (clara) o solapados (no concluyente)
veredicto() { awk -v a="$1" -v b="$2" 'BEGIN { split(a,x,"-"); split(b,y,"-"); if (x[2]+0 < y[1]+0 || y[2]+0 < x[1]+0) print "estadísticamente clara, con intervalos disjuntos"; else print "no concluyente, con intervalos que se solapan" }'; }
kv EQ_SEL_VEREDICTO "$(veredicto $(cell $TAB/equidad_raza.csv raza Caucasian ic95_seleccionado) $(cell $TAB/equidad_raza.csv raza AfricanAmerican ic95_seleccionado))"
kv EQ_SENS_VEREDICTO "$(veredicto $(cell $TAB/equidad_raza.csv raza Caucasian ic95_sensibilidad) $(cell $TAB/equidad_raza.csv raza AfricanAmerican ic95_sensibilidad))"
# ficha
kv FICHA_PACIENTES $PACIENTES; kv FICHA_TASA $TASA; kv FICHA_CAPT $CAPT; kv FICHA_LIFT $LIFT
kv K_FICHA $K
# exclusion: fallecimiento vs hospicio y su efecto en la tasa
EX=$TAB/excluidos_por_codigo.csv
kv N_EXCL_FALL      $(awk -F, '$3=="fallecimiento" {s+=$4} END{print s+0}' $EX)
kv N_EXCL_FALL_LT30 $(awk -F, '$3=="fallecimiento" {s+=$5} END{print s+0}' $EX)
kv N_EXCL_HOSP      $(awk -F, '$3=="hospicio" {s+=$4} END{print s+0}' $EX)
kv N_EXCL_HOSP_LT30 $(awk -F, '$3=="hospicio" {s+=$5} END{print s+0}' $EX)
kv PCT_EXCL_HOSP_LT30 $(awk -F, '$3=="hospicio" {s+=$4; r+=$5} END{printf "%.2f", 100*r/s}' $EX)
kv TASA_POST_EXCL $TASA_POST_EXCL
# diabetes (250.xx) agrupada
kv DX250_N $(echo $DX250 | cut -d, -f1); kv DX250_TASA $(echo $DX250 | cut -d, -f2); kv DX250_POS $(echo $DX250 | cut -d, -f3)
kv DX250_NCOD $NCOD250
# composicion por decil
CD=$TAB/composicion_decil.csv
kv DECT_MIN $(tail -n +2 $CD | cut -d, -f2 | sort -g | head -n 1); kv DECT_MAX $(tail -n +2 $CD | cut -d, -f2 | sort -g | tail -n 1)
kv HPP_1 $(awk -F, 'NR==2 {print $4}' $CD);  kv HPP_10 $(awk -F, 'NR==11 {print $4}' $CD)
kv OTRA_10 $(awk -F, 'NR==11 {print $5}' $CD)
kv OTRA_MIN19 $(awk -F, 'NR>=2 && NR<=10 {print $5}' $CD | sort -g | head -n 1); kv OTRA_MAX19 $(awk -F, 'NR>=2 && NR<=10 {print $5}' $CD | sort -g | tail -n 1)
kv UNA_MAX $(tail -n +2 $CD | cut -d, -f6 | sort -g | tail -n 1); kv UNA_MIN $(tail -n +2 $CD | cut -d, -f6 | sort -g | head -n 1)
kv VARIAS_MIN $(tail -n +2 $CD | cut -d, -f7 | sort -g | head -n 1); kv VARIAS_MAX $(tail -n +2 $CD | cut -d, -f7 | sort -g | tail -n 1)
# experimento de fuga (fila 3 = por fila, fila 4 = por paciente)
FG=$TAB/fuga_hospitalizaciones.csv
for spec in FILA:3 PAC:4; do
  e=${spec%%:*}; r=${spec##*:}
  kv FUGA_${e}_NTRAIN $(awk -F, -v r=$r 'NR==r {print $2}' $FG); kv FUGA_${e}_NTEST $(awk -F, -v r=$r 'NR==r {print $3}' $FG)
  kv FUGA_${e}_PCOMP  $(awk -F, -v r=$r 'NR==r {print $4}' $FG); kv FUGA_${e}_TASA  $(awk -F, -v r=$r 'NR==r {print $5}' $FG)
  kv FUGA_${e}_SENS   $(awk -F, -v r=$r 'NR==r {print $6}' $FG); kv FUGA_${e}_LIFT  $(awk -F, -v r=$r 'NR==r {print $8}' $FG)
  kv FUGA_${e}_AUC    $(awk -F, -v r=$r 'NR==r {print $9}' $FG); kv FUGA_${e}_PREC  $(awk -F, -v r=$r 'NR==r {print $7}' $FG)
done
kv N_TODAS $NTODAS
kv FUGA_DIF_SENS $(awk -F, 'NR==3 {a=$6} NR==4 {b=$6} END{printf "%.2f", a-b}' $FG)
kv FUGA_DIF_AUC  $(awk -F, 'NR==3 {a=$9} NR==4 {b=$9} END{printf "%.3f", a-b}' $FG)
# composicion por raza
EC=$TAB/equidad_composicion.csv
for r in Caucasian AfricanAmerican; do
  kv EQC_V70_$r  $(cell $EC raza $r edad_70_o_mas_pct);  kv EQC_PREV_$r $(cell $EC raza $r ingreso_previo_pct)
  kv EQC_INST_$r $(cell $EC raza $r alta_a_institucion_pct)
  kv EQC_PREC_$r $(cell $EC raza $r precision_pct);       kv EQC_PRECIC_$r $(cell $EC raza $r ic95_precision)
done
kv EQ_PREC_VEREDICTO "$(veredicto $(cell $EC raza Caucasian ic95_precision) $(cell $EC raza AfricanAmerican ic95_precision))"
wc -l < $V

paso "6.4 verificion"

val() { grep -m1 "^$1=" $V | cut -d= -f2-; }
lo()  { val "$1" | cut -d- -f1; }      # limite inferior de un intervalo "a-b"
hi()  { val "$1" | cut -d- -f2; }
VT=$TAB/verificacion_texto.csv
echo "afirmacion,cumple" > $VT
chk() { local d=${1//,/;}
        if awk "BEGIN { exit !($2) }"; then echo "$d,SI" >> $VT; else echo "$d,NO" >> $VT; echo "AVISO: no se cumple: $d"; fi; }
chk "excluir fallecidos/hospicio sube la tasa por hospitalización"     "$(val TASA_POST_EXCL) > $(val RAW_LT30)"
chk "dejar un registro por paciente baja la tasa"                      "$(val TASA_GLOBAL) < $(val TASA_POST_EXCL)"
chk "ningún fallecido tiene reingreso <30"                             "$(val N_EXCL_FALL_LT30) == 0"
chk "algunos pacientes en hospicio sí reingresan <30"                  "$(val N_EXCL_HOSP_LT30) > 0"
chk "time_in_hospital: media > mediana"                                "$(val M_time_in_hospital) > $(val MED_time_in_hospital)"
chk "num_medications: media > mediana"                                 "$(val M_num_medications) > $(val MED_num_medications)"
chk "num_lab_procedures: media < mediana"                              "$(val M_num_lab_procedures) < $(val MED_num_lab_procedures)"
chk "number_diagnoses: media < mediana"                                "$(val M_number_diagnoses) < $(val MED_number_diagnoses)"
chk "tasa crece con ingresos previos (0<1<2<3<4+)"                     "$(val INP_0) < $(val INP_1) && $(val INP_1) < $(val INP_2) && $(val INP_2) < $(val INP_3) && $(val INP_3) < $(val INP_4)"
chk "tasa a 60-69, 70-79 y 80-89 años mayor que el máximo de 20-59"   "$(val EDAD_60_70) > $(val EDAD_2059_MAX) && $(val EDAD_70_80) > $(val EDAD_2059_MAX) && $(val EDAD_80_90) > $(val EDAD_2059_MAX)"
chk "manejo de la diabetes: diferencias menores a 2 puntos"            "$(val DM_Yes) - $(val DM_No) < 2 && $(val CH_Ch) - $(val CH_No) < 2 && $(val A1C_None) - $(val A1C_MED_MIN) < 2"
chk "diabetes agrupada (250) queda en el primer lugar"                 "$(val DX250_POS) == 1"
chk "tasa sobre todas las hospitalizaciones estable (rango < 2 puntos)" "$(val DECT_MAX) - $(val DECT_MIN) < 2"
chk "decil 10 con menos hospitalizaciones por paciente que el 1"       "$(val HPP_10) < $(val HPP_1)"
chk "decil 10 con el menor % de pacientes con otra hospitalización"    "$(val OTRA_10) < $(val OTRA_MIN19)"
chk "con varias hospitalizaciones la tasa es siempre mayor que con una" "$(val VARIAS_MIN) > $(val UNA_MAX)"
chk "B supera a A en sensibilidad (IC de la diferencia sobre cero)"    "$(val BS_dif_sensibilidad_B_menos_A_LO) > 0"
chk "pesos numéricos B: inpatient > diagnoses > time_in_hospital > 0"  "$(val WB_number_inpatient) > $(val WB_number_diagnoses) && $(val WB_number_diagnoses) > $(val WB_time_in_hospital) && $(val WB_time_in_hospital) > 0"
chk "peso de time_in_hospital menor en B que en A"                     "$(val WB_time_in_hospital) < $(val WA_time_in_hospital)"
chk "estadía media mayor con alta a institución que a domicilio"      "$(val TIH_INST) > $(val TIH_CASA)"
chk "ingreso desde SNF (admission_source_id 5) con peso negativo"      "$(val W_AS5) < 0"
chk "altas 22, 5, 2 y 3 con peso positivo"                           "$(val W_DC22) > 0 && $(val W_DC5) > 0 && $(val W_DC2) > 0 && $(val W_DC3) > 0"
chk "edad 10-19 y sin medicación con peso negativo; insulina Down positivo" "$(val W_AGE1020) < 0 && $(val W_DMNO) < 0 && $(val W_INSDOWN) > 0"
chk "partición por fila: pacientes de test también en train"           "$(val FUGA_FILA_PCOMP) > 0"
chk "fuga por fila con efecto pequeño (|dif AUC| < 0.02 y |dif sens| < 2)" "$(val FUGA_DIF_AUC) < 0.02 && $(val FUGA_DIF_AUC) > -0.02 && $(val FUGA_DIF_SENS) < 2 && $(val FUGA_DIF_SENS) > -2"
chk "con todas las hospitalizaciones la tasa de prueba es mayor"       "$(val FUGA_PAC_TASA) > $(val P_TASA_TEST) && $(val FUGA_FILA_TASA) > $(val P_TASA_TEST)"
chk "con todas las hospitalizaciones la precisión del 20% es mayor"    "$(val FUGA_PAC_PREC) > $(val P_PREC_B)"
chk "afroamericanos: menor proporción seleccionada"                    "$(val EQ_SEL_AfricanAmerican) < $(val EQ_SEL_Caucasian)"
chk "afroamericanos: menor sensibilidad puntual"                       "$(val EQ_SENS_AfricanAmerican) < $(val EQ_SENS_Caucasian)"
chk "afroamericanos: menos 70+, menos ingresos previos y menos altas a institución" "$(val EQC_V70_AfricanAmerican) < $(val EQC_V70_Caucasian) && $(val EQC_PREV_AfricanAmerican) < $(val EQC_PREV_Caucasian) && $(val EQC_INST_AfricanAmerican) < $(val EQC_INST_Caucasian)"
chk "precisión por raza con intervalos solapados"                      "!($(hi EQC_PRECIC_AfricanAmerican) < $(lo EQC_PRECIC_Caucasian) || $(hi EQC_PRECIC_Caucasian) < $(lo EQC_PRECIC_AfricanAmerican))"
csvlook -I --blanks $VT
kv VERIF_N  $(( $(wc -l < $VT) - 1 ))
kv VERIF_OK $(grep -c ',SI$' $VT || true)
# ningun valor puede quedar vacio (una busqueda que no encontro nada) ni repetido: el reporte tendria huecos
VACIAS=$(awk -F= '$2=="" {print $1}' $V | tr '\n' ' ')
DUPS=$(cut -d= -f1 $V | sort | uniq -d | tr '\n' ' ')
test -z "$VACIAS$DUPS" || { echo "ERROR: valores vacios: [$VACIAS] repetidos: [$DUPS]"; exit 1; }
echo "OK: $(wc -l < $V) valores, ninguno vacio ni repetido"

# 7. hacer el pdf resultados  

paso "7.1 Tablas en markdown (csvlook)"
for f in $TAB/*.csv; do csvlook -I --blanks "$f" > "${f%.csv}.md"; done

paso "7.1b Todas las tablas en dos archivos: report/tablas.md y report/tablas.csv"

ORDEN="limpieza_pasos codigos_especiales recodificacion excluidos_por_codigo faltantes_raw faltantes_limpio_todas
  faltantes_top5 examenes_no_realizados dist_readmitted descriptivos tasa_edad tasa_inpatient tasa_A1C tasa_change
  tasa_diabetesMed top10_diag1 resultados_modelos aleatorio_simulacion curva_ganancia bootstrap_ic comparacion_particiones
  diagnostico_particion composicion_decil pesos_A pesos_B_numericas pesos_B_top15 fuga_hospitalizaciones
  equidad_raza equidad_composicion verificacion_texto"
LISTA=$( { for t in $ORDEN; do echo $t; done
           ls $TAB/*.csv | xargs -n 1 basename | sed 's/\.csv$//' | sort | grep -v -x -F -f <(for t in $ORDEN; do echo $t; done)
           ls $TAB/alt_enunciado/*.csv | xargs -n 1 basename | sed 's/\.csv$//; s#^#alt_enunciado/#'; } )

! grep -l '"' $TAB/*.csv $TAB/alt_enunciado/*.csv || { echo "ERROR: hay comillas en alguna tabla"; exit 1; }
{
  echo "# Tablas del análisis"
  echo
  echo "Generadas por \`bash scripts/pipeline.sh\` (no se editan a mano). Las mismas cifras están en formato largo en \`report/tablas.csv\` (columnas \`tabla,fila,columna,valor\`). Las tablas \`alt_enunciado/*\` repiten la modelación con la partición del enunciado (\`shuf --random-source=<(yes 42)\`)."
  echo
  echo "## Salidas de inspección"
  for t in 01_inspeccion sensibilidad_orden entorno; do echo; echo "### $t"; echo; echo '```text'; cat $TAB/$t.txt; echo '```'; done
  echo
  echo "## Tablas"
  for t in $LISTA; do echo; echo "### $t"; echo; csvlook -I --blanks $TAB/$t.csv; done
} > report/tablas.md
{
  echo "tabla,fila,columna,valor"
  for t in $LISTA; do
    awk -F, -v OFS=, -v t="$t" 'NR==1 { for (i=1;i<=NF;i++) h[i]=$i; next } { for (i=1;i<=NF;i++) print t, NR-1, h[i], $i }' $TAB/$t.csv
  done
} > report/tablas.csv
echo "report/tablas.md: $(echo $LISTA | wc -w) tablas | report/tablas.csv: $(( $(wc -l < report/tablas.csv) - 1 )) valores"

render() {
  awk -v modo="$3" '
    function grupo(s,   o, l, i) { l=length(s); o=""; for (i=1;i<=l;i++) { o = o substr(s,i,1); if ((l-i)%3==0 && i<l) o = o sep }; return o }
    BEGIN { sep = (modo=="tex") ? "\\," : "\302\240" }
    NR==FNR { v[substr($0,1,index($0,"=")-1)] = substr($0,index($0,"=")+1); next }
    /^\{\{INCLUIR:[^}]+\}\}$/ { f=substr($0,11,length($0)-12); while ((getline linea < f) > 0) print linea; close(f); next }
    { line=$0; out=""
      while (match(line, /\{\{[A-Za-z0-9_]+\}\}/)) {
        key=substr(line,RSTART+2,RLENGTH-4)
        if (!(key in v)) { print "CLAVE FALTANTE: " key > "/dev/stderr"; falta=1; rep="??" }
        else { rep=v[key]; if (rep ~ /^[0-9]+$/ && length(rep)>=4) rep=grupo(rep)
               if (modo=="tex" && rep ~ /^-[0-9.]+$/) rep="$-$" substr(rep,2) }   # signo menos tipografico
        out = out substr(line,1,RSTART-1) rep; line = substr(line,RSTART+RLENGTH) }
      print out line }
    END { exit falta }
  ' report/valores.env "$1" > "$2"
}
paso "7.2 report/reporte.md"
render report/reporte.md.tpl report/reporte.md md
echo "reporte.md: $(wc -l < report/reporte.md) lineas"
paso "7.3 report/informe.tex"
render report/informe.tex.tpl report/informe.tex tex
echo "informe.tex: $(wc -l < report/informe.tex) lineas"

# pdf compila en latex
if command -v latexmk >/dev/null 2>&1; then
  paso "7.4 Compilando report/informe.pdf"
  (cd report && latexmk -xelatex -interaction=nonstopmode -halt-on-error informe.tex > /dev/null && echo "informe.pdf generado") \
    || echo "(no se pudo compilar el PDF; revise report/informe.log)"
else
  echo "(latexmk no disponible: compile report/informe.tex con xelatex; ver README.md)"
fi
echo; echo "Pipeline terminado."
