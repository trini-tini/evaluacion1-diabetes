Reingresos de pacientes diabéticos en 130 hospitales de EE. UU

> **Cómo leer este reporte.** Todas las cifras y tablas se generan al ejecutar `bash scripts/pipeline.sh` (ver sección 8); este archivo se produce desde `report/reporte.md.tpl` y los valores que calcula el pipeline (`report/valores.env`, que se genera al ejecutarlo), por lo que no hay números escritos a mano. El informe técnico detallado está en `report/informe.pdf`.

## 1. Fuente y cita

Clore, J., Cios, K., DeShazo, J., & Strack, B. (2014). *Diabetes 130-US Hospitals for Years 1999-2008* [Conjunto de datos]. UCI Machine Learning Repository. <https://doi.org/10.24432/C5230J>

Estudio que describe el conjunto de datos: Strack, B., DeShazo, J. P., Gennings, C., Olmo, J. L., Ventura, S., Cios, K. J., & Clore, J. N. (2014). Impact of HbA1c measurement on hospital readmission rates: Analysis of 70,000 clinical database patient records. *BioMed Research International*, 2014, 781670. <https://doi.org/10.1155/2014/781670>

El archivo `diabetic_data.csv` contiene {{N_RAW}} hospitalizaciones de {{N_PAC_RAW}} pacientes con diagnóstico de diabetes en 130 hospitales de EE. UU. (1999–2008), con {{COLS_RAW}} columnas. La respuesta `readmitted` toma los valores `<30`, `>30` y `NO`.

**Datos sensibles.** Incluyen edad, sexo y raza. Por eso (i) el repositorio **no** contiene los datos: el pipeline los descarga desde UCI; (ii) la raza **no** se usa como predictor; y (iii) se audita el desempeño del modelo por grupo racial (sección 5).

## 2. Resumen de la limpieza

{{INCLUIR:data/tablas/limpieza_pasos.md}}

* **Terminadores de línea (CRLF).** `cat -A` muestra `^M$` al final de las líneas de `diabetic_data.csv` y de `IDS_mapping.csv`. Se normalizó con `tr -d '\r'`; si no, el último campo valdría `NO^M` o `<30^M` y cualquier comparación `readmitted=="<30"` fallaría sin avisar.
* **Diccionario `IDS_mapping.csv`.** Reúne tres tablas separadas por líneas `,`; se separó con `awk` en `data/mapa_admission_type_id.csv` (8 códigos), `data/mapa_discharge_disposition_id.csv` (30) y `data/mapa_admission_source_id.csv` (25). Algunas descripciones llevan comillas, comas internas o espacios sobrantes.
* **Faltantes.** El dato faltante se codifica como `?` (no hay celdas vacías en el original). Porcentaje de `?` en el archivo original: `weight` {{PCT_RAW_weight}}%, `medical_specialty` {{PCT_RAW_medical_specialty}}%, `payer_code` {{PCT_RAW_payer_code}}%, `race` {{PCT_RAW_race}}%, `diag_3` {{PCT_RAW_diag_3}}%, `diag_2` {{PCT_RAW_diag_2}}%, `diag_1` {{PCT_RAW_diag_1}}%. Se recodificaron {{R_Q}} celdas `?` como vacías.
* **`None` en los exámenes no es un dato faltante.** En `A1Cresult` (`>7`, `>8`, `Norm`, `None`) y `max_glu_serum` (`>200`, `>300`, `Norm`, `None`), `None` significa **examen no realizado** ({{N_A1C_NONE_RAW}} y {{N_GLU_NONE_RAW}} hospitalizaciones; {{PCT_A1C_NONE_RAW}}% y {{PCT_GLU_NONE_RAW}}%). Es información clínica (el examen no se solicitó), por lo que se conserva como categoría y no se imputa. En las columnas de medicamentos, `No` significa «no prescrito».
* **Códigos del diccionario que en realidad son información ausente** (`NULL`, `Not Available`, `Not Mapped`, `Unknown/Invalid`), recodificados como vacío: {{R_TIPO}} celdas de `admission_type_id`, {{R_ALTA}} de `discharge_disposition_id` y {{R_FUENTE}} de `admission_source_id`.

{{INCLUIR:data/tablas/codigos_especiales.md}}

* **Categorías inválidas y columnas constantes.** `gender` tiene el valor inválido `Unknown/Invalid` en {{R_GEN}} filas (pasa a vacío). Se eliminaron tres columnas constantes: `examide` y `citoglipton` (constantes en el original) y `glimepiride-pioglitazone` (constante una vez filtradas las filas); no aportan información.
* **Exclusión de fallecidos y cuidados paliativos.** Se excluyeron {{N_EXCL}} hospitalizaciones con alta por fallecimiento u hospicio (códigos 11, 13, 14, 19, 20 y 21, identificados en el diccionario por las descripciones `Expired` y `Hospice`). **Justificación, distinta para cada grupo:**
  * *Fallecimiento* (códigos 11, 19, 20 y 21; {{N_EXCL_FALL}} hospitalizaciones): el paciente **no puede reingresar**, y los datos lo confirman: {{N_EXCL_FALL_LT30}} tienen `readmitted = <30`. Dejarlos como «no reingreso» confundiría mortalidad con buena evolución.
  * *Hospicio* (códigos 13 y 14; {{N_EXCL_HOSP}} hospitalizaciones): aquí el reingreso **sí es posible**. {{N_EXCL_HOSP_LT30}} de ellas ({{PCT_EXCL_HOSP_LT30}}%) tienen `readmitted = <30`. Se excluyen porque el paciente pasa a cuidados de fin de vida: el objetivo clínico deja de ser evitar la hospitalización, el reingreso no es un resultado evitable que deba medir el programa y estos pacientes no son candidatos a un seguimiento cuyo fin es prevenirlo. Es el mismo criterio del estudio original de Strack et al. (2014).

{{INCLUIR:data/tablas/excluidos_por_codigo.md}}

* **Un registro por paciente** (la hospitalización con menor `encounter_id`). Se eliminaron {{N_DUP}} filas. **Justificación:** (1) las hospitalizaciones de un mismo paciente no son independientes —comparten edad, comorbilidades y conducta de consulta—; si quedaran repartidas entre entrenamiento y prueba habría **fuga de información** y las métricas serían optimistas; (2) el programa contacta *pacientes*, no hospitalizaciones; (3) los pacientes con muchas hospitalizaciones, que reingresan más, dominarían el archivo. **Costo:** se pierde información de los pacientes recurrentes y la primera hospitalización puede no ser representativa. *Nota de sensibilidad:* {{N_PRIMER_EXCL}} pacientes tienen como primer encuentro un fallecimiento/paliativo; en {{N_PRIMER_EXCL_MULTI}} de ellos hay encuentros posteriores y, siguiendo el orden del enunciado (excluir y luego deduplicar), se conserva uno posterior (caso marginal: {{PCT_MULTI}}% de los pacientes).
* **`Reingreso30`** = 1 si `readmitted` es `<30` y 0 en otro caso (`>30` o `NO`). Resultado: `data/diab_clean.csv` con **{{N_CLEAN}} filas y {{COLS_FINAL}} columnas**.

## 3. Análisis exploratorio

### 3.1 Distribución de la respuesta

{{INCLUIR:data/tablas/dist_readmitted.md}}

![Distribución de readmitted y Reingreso30](figuras/fig1_distribucion.png)

En el archivo original, el {{RAW_LT30}}% de las hospitalizaciones termina en reingreso en menos de 30 días ({{RAW_GT30}}% después de 30 días y {{RAW_NO}}% sin reingreso). Tras la limpieza, **la tasa de reingreso a 30 días es {{TASA_GLOBAL}}%** ({{N_REING}} de {{N_CLEAN}} pacientes): una clase positiva rara, con desbalance cercano a 1 a 10. Los dos pasos de limpieza mueven la tasa en sentidos opuestos. Excluir fallecidos y hospicio la **sube**, de {{RAW_LT30}}% a {{TASA_POST_EXCL}}% por hospitalización, porque casi todas esas altas tenían `readmitted = NO`. Dejar un registro por paciente la **baja** a {{TASA_GLOBAL}}%: en el original los pacientes recurrentes, que reingresan más, aportan muchas filas, y la primera hospitalización de cada paciente es, en promedio, de menor riesgo. `Reingreso30` colapsa `>30` y `NO` en una sola clase: mide el reingreso temprano, el que el programa de seguimiento busca evitar. El desbalance hace que la **exactitud sea una mala métrica**: predecir siempre «no reingreso» acierta {{P_ACC_BASE}}% en el conjunto de prueba.

### 3.2 Datos faltantes: las cinco peores columnas

{{INCLUIR:data/tablas/faltantes_top5.md}}

* `weight` ({{PCT_MISS_weight}}% faltante) es inutilizable. `medical_specialty` ({{PCT_MISS_medical_specialty}}%) y `payer_code` ({{PCT_MISS_payer_code}}%) faltan en casi la mitad de los registros y probablemente no al azar (dependen de cada hospital), por lo que no se usan como predictores.
* `admission_type_id` ({{PCT_MISS_admission_type_id}}%) y `admission_source_id` ({{PCT_MISS_admission_source_id}}%) tienen faltantes moderados; en el Modelo B se tratan como una categoría adicional `NA`.
* Los exámenes `A1Cresult` y `max_glu_serum` no se realizaron en {{PCT_A1C_NOTEST}}% y {{PCT_GLU_NOTEST}}% de los pacientes. Que el examen no se haga no es un dato faltante, pero sí limita lo que el resultado puede aportar: `A1Cresult` entra al Modelo B con `None` como categoría propia, y `max_glu_serum` no se usa.

### 3.3 Estadísticos descriptivos

{{INCLUIR:data/tablas/descriptivos.md}}

`time_in_hospital` y `num_medications` tienen cola derecha (media mayor que la mediana; máximos de {{MAX_time_in_hospital}} días y {{MAX_num_medications}} medicamentos), mientras que `num_lab_procedures` y `number_diagnoses` tienen medias algo menores que sus medianas. La estadía mediana es {{MED_time_in_hospital}} días (Q1–Q3: {{Q1_time_in_hospital}}–{{Q3_time_in_hospital}}; máximo {{MAX_time_in_hospital}}); se usan en promedio {{M_num_medications}} medicamentos distintos (mediana {{MED_num_medications}}) y {{M_num_lab_procedures}} procedimientos de laboratorio, y se registran en promedio {{M_number_diagnoses}} diagnósticos.

### 3.4 Tasa de reingreso < 30 días según variables clave

![Tasas de reingreso por edad, ingresos previos, HbA1c y medicación](figuras/fig2_tasas.png)

{{INCLUIR:data/tablas/tasa_edad.md}}

{{INCLUIR:data/tablas/tasa_inpatient.md}}

{{INCLUIR:data/tablas/tasa_A1C.md}}

{{INCLUIR:data/tablas/tasa_change.md}}

{{INCLUIR:data/tablas/tasa_diabetesMed.md}}

### 3.5 Diez diagnósticos principales (`diag_1`, ICD-9)

{{INCLUIR:data/tablas/top10_diag1.md}}

![Diagnósticos principales y tasa de reingreso](figuras/fig3_diagnosticos.png)

*Nota.* La tabla usa los códigos de `diag_1` tal como vienen, que es lo que pide el enunciado. La diabetes misma (ICD-9 250.xx) no aparece porque está repartida en {{DX250_NCOD}} subcódigos (250.8, 250.6, …). Agrupada en su categoría de tres caracteres suma {{DX250_N}} pacientes, con una tasa de {{DX250_TASA}}%, y ocuparía el lugar {{DX250_POS}} del ranking.

### 3.6 Tres hallazgos clave

1. **Las hospitalizaciones previas son el mayor gradiente de riesgo.** La tasa de reingreso sube de {{INP_0}}% (sin ingresos previos en el año anterior) a {{INP_1}}%, {{INP_2}}%, {{INP_3}}% y {{INP_4}}% con 1, 2, 3 y 4 o más (×{{INP_RATIO}} entre extremos). Quienes tuvieron al menos un ingreso previo son solo el {{PCT_PAC_PREV}}% de los pacientes pero concentran el {{PCT_REING_PREV}}% de los reingresos (fig. 2, tabla de ingresos previos).
2. **El riesgo aumenta con la edad.** Entre 20 y 59 años la tasa ronda {{EDAD_2059_MIN}}–{{EDAD_2059_MAX}}%; sube a {{EDAD_60_70}}% a los 60–69 y alcanza {{EDAD_70_80}}% y {{EDAD_80_90}}% a los 70–79 y 80–89 años. Bajo los 20 años hay muy pocos casos ({{EDAD_0_10}}% y {{EDAD_10_20}}%, con n = {{EDADN_0_10}} y {{EDADN_10_20}}), por lo que esas tasas son inestables.
3. **El diagnóstico principal y el manejo de la diabetes separan menos que el historial.** Entre los diez diagnósticos más frecuentes la tasa va de {{DX_786}}% (síntomas respiratorios y del tórax, 786) a {{DX_434}}% (oclusión de arterias cerebrales, 434) y {{DX_428}}% (insuficiencia cardiaca, 428). Las variables de manejo de la diabetes asocian diferencias modestas (menos de 2 puntos): {{DM_Yes}}% con medicación vs {{DM_No}}% sin ella, {{CH_Ch}}% con cambio de medicación vs {{CH_No}}% sin cambio, y {{A1C_None}}% cuando la HbA1c no se midió vs {{A1C_MED_MIN}}%–{{A1C_MED_MAX}}% cuando sí se midió. Son asociaciones, no efectos causales.

## 4. Modelación predictiva con Vowpal Wabbit

**Diseño.** Modelos de regresión logística (`vw --loss_function logistic`, 10 pasadas, regularización L2 de 1e-6, semilla 42). *Modelo A*: ocho variables numéricas; *Modelo B*: A más `age`, `gender`, `admission_type_id`, `admission_source_id`, `discharge_disposition_id`, `A1Cresult`, `insulin`, `change` y `diabetesMed` (los códigos como categorías, no como números). Las numéricas se estandarizan con la media y desviación estándar del entrenamiento; las categóricas se codifican como `variable=valor`, con `NA` para los faltantes. La conversión CSV → formato `vw` se hace con `awk`. Partición 70/30 por paciente (una fila por paciente; se verifica con `comm` que ningún paciente está en ambos conjuntos): entrenamiento {{P_NTRAIN}}, prueba {{P_NTEST}}. Los pacientes de prueba se ordenan por probabilidad predicha y se evalúa el **20 % superior** ({{P_K}} pacientes).

**Sobre la partición.** El enunciado propone `shuf --random-source=<(yes 42)`. Se verificó que esa fuente *no mezcla de forma uniforme* (el flujo `42\n42\n…` es periódico): el {{DEC10_YES}}% del conjunto de prueba proviene del último decil del archivo ordenado por `encounter_id` (esperado: 10%), donde la tasa de reingreso es menor ({{DEC10_TASA}}% frente a {{DEC1_TASA}}% en el primer decil). Resultado: tasa de reingreso de {{ALT_TASA_TRAIN}}% en entrenamiento y {{ALT_TASA_TEST}}% en prueba. Por eso la partición **principal** usa el mismo comando con una fuente pseudoaleatoria de calidad sembrada con 42 (generador Mersenne Twister de `python3`, `random.Random(42)`, que `shuf` consume como flujo de bytes): {{P_TASA_TRAIN}}% vs {{P_TASA_TEST}}%. La partición del enunciado se conserva como análisis de sensibilidad.

{{INCLUIR:data/tablas/diagnostico_particion.md}}

**¿Por qué el final del archivo tiene menos reingresos?** No es una tendencia temporal general. Con *todas* las hospitalizaciones la tasa de reingreso se mantiene estable entre deciles ({{DECT_MIN}}–{{DECT_MAX}}%); la caída aparece solo en la primera hospitalización de cada paciente. La explicación está en la ventana de observación. Los pacientes con más de una hospitalización registrada reingresan mucho más ({{VARIAS_MIN}}–{{VARIAS_MAX}}% en todos los deciles) que los que tienen una sola ({{UNA_MIN}}–{{UNA_MAX}}%). Un paciente que aparece por primera vez al final del período (2008) tiene menos tiempo para acumular hospitalizaciones dentro de los datos. En el último decil solo el {{OTRA_10}}% tiene otra hospitalización registrada, contra {{OTRA_MIN19}}–{{OTRA_MAX19}}% en los demás. Una partición que concentra la prueba en ese decil evalúa el modelo en una población distinta de la de entrenamiento.

{{INCLUIR:data/tablas/composicion_decil.md}}

### 4.1 Resultados (conjunto de prueba, 20 % de mayor riesgo)

{{INCLUIR:data/tablas/resultados_modelos.md}}

*Sensibilidad* = % de los reingresos de la prueba capturados entre los pacientes contactados; *precisión* = % de contactados que reingresan; *lift* = precisión / tasa global de la prueba ({{P_TASA_TEST}}%); *exactitud* evaluada con umbral 0.5. Si el 20% se elige **al azar**, la sensibilidad esperada es 20%; en 1000 selecciones aleatorias simuladas del 20% la sensibilidad media fue {{P_AZAR_MEDIA}}% (desviación estándar {{P_AZAR_DE}}; rango {{P_AZAR_MIN}}–{{P_AZAR_MAX}}%), de modo que ninguno de los dos modelos se parece al azar (A: {{P_SENS_A}}%, B: {{P_SENS_B}}%).

![Curva de ganancia acumulada](figuras/fig4_ganancia.png)

Intervalos de confianza del 95% (bootstrap de 1000 remuestras del conjunto de prueba, corte de score fijo). *Alcance:* estos intervalos reflejan solo la variabilidad del conjunto de prueba, con los modelos ya entrenados. No incluyen la variabilidad del entrenamiento (otra partición daría otros pesos), por lo que subestiman la incertidumbre total. La comparación con la partición del enunciado, más abajo, da una idea de esa otra fuente de variación.

{{INCLUIR:data/tablas/bootstrap_ic.md}}

Sensibilidad de la conclusión a la partición:

{{INCLUIR:data/tablas/comparacion_particiones.md}}

## 5. Interpretación

**(i) ¿Qué modelo prioriza mejor y cuánto mejora respecto del azar?** El **Modelo B**: contactando al 20% de mayor riesgo captura {{P_SENS_B}}% de los reingresos ({{P_CAP_B}} de {{P_TOT_TEST}}), con precisión {{P_PREC_B}}% y *lift* {{P_LIFT_B}}, frente a {{P_SENS_A}}% y {{P_LIFT_A}} del Modelo A y a 20% / 1.00 del azar. Es decir, B captura {{P_LIFT_B}} veces los reingresos que captura una selección aleatoria. La ventaja de B sobre A es de {{BS_dif_sensibilidad_B_menos_A_MED}} puntos de sensibilidad (IC 95%: {{BS_dif_sensibilidad_B_menos_A_LO}} a {{BS_dif_sensibilidad_B_menos_A_HI}}), con el intervalo completamente sobre cero. El AUC es {{P_AUC_B}} (B) y {{P_AUC_A}} (A): hay señal útil para priorizar, pero el poder discriminativo es modesto.

**(ii) ¿Por qué la exactitud es engañosa?** Porque solo ~{{TASA_GLOBAL}}% de los pacientes reingresa: un «modelo» que siempre predice «no reingreso» logra {{P_ACC_BASE}}% de exactitud sin identificar a ningún paciente de riesgo (sensibilidad 0%). Los Modelos A y B, evaluados con umbral 0.5, tienen {{P_ACC_A}}% y {{P_ACC_B}}%: prácticamente lo mismo, porque casi ninguna probabilidad supera 0.5 (solo {{P_N05_A}} y {{P_N05_B}} de {{P_NTEST}} pacientes en A y B), aunque B ordena claramente mejor. La exactitud ignora el orden y el desbalance; en este problema importa la capacidad de *ranking* (sensibilidad, precisión y *lift* en el 20% superior).

**(iii) ¿Qué variables ponderan más y son clínicamente razonables?**

*Modelo B: pesos de las ocho variables numéricas (log-odds por una desviación estándar).*

{{INCLUIR:data/tablas/pesos_B_numericas.md}}

*Modelo B: los 15 mayores efectos en valor absoluto, entre las variables numéricas y las categorías con al menos 300 pacientes en el entrenamiento. Las categorías se expresan como contraste con su categoría de referencia (la más frecuente).*

{{INCLUIR:data/tablas/pesos_B_top15.md}}

![Mayores pesos del Modelo B](figuras/fig5_pesos.png)

Entre las numéricas (por desviación estándar), pesa más `number_inpatient` ({{WB_number_inpatient}}), seguida de `number_diagnoses` ({{WB_number_diagnoses}}) y `time_in_hospital` ({{WB_time_in_hospital}}): más hospitalizaciones previas, estadías largas y más diagnósticos —mayor complejidad clínica— aumentan el riesgo. Entre las categóricas, relativas al alta a domicilio, destacan el alta a **rehabilitación** ({{W_DC22}}), a otro tipo de **institución de cuidado** ({{W_DC5}}), a **otro hospital** ({{W_DC2}}) y a **centro de enfermería especializada (SNF)** ({{W_DC3}}), que son pacientes más frágiles; los pacientes de 10 a 19 años tienen menor riesgo (`age=[10-20)`: {{W_AGE1020}} frente a 70–79 años), igual que quienes no usan medicación para la diabetes ({{W_DMNO}}), y la insulina con dosis reducida (`Down`) se asocia a mayor riesgo ({{W_INSDOWN}}). Los pesos de las numéricas (por desviación estándar) y los de las categorías (contraste con la categoría de referencia) no son directamente comparables entre sí. La mayoría de los efectos es clínicamente razonable, con dos matices. Primero, el peso de `time_in_hospital` baja de {{WA_time_in_hospital}} en el Modelo A a {{WB_time_in_hospital}} en el B: parte de su efecto lo recoge el destino al alta, porque las estadías largas terminan más a menudo en traslado a otra institución (estadía media de {{TIH_INST}} días con alta a otra institución, contra {{TIH_CASA}} con alta a domicilio). El peso de una variable depende de qué otras incluye el modelo. Segundo, el ingreso desde un centro de enfermería especializada (`admission_source_id=5`) tiene peso negativo ({{W_AS5}}), sin una explicación clínica evidente; puede reflejar cómo se registra ese origen, y no conviene interpretarlo. En todo caso son **asociaciones predictivas, no causales**, y las categorías raras (< 300 pacientes) no se interpretan.

**(iv) Efecto de usar varias hospitalizaciones del mismo paciente y cómo verificarlo.**

*Qué se espera.* Las hospitalizaciones de un mismo paciente están correlacionadas: misma edad, mismas comorbilidades, mismo historial de ingresos. Con una partición al azar por fila, el mismo paciente quedaría en entrenamiento y en prueba, y el modelo podría «reconocerlo». Esa **fuga de información** inflaría el AUC, la sensibilidad y el *lift*. Además, al contar como independientes datos que no lo son, se subestimaría la incertidumbre, y los pacientes con muchas hospitalizaciones pesarían más.

*Cómo se verificó.* Además de comprobar con `comm -12` que el análisis principal no comparte pacientes entre entrenamiento y prueba (0 compartidos), se hizo el experimento directo. Se tomaron todas las hospitalizaciones tras excluir fallecidos y hospicio ({{N_TODAS}}, sin deduplicar) y se entrenó el mismo Modelo B con dos particiones 70/30 que solo difieren en *cómo* se reparte: **por fila** (cada hospitalización al azar) y **por paciente** (se sortean pacientes y todas sus hospitalizaciones van al mismo lado).

{{INCLUIR:data/tablas/fuga_hospitalizaciones.md}}

*Resultado.* La fuga es real: con la partición por fila, el {{FUGA_FILA_PCOMP}}% de las hospitalizaciones de prueba pertenece a pacientes que también están en entrenamiento. Pero su efecto sobre este modelo es **pequeño**: AUC {{FUGA_FILA_AUC}} contra {{FUGA_PAC_AUC}} (diferencia {{FUGA_DIF_AUC}}) y sensibilidad {{FUGA_FILA_SENS}}% contra {{FUGA_PAC_SENS}}% (diferencia {{FUGA_DIF_SENS}} puntos), dentro de la variación esperable de una sola partición. Tiene sentido: una regresión logística con 17 variables generales no puede memorizar pacientes individuales. La fuga sería mucho mayor con modelos flexibles (árboles, *boosting*) o con variables que identifiquen al paciente.

El efecto más importante de usar todas las hospitalizaciones es otro: **cambia la población evaluada**. La tasa de reingreso de la prueba sube de {{P_TASA_TEST}}% (por paciente) a {{FUGA_PAC_TASA}}% (por hospitalización), y la precisión del 20% superior de {{P_PREC_B}}% a {{FUGA_PAC_PREC}}%, porque los pacientes recurrentes aportan muchas filas. Esas cifras miden otra cosa: «hospitalizaciones contactadas», no «pacientes contactados». Mezclarlas sobreestimaría lo que el programa logra por cada paciente al que llama. Por eso el análisis principal usa un registro por paciente.

**(v) ¿Es apropiado usar la raza como predictor?** **No.** Aunque ninguno de los modelos la usa, conviene explicar por qué y qué ocurre sin ella. (a) La raza es un atributo protegido: usarla para decidir a quién se contacta puede generar trato desigual y riesgo legal y ético, y la asociación con reingreso refleja determinantes sociales (acceso, seguro, barrios) más que biología. (b) En los datos la raza falta en {{PCT_RAW_race}}% de las hospitalizaciones y varios grupos son pequeños. (c) Aun sin raza, el modelo puede no ser neutral: con tasas de reingreso observadas de {{EQ_TASA_Caucasian}}% en caucásicos y {{EQ_TASA_AfricanAmerican}}% en afroamericanos, el Modelo B incluye en el 20% de mayor riesgo al {{EQ_SEL_Caucasian}}% de los caucásicos (IC 95%: {{EQ_SELIC_Caucasian}}) y al {{EQ_SEL_AfricanAmerican}}% de los afroamericanos (IC 95%: {{EQ_SELIC_AfricanAmerican}}), una brecha {{EQ_SEL_VEREDICTO}}; y captura {{EQ_SENS_Caucasian}}% (IC 95%: {{EQ_SENSIC_Caucasian}}) de los reingresos de los primeros frente a {{EQ_SENS_AfricanAmerican}}% ({{EQ_SENSIC_AfricanAmerican}}) de los segundos, una brecha {{EQ_SENS_VEREDICTO}}.

(d) *¿De dónde viene la brecha de selección?* Coincide con diferencias de composición en las variables que más pesan en el modelo. En la prueba, el {{EQC_V70_AfricanAmerican}}% de los pacientes afroamericanos tiene 70 años o más, contra {{EQC_V70_Caucasian}}% de los caucásicos. Tienen algún ingreso previo el {{EQC_PREV_AfricanAmerican}}% contra el {{EQC_PREV_Caucasian}}%, y son dados de alta a otra institución (códigos 2, 3, 4, 5 y 22) el {{EQC_INST_AfricanAmerican}}% contra el {{EQC_INST_Caucasian}}%. Entre los pacientes seleccionados, la **precisión es similar**: reingresa el {{EQC_PREC_AfricanAmerican}}% de los afroamericanos contactados (IC 95%: {{EQC_PRECIC_AfricanAmerican}}) y el {{EQC_PREC_Caucasian}}% de los caucásicos ({{EQC_PRECIC_Caucasian}}), una diferencia {{EQ_PREC_VEREDICTO}}. Es decir, entre los contactados la proporción que efectivamente reingresa es parecida en ambos grupos. La menor selección de pacientes afroamericanos coincide con que, en promedio, presentan menos de los factores de riesgo que el modelo usa. Estas variables pueden, a la vez, recoger diferencias de acceso a la atención: un menor registro de ingresos previos puede reflejar menos acceso y no menos riesgo. Con estos datos eso no se puede distinguir.

**Recomendación.** No usar la raza como predictor. Usarla **solo para auditar**: medir periódicamente, por grupo, la proporción seleccionada, la sensibilidad y la precisión. Si el comité quisiera además igualar la sensibilidad entre grupos, tendría que fijar cuotas o umbrales por raza, lo que en sí mismo es usar la raza para decidir a quién se llama. Esa es una decisión de política, con implicancias legales y éticas, que corresponde al comité y no al modelo; el análisis solo entrega la evidencia. Es un chequeo exploratorio, con grupos pequeños y un único conjunto de prueba.

![Desempeño por grupo racial](figuras/fig6_equidad.png)

{{INCLUIR:data/tablas/equidad_raza.md}}

*Composición de los pacientes de prueba por raza* (variables de mayor peso del Modelo B) *y precisión entre los seleccionados:*

{{INCLUIR:data/tablas/equidad_composicion.md}}

## 6. Conclusión y recomendación al comité

* **Recomendación:** usar el **Modelo B** para priorizar el seguimiento telefónico. Contactar al 20% de pacientes con mayor riesgo predicho captura **{{P_SENS_B}}%** de los reingresos a 30 días, **{{P_LIFT_B}} veces** lo que se lograría al azar (IC 95% del *lift*: {{BS_lift_B_LO}}–{{BS_lift_B_HI}}).
* **Alcance honesto:** el AUC de {{P_AUC_B}} indica que el modelo ordena a los pacientes solo moderadamente bien: el {{NOCAPT_B}}% de los reingresos queda fuera del 20% contactado. Se recomienda complementarlo con reglas simples y trazables (ingresos previos y alta a una institución de cuidado) y evaluar su desempeño en datos más recientes.
* **Equidad y privacidad:** no usar la raza como predictor, sino solo para auditar. Monitorear por grupo la proporción seleccionada, la sensibilidad y la precisión: hoy se selecciona a una menor proporción de pacientes afroamericanos, con una precisión similar. Si se decide intervenir, que lo resuelva el comité como decisión explícita de política. No distribuir los datos de pacientes fuera del entorno autorizado.
* **Limitaciones:** un solo conjunto de prueba (sin validación cruzada ni validación temporal); intervalos bootstrap que solo recogen la variabilidad de la prueba; modelo lineal sin interacciones ni ajuste fino de hiperparámetros; datos de 1999–2008; solo reingresos observados en estos hospitales; ventana de observación más corta para los pacientes vistos por primera vez al final del período; análisis restringido a la primera hospitalización de cada paciente.

## 7. Ficha de seguimiento post-alta

Generada por el pipeline (`report/ficha.txt`) con comandos sobre `data/diab_clean.csv` y `data/test_pred.csv` (Modelo B, partición principal):

```text
{{INCLUIR:report/ficha.txt}}
```

## 8. Reproducibilidad

```bash
git clone {{REPO_URL}} && cd {{REPO_DIR}}
# dentro del contenedor datasciencetoolbox/dsatcl2e (o una terminal Linux con las herramientas indicadas)
bash scripts/pipeline.sh
```

Estructura: `scripts/` (`pipeline.sh`, `graficos.py`, `csv2tex.py`), `data/` (datos y tablas intermedias; se genera y no se versiona), `report/` (`reporte.md`, `ficha.txt`, `informe.tex`, `informe.pdf`, `figuras/`). Rutas relativas a la raíz del repositorio. Semillas: 42 (partición, `vw`, simulaciones).

**Verificación del texto.** Las afirmaciones cualitativas de este reporte dependen de los números: el orden de los pesos, sus signos, si una tasa «sube» o «baja». Por eso el pipeline las comprueba una a una contra los valores calculados (`data/tablas/verificacion_texto.csv`, que se genera al ejecutarlo) y avisa si alguna deja de cumplirse, por ejemplo con otra versión de `vw`. En esta ejecución se cumplen **{{VERIF_OK}} de {{VERIF_N}}**.

**Validación entre entornos.** El pipeline se ejecutó desde cero, con descarga incluida, en dos entornos con versiones distintas de las herramientas: el contenedor `datasciencetoolbox/dsatcl2e` (`vw` 8.11, `shuf` 8.32, `mawk`, Python 3.9) y Ubuntu 24.04 en WSL (`vw` 8.6.1, `shuf` 9.4, `gawk`, Python 3.12). Todas las tablas, `data/diab_clean.csv` y `report/valores.env` resultaron idénticos byte a byte, y se cumplieron las mismas verificaciones. Las probabilidades de `vw` difieren solo en la sexta cifra decimal (menos de 0.00001), sin cambiar el orden de los pacientes ni ninguna métrica. Lo único que cambia es la línea `Analista` de la ficha, que toma el usuario que ejecuta (`whoami`).

Entorno de la última ejecución:

```text
{{INCLUIR:data/tablas/entorno.txt}}
```
