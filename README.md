# Evaluación N°1 (Dataset: Diabetes)


## Entregables

| Archivo | Contenido |
|---|---|
| `scripts/pipeline.sh` | Pipeline completo (obtención → limpieza → exploración → modelación  → informes) |
| `scripts/graficos.py`, `scripts/csv2tex.py` | Figuras (matplotlib) y conversión de tablas CSV a LaTeX |
| `report/reporte.md` | Reporte: fuente, limpieza, hallazgos, resultados de los modelos, interpretación  |
| `report/informe.pdf` / `report/informe.tex` | Informe  portada, índices, metodología, resultados, discusión y el código fuente |
| `report/ficha.txt` | Ficha de seguimiento post-alta (valores calculados)|
| `report/figuras/` | Figuras generadas |
| `report/*.tpl` | Plantillas  del informe |

## Cómo reproducirlo

Todas las rutas son relativas a la raíz del repositorio (`./data`, `./scripts`, `./report`).

```bash
git clone https://github.com/trini-tini/evaluacion1-diabetes && cd evaluacion1-diabetes
```

**Dentro del contenedor `datasciencetoolbox/dsatcl2e`** (desde la raíz del repositorio, en Linux/WSL). Es el comando con que se validó el pipeline:

```bash
chmod -R a+rwx .                    
docker run --rm --entrypoint bash -v "$PWD":/data/eval1 -w /data/eval1 \
  datasciencetoolbox/dsatcl2e scripts/pipeline.sh
```

En una terminal Linux con `bash`, `curl`, `unzip`, `awk`, `sed`, `sort`, `shuf`, `csvkit`, `vw` (Vowpal Wabbit) y `python3` con `matplotlib`:

```bash
bash scripts/pipeline.sh
```

El pipeline descarga los datos desde UCI se cribe las salidas en `data/` y `report/`. Si hay `latexmk` compila además `report/informe.pdf`; si no (por ejemplo, en el contenedor), `report/informe.tex` es autocontenido y se compila con **xelatex** junto a `report/figuras/`:

```bash
cd report && latexmk -xelatex informe.tex     
```

El informe usa los paquetes LaTeX `fontspec`, `babel`, `geometry`, `booktabs`, `graphicx`, `float`, `adjustbox`, `caption`, `xcolor`, `enumitem`, `listings`, `fancyhdr`, `setspace`, `hyperref`, `amsmath` y `underscore`.

## Decisioness

* **Limpieza.** Se normalizan los terminadores CRLF; `IDS_mapping.csv` se separa en tres tablas; los códigos `NULL / Not Available / Not Mapped / Unknown/Invalid` y el marcador `?` pasan a faltantes; `None` en `A1Cresult` y `max_glu_serum` es *examen no realizado* (no faltante); se excluyen altas por fallecimiento u hospicio; se deja un registro por paciente (menor `encounter_id`); se eliminan columnas constantes; `Reingreso30 = (readmitted == "<30")`.
* **Modelos.** Regresión logística con Vowpal Wabbit (Modelo A: 8 numéricas; Modelo B: A + 9 categóricas). Evaluación en el 20 % de mayor riesgo: sensibilidad, precisión y lif, con IC bootstrap y simulación de la selección aleatoria.
* **Partición 70/30.** `shuf --random-source=<(yes 42)` : el test queda concentrado en el final del archivo ordenado por `encounter_id`, donde la tasa de reingreso es menor. La partición principal usa el mismo comando con una fuente pseudoaleatoria sembrada con 42 (Mersenne Twister de `python3`)

* **Validado en dos entornos.** `dsatcl2e` (vw 8.11, mawk) y Ubuntu 24.04 (vw 8.6.1, gawk) 

## Estructura

```
scripts/   pipeline.sh  graficos.py  csv2tex.py
report/    reporte.md  informe.tex  informe.pdf  ficha.txt  *.tpl  figuras/
data/      datos, particiones y tablas intermedias (se generan; no se versionan)
           (tambien se generan report/valores.env, report/tablas.md y report/tablas.csv, que no se versionan)
```
