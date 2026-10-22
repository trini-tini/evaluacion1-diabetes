%Evaluación N°1. Generado desde report/informe.tex.tpl por scripts/pipeline.sh
% (las cifras provienen de report/valores.env). Compilar con: xelatex informe.tex (dos veces) o latexmk -xelatex.
\documentclass[11pt,a4paper]{article}
\usepackage{fontspec}
\usepackage[spanish,es-noshorthands,es-tabla]{babel}
\usepackage[a4paper,margin=2.4cm]{geometry}
\usepackage{booktabs,graphicx,float,adjustbox,caption,xcolor,enumitem,listings,fancyhdr,setspace}
\usepackage[hidelinks]{hyperref}
\usepackage{amsmath}
\usepackage{underscore}   % permite _ dentro de \texttt sin escapar
\captionsetup{font=small,labelfont=bf}
\setlist{itemsep=2pt,topsep=4pt}
\setstretch{1.08}
\emergencystretch=3em      % evita desbordes por palabras largas en \texttt
\lstset{basicstyle=\ttfamily\footnotesize,breaklines=true,columns=fullflexible,frame=single,
  backgroundcolor=\color{black!4},rulecolor=\color{black!20},xleftmargin=2pt,xrightmargin=2pt,
  showstringspaces=false,upquote=true}
\newcommand{\cod}[1]{\texttt{#1}}
\newenvironment{tablaentex}[2]{% caption, label; el contenido (tabular) lo inserta el pipeline
  \begin{table}[H]\centering\small\caption{#1}\label{#2}\begin{adjustbox}{max width=\textwidth}}%
  {\end{adjustbox}\end{table}}
\pagestyle{fancy}\fancyhf{}
\fancyhead[L]{\small Evaluación N°1}
\fancyhead[R]{\small Dataset: Diabetes}
\fancyfoot[C]{\thepage}
\renewcommand{\headrulewidth}{0.3pt}

\begin{document}

% ------------------------------------------------------------------ PORTADA
\begin{titlepage}
\centering
{\large UNIVERSIDAD DEL BÍO-BÍO}\\[2pt]
{\normalsize Facultad de Ciencias}\\[2pt]
{\normalsize Departamento de Estadística}\\[1.6cm]
\rule{\textwidth}{0.6pt}\\[0.5cm]
{\Large\bfseries Ciencia de Datos en la Terminal Linux}\\[0.4cm]
{\large Evaluación N°1}\\[0.5cm]
\rule{\textwidth}{0.6pt}\\[1.6cm]
{\LARGE\bfseries ¿Quién vuelve al hospital?}\\[0.5cm]
{\Large Reingresos de pacientes diabéticos en 130 hospitales de EE.\,UU.}\\[1.2cm]
{\large Dataset asignado: \textbf{Diabetes}}\\[2.2cm]
\begin{tabular}{rl}
\textbf{Autora:}   & Trinidad Saez \\
\textbf{Profesor:} & Luis Gómez \\
\textbf{Entrega:}  & 22 de octubre de 2026 \\
\end{tabular}\\[2cm]
{\normalsize Octubre de 2026}
\vfill
{\small Repositorio con el código, el pipeline reproducible y este informe:\\ \texttt{scripts/pipeline.sh} $\cdot$ \texttt{report/reporte.md} $\cdot$ \texttt{report/informe.pdf}}
\end{titlepage}

\tableofcontents
\vspace{1.5em}
\listoffigures
\clearpage
\listoftables
\clearpage

% ------------------------------------------------------------------ 1
\section{Introducción y objetivo}
El comité de calidad de una red hospitalaria quiere reducir los reingresos tempranos de pacientes con diabetes.
Cuenta con un programa de seguimiento telefónico post-alta, pero solo puede contactar al \textbf{20\,\%} de los pacientes.
Con registros de diez años (1999--2008) de atención en 130 hospitales de EE.\,UU., el comité plantea la pregunta:
\begin{quote}\itshape ¿Qué características de un paciente se asocian con un reingreso en menos de 30 días y qué tan bien permite un modelo sencillo priorizar al 20\,\% de pacientes con mayor riesgo?\end{quote}
El trabajo se realizó exclusivamente con herramientas de línea de comandos (\cod{awk}, \cod{sed}, \cod{tr}, \cod{sort}, \cod{csvkit}, \cod{vw}, \cod{python3} con \cod{matplotlib}), en un flujo de obtención, limpieza, exploración, modelación e interpretación, empaquetado en un único \emph{pipeline} reproducible (\cod{scripts/pipeline.sh}).

% ------------------------------------------------------------------ 2
\section{Datos y consideraciones éticas}
\textbf{Fuente.} Clore, J., Cios, K., DeShazo, J., \& Strack, B. (2014). \emph{Diabetes 130-US Hospitals for Years 1999-2008} [Conjunto de datos]. UCI Machine Learning Repository. \url{https://doi.org/10.24432/C5230J}.

\textbf{Estudio que describe los datos.} Strack, B., DeShazo, J.\,P., Gennings, C., Olmo, J.\,L., Ventura, S., Cios, K.\,J., \& Clore, J.\,N. (2014). Impact of HbA1c measurement on hospital readmission rates: Analysis of 70,000 clinical database patient records. \emph{BioMed Research International}, 2014, 781670. \url{https://doi.org/10.1155/2014/781670}.

El archivo \cod{diabetic_data.csv} contiene {{N_RAW}} hospitalizaciones de {{N_PAC_RAW}} pacientes (una fila por hospitalización) y {{COLS_RAW}} columnas: identificadores (\cod{encounter\_id}, \cod{patient\_nbr}), datos demográficos (\cod{race}, \cod{gender}, \cod{age} en intervalos de 10 años), características de la estadía (\cod{time\_in\_hospital}, \cod{num\_lab\_procedures}, \cod{num\_medications}, \dots), visitas del año anterior (\cod{number\_outpatient}, \cod{number\_emergency}, \cod{number\_inpatient}), diagnósticos (\cod{diag\_1}--\cod{diag\_3}, códigos ICD-9), exámenes (\cod{A1Cresult}, \cod{max\_glu\_serum}), 23 columnas de medicamentos, \cod{change}, \cod{diabetesMed} y la respuesta \cod{readmitted} (\cod{<30}, \cod{>30}, \cod{NO}). El archivo \cod{IDS\_mapping.csv} es el diccionario de los códigos \cod{admission\_type\_id}, \cod{discharge\_disposition\_id} y \cod{admission\_source\_id}.

\textbf{Datos sensibles.} Los datos incluyen edad, sexo y raza. Se adoptaron tres decisiones: (i) el repositorio \emph{no} contiene los datos (el \emph{pipeline} los descarga desde UCI); (ii) la \textbf{raza no se usa como predictor}; y (iii) se \textbf{audita} el desempeño del modelo por grupo racial (sección~\ref{sec:equidad}).

% ------------------------------------------------------------------ 3
\section{Metodología}\label{sec:metodo}
\subsection{Entorno y reproducibilidad}
El análisis se ejecuta desde la raíz del repositorio con \cod{bash scripts/pipeline.sh}; todas las rutas son relativas (\cod{./data}, \cod{./scripts}, \cod{./report}). El script usa \cod{set -eu} y verificaciones automáticas (por ejemplo, que \cod{diab\_clean.csv} tenga un paciente por fila y que ningún paciente esté a la vez en entrenamiento y prueba). Las semillas son 42. El apéndice~\ref{app:entorno} lista las versiones del entorno usado. Además, las afirmaciones cualitativas del texto (el orden de los pesos, sus signos, si una tasa «sube» o «baja») se comprueban una a una contra los valores calculados (\cod{data/tablas/verificacion\_texto.csv}, que se genera al ejecutarlo), de modo que el pipeline avisa si alguna deja de cumplirse con otra versión de las herramientas. En esta ejecución se cumplen {{VERIF_OK}} de {{VERIF_N}}.

\textbf{Validación entre entornos.} El \emph{pipeline} se ejecutó desde cero, con descarga incluida, en dos entornos con versiones distintas: el contenedor \cod{datasciencetoolbox/dsatcl2e} (\cod{vw} 8.11, \cod{shuf} 8.32, \cod{mawk}, Python 3.9) y Ubuntu 24.04 en WSL (\cod{vw} 8.6.1, \cod{shuf} 9.4, \cod{gawk}, Python 3.12). Todas las tablas, \cod{data/diab\_clean.csv} y \cod{report/valores.env} resultaron idénticos byte a byte. Las probabilidades de \cod{vw} difieren solo en la sexta cifra decimal ($<10^{-5}$), sin cambiar el orden de los pacientes ni ninguna métrica. Solo cambia la línea \emph{Analista} de la ficha, que toma el usuario que ejecuta (\cod{whoami}).

\subsection{Limpieza de datos}
\textbf{Inspección.} Se inspeccionaron los archivos con \cod{head}, \cod{file} y \cod{cat -A}, que muestra los caracteres no imprimibles. Ambos archivos terminan sus líneas en \cod{\^{}M\$} (CRLF), y \cod{IDS\_mapping.csv} reúne tres tablas separadas por líneas con una sola coma. Se normalizaron los terminadores con \cod{tr}; si no se hiciera, el último campo valdría \cod{NO\^{}M} o \cod{<30\^{}M} y cualquier comparación fallaría sin avisar:
\begin{lstlisting}
tr -d '\r' < data/diabetic_data.csv > data/interim/raw_lf.csv
\end{lstlisting}

\textbf{Diccionario.} Se separaron las tres tablas con \cod{awk}: una línea vacía o \cod{,} señala el cambio de tabla, y un encabezado \cod{xxx,description} abre un archivo nuevo. Las descripciones se cortan en la \emph{primera} coma (algunas llevan comas entre comillas) y se les quitan comillas y espacios sobrantes.
\begin{lstlisting}
awk '/^,*$/ {next}
     /^[a-z_]+,description$/ {split($0,h,","); out="data/mapa_" h[1] ".csv"; print > out; next}
     {i=index($0,","); cod=substr($0,1,i-1); d=substr($0,i+1); gsub(/^"|"$/,"",d)
      gsub(/^ +| +$/,"",d); if (d~/,/) d="\"" d "\""; print cod "," d > out}' data/interim/ids_lf.csv
\end{lstlisting}

\textbf{Valores faltantes.} Como el dato faltante no es la celda vacía sino el marcador \cod{?}, se contaron por columna los \cod{?}, las celdas vacías, los \cod{None} y los \cod{Unknown/Invalid} con un \cod{awk} que recorre todas las columnas. Un \cod{None} en \cod{A1Cresult} o \cod{max\_glu\_serum} indica que el examen \emph{no se realizó}; es información clínica y se conserva como categoría. Los códigos del diccionario cuyas descripciones son \cod{NULL}, \cod{Not Available}, \cod{Not Mapped} o \cod{Unknown/Invalid} \emph{son faltantes disfrazados}; se detectan con una expresión regular sobre el propio diccionario (no a mano) y se recodifican como celda vacía junto con los \cod{?}.

\textbf{Exclusión de fallecidos y cuidados paliativos.} Los códigos de alta cuya descripción contiene \cod{Expired} o \cod{Hospice} (11, 13, 14, 19, 20 y 21) se identifican también desde el diccionario y se excluyen. La justificación es distinta para cada grupo. Un paciente \emph{fallecido} no puede reingresar, y dejarlo como «no reingreso» confundiría mortalidad con buena evolución. Un paciente en \emph{hospicio} sí puede reingresar (la tabla~\ref{tab:excl} lo cuantifica), pero pasa a cuidados de fin de vida. Desde ese momento el objetivo clínico ya no es evitar la hospitalización, su reingreso no es un resultado evitable que el programa deba medir y no es candidato a un seguimiento cuyo fin es prevenirlo. Es el mismo criterio de Strack et~al.~(2014).

\textbf{Un registro por paciente.} Se conserva la hospitalización con menor \cod{encounter\_id} de cada paciente:
\begin{lstlisting}
tail -n +2 pasoB.csv | sort -t, -k2,2n -k1,1n | awk -F, '!visto[$2]++' | sort -t, -k1,1n
\end{lstlisting}
La justificación es la independencia: las hospitalizaciones del mismo paciente están correlacionadas y, repartidas entre entrenamiento y prueba, filtrarían información. Además, el programa contacta pacientes y no hospitalizaciones, y los pacientes recurrentes (que reingresan más) dominarían el archivo.

\textbf{Columnas constantes y respuesta.} Una pasada de \cod{awk} cuenta los valores distintos por columna y elimina las que tienen uno solo; en la misma pasada se crea \cod{Reingreso30} $=1$ si \cod{readmitted} es \cod{<30} y $0$ en otro caso. El resultado se guarda en \cod{data/diab\_clean.csv}.

\subsection{Análisis exploratorio}
Las tasas de reingreso por categoría se calculan con \cod{csvcut} (selecciona la variable y \cod{Reingreso30}) y un \cod{awk} que acumula conteos por categoría; los descriptivos (media, desviación estándar, cuartiles, mínimo y máximo) se calculan sobre la columna ordenada. Las figuras se generan con \cod{python3} y \cod{matplotlib} (\cod{scripts/graficos.py}).

\subsection{Modelación predictiva}
\textbf{Modelos.} Regresión logística con Vowpal Wabbit (\cod{vw --loss\_function logistic --passes 10 --l2 1e-6 -b 22}). El \textbf{Modelo A} usa ocho variables numéricas (\cod{time\_in\_hospital}, \cod{num\_lab\_procedures}, \cod{num\_procedures}, \cod{num\_medications}, \cod{number\_outpatient}, \cod{number\_emergency}, \cod{number\_inpatient}, \cod{number\_diagnoses}); el \textbf{Modelo B} agrega \cod{age}, \cod{gender}, \cod{admission\_type\_id}, \cod{admission\_source\_id}, \cod{discharge\_disposition\_id}, \cod{A1Cresult}, \cod{insulin}, \cod{change} y \cod{diabetesMed}, con los códigos tratados como \emph{categorías}. Las numéricas se estandarizan con la media y la desviación estándar del entrenamiento y las categóricas se codifican con \cod{awk} como \cod{variable=valor} (los faltantes como \cod{NA}):
\begin{lstlisting}
-1 |num time_in_hospital:0.219 ... number_diagnoses:0.964 |cat age=_60_70_ gender=Male admission_type_id=NA ...
\end{lstlisting}
\textbf{Partición.} 70\,\% entrenamiento y 30\,\% prueba con semilla 42, sobre \cod{diab\_clean.csv} (una fila por paciente, por lo que la partición es por paciente). El enunciado propone la orden
\begin{lstlisting}
shuf --random-source=<(yes 42)
\end{lstlisting}
Como se muestra en la sección~\ref{sec:resparticion}, esa fuente no mezcla uniformemente, de modo que la partición \emph{principal} usa el mismo comando con una fuente pseudoaleatoria de calidad sembrada con 42 (generador Mersenne Twister de \cod{python3}, \cod{random.Random(42)}), y la del enunciado se conserva como análisis de sensibilidad.

\textbf{Evaluación.} Con las probabilidades $\hat p_i=1/(1+e^{-s_i})$ del conjunto de prueba ($N$ pacientes), se ordena de mayor a menor y se toman los $K=\lfloor N/5\rfloor$ primeros (el 20\,\%). Con $C$ reingresos capturados entre ellos y $T$ reingresos en total:
\[
\text{sensibilidad}=\frac{C}{T},\qquad
\text{precisión}=\frac{C}{K},\qquad
\text{lift}=\frac{C/K}{T/N}.
\]
La selección aleatoria tiene sensibilidad esperada 20\,\% y $\text{lift}=1$. Se agregan: el AUC (Mann--Whitney, con empates), la exactitud con umbral 0.5, una simulación de 1000 selecciones aleatorias del 20\,\%, e intervalos de confianza del 95\,\% por \emph{bootstrap} (1000 remuestras del conjunto de prueba con el corte de puntaje fijo en el del 20\,\% superior).
\begin{lstlisting}
K=$(( NTEST / 5 ))
CAPT=$(tail -n +2 data/test_pred.csv | LC_ALL=C sort -t, -k2,2gr | head -n $K | awk -F, '{s+=$1} END{print s}')
\end{lstlisting}

% 
\section{Resultados}
\subsection{Limpieza}
La tabla~\ref{tab:pasos} resume las filas antes y después de cada paso. Se normalizaron los terminadores de línea y se recodificaron {{R_Q}} celdas \cod{?} y las celdas con códigos ausentes del diccionario (tabla~\ref{tab:recod}); se excluyeron {{N_EXCL}} hospitalizaciones con alta por fallecimiento u hospicio (tabla~\ref{tab:excl}): {{N_EXCL_FALL}} por fallecimiento, ninguna con reingreso registrado ({{N_EXCL_FALL_LT30}}), y {{N_EXCL_HOSP}} a hospicio, de las cuales {{N_EXCL_HOSP_LT30}} ({{PCT_EXCL_HOSP_LT30}}\,\%) sí reingresaron en menos de 30 días; y se conservó una hospitalización por paciente ({{N_DUP}} filas eliminadas). Se eliminaron las columnas constantes \cod{examide}, \cod{citoglipton} y \cod{glimepiride-pioglitazone} (esta última queda constante una vez filtradas las filas). Resultado: {{N_CLEAN}} pacientes y {{COLS_FINAL}} columnas.

\begin{tablaentex}{Filas, pacientes únicos y columnas después de cada paso de limpieza.}{tab:pasos}
{{INCLUIR:data/tablas/limpieza_pasos.tex}}
\end{tablaentex}
\begin{tablaentex}{Celdas recodificadas como faltantes en el paso A.}{tab:recod}
{{INCLUIR:data/tablas/recodificacion.tex}}
\end{tablaentex}
\begin{tablaentex}{Códigos del diccionario tratados como información ausente o como alta por fallecimiento/paliativos.}{tab:codigos}
{{INCLUIR:data/tablas/codigos_especiales.tex}}
\end{tablaentex}
\begin{tablaentex}{Hospitalizaciones excluidas por alta con fallecimiento u hospicio, y cuántas tenían \cod{readmitted} $=$ \cod{<30}.}{tab:excl}
{{INCLUIR:data/tablas/excluidos_por_codigo.tex}}
\end{tablaentex}

\textbf{Faltantes y exámenes no realizados.} En el archivo original los porcentajes de \cod{?} fueron: \cod{weight} {{PCT_RAW_weight}}\,\%, \cod{medical\_specialty} {{PCT_RAW_medical_specialty}}\,\%, \cod{payer\_code} {{PCT_RAW_payer_code}}\,\%, \cod{race} {{PCT_RAW_race}}\,\%, \cod{diag\_3} {{PCT_RAW_diag_3}}\,\% y \cod{diag\_2} {{PCT_RAW_diag_2}}\,\%. Los \cod{None} de \cod{A1Cresult} ({{PCT_A1C_NONE_RAW}}\,\%) y \cod{max\_glu\_serum} ({{PCT_GLU_NONE_RAW}}\,\%) significan examen no realizado y no se imputan. Del diccionario, {{R_TIPO}} celdas de \cod{admission\_type\_id}, {{R_ALTA}} de \cod{discharge\_disposition\_id} y {{R_FUENTE}} de \cod{admission\_source\_id} tenían códigos ausentes; \cod{gender} tenía {{R_GEN}} valores \cod{Unknown/Invalid}.

\textbf{Sensibilidad al orden de los pasos.} {{N_PRIMER_EXCL}} pacientes tienen como primer encuentro un alta por fallecimiento u hospicio; en {{N_PRIMER_EXCL_MULTI}} de ellos hay encuentros posteriores. Siguiendo el orden del enunciado (excluir y luego dejar uno por paciente) se conserva un encuentro posterior; el caso es marginal ({{PCT_MULTI}}\,\% de los pacientes).

\subsection{Análisis exploratorio}
\paragraph{Respuesta.} En el archivo original el {{RAW_LT30}}\,\% de las hospitalizaciones termina en reingreso en menos de 30 días ({{RAW_GT30}}\,\% a más de 30 días y {{RAW_NO}}\,\% sin reingreso). Tras la limpieza, la tasa de \cod{Reingreso30} es \textbf{{{TASA_GLOBAL}}\,\%} ({{N_REING}} de {{N_CLEAN}} pacientes): una clase positiva rara, con desbalance de aproximadamente 1 a 10. Los dos pasos de limpieza mueven la tasa en sentidos opuestos. Excluir fallecidos y hospicio la \emph{sube}, de {{RAW_LT30}}\,\% a {{TASA_POST_EXCL}}\,\% por hospitalización, porque casi todas esas altas tenían \cod{readmitted} $=$ \cod{NO}. Dejar un registro por paciente la \emph{baja} a {{TASA_GLOBAL}}\,\%: en el original los pacientes recurrentes, que reingresan más, aportan muchas filas. \cod{Reingreso30} colapsa \cod{>30} y \cod{NO}: mide el reingreso temprano que el programa busca evitar. Predecir siempre «no reingreso» acierta el {{P_ACC_BASE}}\,\% en la prueba, por lo que la exactitud no sirve como métrica (sección~\ref{sec:disc}).

\begin{figure}[H]\centering\includegraphics[width=\textwidth]{figuras/fig1_distribucion.png}
\caption{Distribución de \cod{readmitted} (original y limpia) y de \cod{Reingreso30}.}\label{fig:dist}\end{figure}
\begin{tablaentex}{Distribución de \cod{readmitted} antes de la limpieza y de \cod{readmitted} y \cod{Reingreso30} después.}{tab:dist}
{{INCLUIR:data/tablas/dist_readmitted.tex}}
\end{tablaentex}

\paragraph{Datos faltantes.} La tabla~\ref{tab:falt} muestra las cinco columnas con más celdas vacías tras la limpieza. \cod{weight} ({{PCT_MISS_weight}}\,\%) es inutilizable; \cod{medical\_specialty} ({{PCT_MISS_medical_specialty}}\,\%) y \cod{payer\_code} ({{PCT_MISS_payer_code}}\,\%) faltan en casi la mitad de los registros y, probablemente, no al azar (dependen de las prácticas de cada hospital), por lo que no se usan como predictores. \cod{admission\_type\_id} ({{PCT_MISS_admission_type_id}}\,\%) y \cod{admission\_source\_id} ({{PCT_MISS_admission_source_id}}\,\%) se tratan como una categoría adicional \cod{NA} en el Modelo B. Además, los exámenes de laboratorio casi no se realizan (tabla~\ref{tab:noexam}): {{PCT_A1C_NOTEST}}\,\% sin HbA1c y {{PCT_GLU_NOTEST}}\,\% sin glucosa sérica. Que el examen no se haga no es un dato faltante, pero limita lo que el resultado puede aportar: \cod{A1Cresult} entra al Modelo B con \cod{None} como categoría propia, y \cod{max\_glu\_serum} no se usa.
\begin{tablaentex}{Las cinco columnas con mayor porcentaje de celdas vacías en \cod{diab\_clean.csv}.}{tab:falt}
{{INCLUIR:data/tablas/faltantes_top5.tex}}
\end{tablaentex}
\begin{tablaentex}{Exámenes no realizados (\cod{None}); no se consideran datos faltantes.}{tab:noexam}
{{INCLUIR:data/tablas/examenes_no_realizados.tex}}
\end{tablaentex}

\paragraph{Estadísticos descriptivos.} \cod{time\_in\_hospital} y \cod{num\_medications} tienen cola derecha (media mayor que la mediana; máximos de {{MAX_time_in_hospital}} días y {{MAX_num_medications}} medicamentos), mientras que \cod{num\_lab\_procedures} y \cod{number\_diagnoses} tienen medias algo menores que sus medianas. La estadía mediana es de {{MED_time_in_hospital}} días (Q1--Q3: {{Q1_time_in_hospital}}--{{Q3_time_in_hospital}}).
\begin{tablaentex}{Estadísticos descriptivos de variables numéricas seleccionadas.}{tab:desc}
{{INCLUIR:data/tablas/descriptivos.tex}}
\end{tablaentex}

\paragraph{Tasas de reingreso.} Las tablas~\ref{tab:edad}--\ref{tab:dm} y la figura~\ref{fig:tasas} muestran la tasa de reingreso a 30 días según edad, ingresos hospitalarios previos, resultado de HbA1c, cambio de medicación y uso de medicamentos para la diabetes.
\begin{figure}[H]\centering\includegraphics[width=\textwidth]{figuras/fig2_tasas.png}
\caption{Tasa de reingreso $<30$ días según variables clave (línea roja: promedio global).}\label{fig:tasas}\end{figure}
\begin{tablaentex}{Tasa de reingreso $<30$ días por grupo de edad.}{tab:edad}
{{INCLUIR:data/tablas/tasa_edad.tex}}
\end{tablaentex}
\begin{tablaentex}{Tasa de reingreso $<30$ días según ingresos hospitalarios previos (\cod{number\_inpatient}).}{tab:inp}
{{INCLUIR:data/tablas/tasa_inpatient.tex}}
\end{tablaentex}
\begin{tablaentex}{Tasa de reingreso $<30$ días según \cod{A1Cresult} (\cod{None}: no medida).}{tab:a1c}
{{INCLUIR:data/tablas/tasa_A1C.tex}}
\end{tablaentex}
\begin{tablaentex}{Tasa de reingreso $<30$ días según cambio de medicación (\cod{change}).}{tab:ch}
{{INCLUIR:data/tablas/tasa_change.tex}}
\end{tablaentex}
\begin{tablaentex}{Tasa de reingreso $<30$ días según uso de medicamentos para la diabetes (\cod{diabetesMed}).}{tab:dm}
{{INCLUIR:data/tablas/tasa_diabetesMed.tex}}
\end{tablaentex}

\paragraph{Diagnósticos principales.} La tabla~\ref{tab:diag} y la figura~\ref{fig:diag} muestran los diez diagnósticos principales (\cod{diag\_1}) más frecuentes. Entre ellos, la tasa de reingreso va de {{DX_786}}\,\% (786, síntomas respiratorios y del tórax) a {{DX_434}}\,\% (434, oclusión de arterias cerebrales) y {{DX_428}}\,\% (428, insuficiencia cardiaca). La tabla usa los códigos tal como vienen, como pide el enunciado. La diabetes misma (ICD-9 250.xx) no aparece porque está repartida en {{DX250_NCOD}} subcódigos. Agrupada en su categoría de tres caracteres suma {{DX250_N}} pacientes, con una tasa de {{DX250_TASA}}\,\%, y ocuparía el lugar {{DX250_POS}} del ranking.
\begin{tablaentex}{Diez diagnósticos principales más frecuentes (\cod{diag\_1}, ICD-9) y su tasa de reingreso.}{tab:diag}
{{INCLUIR:data/tablas/top10_diag1.tex}}
\end{tablaentex}
\begin{figure}[H]\centering\includegraphics[width=0.95\textwidth]{figuras/fig3_diagnosticos.png}
\caption{Diagnósticos principales y tasa de reingreso $<30$ días.}\label{fig:diag}\end{figure}

\paragraph{Tres hallazgos clave.}
\begin{enumerate}
\item \textbf{Las hospitalizaciones previas son el mayor gradiente de riesgo.} La tasa sube de {{INP_0}}\,\% sin ingresos previos a {{INP_1}}\,\%, {{INP_2}}\,\%, {{INP_3}}\,\% y {{INP_4}}\,\% con 1, 2, 3 y 4 o más ($\times${{INP_RATIO}} entre extremos). Quienes tuvieron al menos un ingreso previo son el {{PCT_PAC_PREV}}\,\% de los pacientes pero concentran el {{PCT_REING_PREV}}\,\% de los reingresos (figura~\ref{fig:tasas}, tabla~\ref{tab:inp}).
\item \textbf{El riesgo aumenta con la edad.} Entre 20 y 59 años la tasa ronda {{EDAD_2059_MIN}}--{{EDAD_2059_MAX}}\,\%; sube a {{EDAD_60_70}}\,\% a los 60--69 y a {{EDAD_70_80}}\,\% y {{EDAD_80_90}}\,\% a los 70--79 y 80--89 años. Bajo los 20 años hay pocos casos ($n={{EDADN_0_10}}$ y ${{EDADN_10_20}}$), por lo que esas tasas son inestables.
\item \textbf{El diagnóstico principal y el manejo de la diabetes separan menos que el historial.} Las variables de manejo asocian diferencias modestas (menos de 2 puntos): {{DM_Yes}}\,\% con medicación frente a {{DM_No}}\,\% sin ella; {{CH_Ch}}\,\% con cambio de medicación frente a {{CH_No}}\,\% sin cambio; y {{A1C_None}}\,\% cuando la HbA1c no se midió frente a {{A1C_MED_MIN}}--{{A1C_MED_MAX}}\,\% cuando sí. Son asociaciones, no efectos causales.
\end{enumerate}

\subsection{Modelación predictiva}\label{sec:resmodelos}
\paragraph{Partición.}\label{sec:resparticion}
La partición del enunciado, \cod{shuf --random-source=<(yes 42)}, \emph{no mezcla uniformemente}: el flujo \cod{42\textbackslash n42\textbackslash n\dots} es periódico y el {{DEC10_YES}}\,\% del conjunto de prueba proviene del último decil de \cod{diab\_clean.csv} (ordenado por \cod{encounter\_id}), cuando lo esperable es 10\,\%. Como la tasa de reingreso del último decil ({{DEC10_TASA}}\,\%) es menor que la del primero ({{DEC1_TASA}}\,\%), la prueba queda sesgada: {{ALT_TASA_TRAIN}}\,\% de reingreso en entrenamiento frente a {{ALT_TASA_TEST}}\,\% en prueba. La partición principal ({{P_TASA_TRAIN}}\,\% frente a {{P_TASA_TEST}}\,\%) usa una fuente aleatoria de calidad con la misma semilla; el entrenamiento tiene {{P_NTRAIN}} pacientes y la prueba {{P_NTEST}} (el 20\,\% son $K={{P_K}}$ pacientes). Se verificó con \cod{comm} que no hay pacientes compartidos entre ambos conjuntos.
\begin{tablaentex}{Porcentaje del conjunto de prueba proveniente de cada decil de \cod{diab\_clean.csv} con cada fuente aleatoria (esperado: 10\,\%) y tasa de reingreso del decil.}{tab:diagpart}
{{INCLUIR:data/tablas/diagnostico_particion.tex}}
\end{tablaentex}

\textbf{¿Por qué el final del archivo tiene menos reingresos?} No es una tendencia temporal general. Con \emph{todas} las hospitalizaciones la tasa se mantiene estable entre deciles ({{DECT_MIN}}--{{DECT_MAX}}\,\%, tabla~\ref{tab:compdec}); la caída aparece solo en la primera hospitalización de cada paciente. La explicación está en la ventana de observación. Los pacientes con más de una hospitalización registrada reingresan mucho más ({{VARIAS_MIN}}--{{VARIAS_MAX}}\,\% en todos los deciles) que los que tienen una sola ({{UNA_MIN}}--{{UNA_MAX}}\,\%). Un paciente que aparece por primera vez al final del período tiene menos tiempo para acumular hospitalizaciones dentro de los datos: en el último decil solo el {{OTRA_10}}\,\% tiene otra hospitalización registrada, contra {{OTRA_MIN19}}--{{OTRA_MAX19}}\,\% en los demás. Una partición que concentra la prueba en ese decil evalúa el modelo en una población distinta de la de entrenamiento.
\begin{tablaentex}{Composición por decil de \cod{encounter\_id}: tasa de reingreso con todas las hospitalizaciones y con la primera de cada paciente, hospitalizaciones registradas por paciente, \% con otra hospitalización registrada y tasa según tengan una o varias.}{tab:compdec}
{{INCLUIR:data/tablas/composicion_decil.tex}}
\end{tablaentex}

\paragraph{Desempeño en el 20\,\% de mayor riesgo.}
\begin{tablaentex}{Resultados en el conjunto de prueba (partición principal). Sensibilidad, precisión y exactitud en \%.}{tab:res}
{{INCLUIR:data/tablas/resultados_modelos.tex}}
\end{tablaentex}
El \textbf{Modelo B} captura {{P_CAP_B}} de los {{P_TOT_TEST}} reingresos de la prueba contactando al 20\,\% ({{P_SENS_B}}\,\%), con precisión {{P_PREC_B}}\,\% y \emph{lift} {{P_LIFT_B}}; el Modelo A captura {{P_SENS_A}}\,\% (\emph{lift} {{P_LIFT_A}}). La selección aleatoria captura 20\,\%: en 1000 simulaciones de selección aleatoria del 20\,\% la sensibilidad media fue {{P_AZAR_MEDIA}}\,\% (desviación estándar {{P_AZAR_DE}}; rango {{P_AZAR_MIN}}--{{P_AZAR_MAX}}\,\%). La exactitud de predecir siempre «no reingreso» es {{P_ACC_BASE}}\,\%, prácticamente igual a la de los modelos con umbral 0.5 ({{P_ACC_A}}\,\% y {{P_ACC_B}}\,\%).
\begin{figure}[H]\centering\includegraphics[width=0.62\textwidth]{figuras/fig4_ganancia.png}
\caption{Curva de ganancia acumulada en el conjunto de prueba.}\label{fig:gan}\end{figure}
\begin{tablaentex}{Intervalos de confianza del 95\,\% (\emph{bootstrap}) para sensibilidad (\%) y \emph{lift} en el 20\,\% superior, y diferencias B menos A.}{tab:bs}
{{INCLUIR:data/tablas/bootstrap_ic.tex}}
\end{tablaentex}
Estos intervalos reflejan solo la variabilidad del conjunto de prueba, con los modelos ya entrenados. No incluyen la variabilidad del entrenamiento (otra partición daría otros pesos), por lo que subestiman la incertidumbre total. La comparación con la partición del enunciado (tabla~\ref{tab:comp}) da una idea de esa otra fuente de variación.
\begin{tablaentex}{Sensibilidad de los resultados a la partición: principal frente a la del enunciado (\cod{yes 42}).}{tab:comp}
{{INCLUIR:data/tablas/comparacion_particiones.tex}}
\end{tablaentex}
Las conclusiones son cualitativamente iguales con ambas particiones (B supera a A y ambos superan al azar), pero la partición del enunciado entrega un conjunto de prueba con una tasa de reingreso distinta de la de entrenamiento, por lo que sus cifras no son directamente comparables.

\paragraph{Pesos del modelo.}
Las tablas~\ref{tab:wnum} y~\ref{tab:wtop} y la figura~\ref{fig:pesos} muestran los pesos del Modelo B: las numéricas están estandarizadas (peso por una desviación estándar) y los pesos de las variables categóricas se expresan como contraste con su categoría de referencia (la más frecuente); la interpretación se discute en la sección~\ref{sec:disc}.
\begin{tablaentex}{Modelo B: pesos de las variables numéricas (por una desviación estándar).}{tab:wnum}
{{INCLUIR:data/tablas/pesos_B_numericas.tex}}
\end{tablaentex}
\begin{tablaentex}{Modelo B: 15 mayores efectos entre variables numéricas y categorías con $n\geq300$ en el entrenamiento (categóricas relativas a la categoría de referencia, la más frecuente).}{tab:wtop}
{{INCLUIR:data/tablas/pesos_B_top15.tex}}
\end{tablaentex}
\begin{figure}[H]\centering\includegraphics[width=0.95\textwidth]{figuras/fig5_pesos.png}
\caption{Modelo B: mayores pesos (log-odds).}\label{fig:pesos}\end{figure}

\subsection{Desempeño por grupo racial}\label{sec:equidad}
La raza no es predictor de ningún modelo, pero se auditó el desempeño del Modelo B por grupo (tabla~\ref{tab:eq}, figura~\ref{fig:eq}). Con tasas de reingreso observadas de {{EQ_TASA_Caucasian}}\,\% en caucásicos y {{EQ_TASA_AfricanAmerican}}\,\% en afroamericanos, el modelo incluye en el 20\,\% de mayor riesgo al {{EQ_SEL_Caucasian}}\,\% de los caucásicos (IC 95\,\%: {{EQ_SELIC_Caucasian}}) y al {{EQ_SEL_AfricanAmerican}}\,\% de los afroamericanos (IC 95\,\%: {{EQ_SELIC_AfricanAmerican}}), una brecha {{EQ_SEL_VEREDICTO}}; captura {{EQ_SENS_Caucasian}}\,\% (IC 95\,\%: {{EQ_SENSIC_Caucasian}}) de los reingresos de los primeros frente a {{EQ_SENS_AfricanAmerican}}\,\% ({{EQ_SENSIC_AfricanAmerican}}) de los segundos, una brecha {{EQ_SENS_VEREDICTO}}. Es un chequeo exploratorio: los intervalos son de Wald y varios grupos son pequeños.
\begin{tablaentex}{Modelo B por raza en el 20\,\% de mayor riesgo (\emph{NA}: raza no informada). Intervalos de Wald al 95\,\%.}{tab:eq}
{{INCLUIR:data/tablas/equidad_raza.tex}}
\end{tablaentex}
\begin{figure}[H]\centering\includegraphics[width=\textwidth]{figuras/fig6_equidad.png}
\caption{Proporción seleccionada y sensibilidad por raza (grupos con $n\geq300$), IC 95\,\%.}\label{fig:eq}\end{figure}

\textbf{¿De dónde viene la brecha de selección?} La tabla~\ref{tab:eqcomp} compara la composición de cada grupo en las variables de mayor peso del Modelo B. El {{EQC_V70_AfricanAmerican}}\,\% de los pacientes afroamericanos tiene 70 años o más, contra {{EQC_V70_Caucasian}}\,\% de los caucásicos. Tienen algún ingreso previo el {{EQC_PREV_AfricanAmerican}}\,\% contra el {{EQC_PREV_Caucasian}}\,\%, y son dados de alta a otra institución (códigos 2, 3, 4, 5 y 22) el {{EQC_INST_AfricanAmerican}}\,\% contra el {{EQC_INST_Caucasian}}\,\%. Entre los seleccionados, la precisión es similar: {{EQC_PREC_AfricanAmerican}}\,\% (IC 95\,\%: {{EQC_PRECIC_AfricanAmerican}}) contra {{EQC_PREC_Caucasian}}\,\% ({{EQC_PRECIC_Caucasian}}), una diferencia {{EQ_PREC_VEREDICTO}}.
\begin{tablaentex}{Composición de los pacientes de prueba por raza y precisión del Modelo B entre los seleccionados (IC 95\,\% de Wald).}{tab:eqcomp}
{{INCLUIR:data/tablas/equidad_composicion.tex}}
\end{tablaentex}

% ------------------------------------------------------------------ 5
\section{Discusión}\label{sec:disc}
\paragraph{(i) ¿Qué modelo prioriza mejor y cuánto mejora respecto de la selección aleatoria?}
El Modelo B. Contactando al 20\,\% de mayor riesgo captura {{P_SENS_B}}\,\% de los reingresos frente a 20\,\% del azar, es decir, {{P_LIFT_B}} veces lo que capturaría una selección aleatoria (IC 95\,\% del \emph{lift}: {{BS_lift_B_LO}}--{{BS_lift_B_HI}}); el Modelo A llega a {{P_SENS_A}}\,\% (\emph{lift} {{P_LIFT_A}}). La ventaja de B sobre A es de {{BS_dif_sensibilidad_B_menos_A_MED}} puntos de sensibilidad (IC 95\,\%: {{BS_dif_sensibilidad_B_menos_A_LO}} a {{BS_dif_sensibilidad_B_menos_A_HI}}), con el intervalo completo sobre cero. El AUC es {{P_AUC_B}} (B) y {{P_AUC_A}} (A): hay señal útil para priorizar, pero el poder discriminativo es modesto.

\paragraph{(ii) ¿Por qué la exactitud es una métrica engañosa en este problema?}
Porque solo alrededor del {{TASA_GLOBAL}}\,\% de los pacientes reingresa: un «modelo» que siempre predice «no reingreso» logra {{P_ACC_BASE}}\,\% de exactitud sin identificar a ningún paciente de riesgo (sensibilidad 0\,\%). Los modelos A y B, con umbral 0.5, tienen {{P_ACC_A}}\,\% y {{P_ACC_B}}\,\%, prácticamente lo mismo, porque casi ninguna probabilidad supera 0.5 (solo {{P_N05_A}} y {{P_N05_B}} de {{P_NTEST}} pacientes en A y B), aunque B ordena claramente mejor. La exactitud ignora el orden y el desbalance; aquí importa la capacidad de \emph{ranking} (sensibilidad, precisión y \emph{lift} en el 20\,\% superior).

\paragraph{(iii) ¿Qué variables ponderan más y son clínicamente razonables?}
Entre las numéricas (por desviación estándar), pesa más \cod{number\_inpatient} ({{WB_number_inpatient}}), seguida de \cod{number\_diagnoses} ({{WB_number_diagnoses}}) y \cod{time\_in\_hospital} (\mbox{{{WB_time_in_hospital}}}): más hospitalizaciones previas, estadías largas y más diagnósticos (mayor complejidad clínica) aumentan el riesgo. Entre las categóricas, relativas al alta a domicilio, destacan el alta a \textbf{rehabilitación} ({{W_DC22}}), a otro tipo de \textbf{institución de cuidado} ({{W_DC5}}), a \textbf{otro hospital} ({{W_DC2}}) y a un \textbf{centro de enfermería especializada} ({{W_DC3}}), que son pacientes más frágiles; los pacientes de 10 a 19 años tienen menor riesgo (\cod{age=[10-20)}: \mbox{{{W_AGE1020}}} frente a 70--79 años), igual que quienes no usan medicación para la diabetes (\mbox{{{W_DMNO}}}); la insulina con dosis reducida (\cod{Down}) se asocia a mayor riesgo (\mbox{{{W_INSDOWN}}}). Los pesos de las numéricas (por desviación estándar) y los de las categorías (contraste con la categoría de referencia) no son directamente comparables entre sí. La mayoría de los efectos es clínicamente razonable, con dos matices. Primero, el peso de \cod{time\_in\_hospital} baja de \mbox{{{WA_time_in_hospital}}} en el Modelo A a \mbox{{{WB_time_in_hospital}}} en el B: parte de su efecto lo recoge el destino al alta, porque las estadías largas terminan más a menudo en traslado a otra institución (estadía media de {{TIH_INST}} días con alta a otra institución, contra {{TIH_CASA}} con alta a domicilio). El peso de una variable depende de qué otras incluye el modelo. Segundo, el ingreso desde un centro de enfermería especializada (\cod{admission\_source\_id=5}) tiene peso negativo (\mbox{{{W_AS5}}}), sin una explicación clínica evidente; puede reflejar cómo se registra ese origen, y no conviene interpretarlo. En todo caso son \emph{asociaciones predictivas, no causales}, y las categorías raras ($<300$ pacientes) no deben interpretarse.

\paragraph{(iv) Efecto de usar varias hospitalizaciones de un mismo paciente y cómo verificarlo.}
Se esperan resultados \textbf{optimistas}. Las hospitalizaciones de un paciente están correlacionadas (misma edad, comorbilidades e historial de ingresos), por lo que con una partición al azar por fila el mismo paciente quedaría en entrenamiento y en prueba y el modelo lo «reconocería» (fuga de información), inflando AUC, sensibilidad y \emph{lift}; además se subestimaría la incertidumbre al tratar como independientes datos que no lo son, y los pacientes con muchas hospitalizaciones quedarían sobrerrepresentados. \emph{Verificación.} Además de comprobar con \cod{comm -12} que el análisis principal no comparte pacientes entre entrenamiento y prueba (0 compartidos), se hizo el experimento directo. Con todas las hospitalizaciones tras la exclusión ({{N_TODAS}}, sin deduplicar) se entrenó el mismo Modelo B con dos particiones 70/30 que solo difieren en cómo se reparte: \emph{por fila} (cada hospitalización al azar) y \emph{por paciente} (se sortean pacientes y todas sus hospitalizaciones van al mismo lado). Los resultados están en la tabla~\ref{tab:fuga}.
\begin{tablaentex}{Modelo B con todas las hospitalizaciones: partición por fila frente a partición por paciente, y el análisis principal como referencia.}{tab:fuga}
{{INCLUIR:data/tablas/fuga_hospitalizaciones.tex}}
\end{tablaentex}
\emph{Resultado.} La fuga es real: con la partición por fila, el {{FUGA_FILA_PCOMP}}\,\% de las hospitalizaciones de prueba pertenece a pacientes que también están en entrenamiento. Pero su efecto en este modelo es pequeño: AUC {{FUGA_FILA_AUC}} contra {{FUGA_PAC_AUC}} (diferencia {{FUGA_DIF_AUC}}) y sensibilidad {{FUGA_FILA_SENS}}\,\% contra {{FUGA_PAC_SENS}}\,\% (diferencia {{FUGA_DIF_SENS}} puntos), dentro de la variación esperable de una sola partición. Una regresión logística con 17 variables generales no puede memorizar pacientes; la fuga sería mucho mayor con modelos flexibles o con variables que identifiquen al paciente. El efecto más importante es otro: \textbf{cambia la población evaluada}. La tasa de reingreso de la prueba pasa de {{P_TASA_TEST}}\,\% (por paciente) a {{FUGA_PAC_TASA}}\,\% (por hospitalización), y la precisión del 20\,\% superior de {{P_PREC_B}}\,\% a {{FUGA_PAC_PREC}}\,\%, porque los pacientes recurrentes aportan muchas filas. Esas cifras miden «hospitalizaciones contactadas» y no «pacientes contactados», y sobreestimarían lo que el programa logra por cada paciente al que llama. Por eso el análisis principal usa un registro por paciente.

\paragraph{(v) ¿Es apropiado usar la raza como predictor en un programa de seguimiento?}
No. (a) La raza es un atributo protegido: usarla para decidir a quién se contacta puede producir trato desigual y riesgo legal y ético, y su asociación con el reingreso refleja determinantes sociales (acceso, seguro, vecindario) más que biología. (b) En los datos falta en {{PCT_RAW_race}}\,\% de las hospitalizaciones y varios grupos son pequeños. (c) Aun sin raza el modelo no es neutral: como se vio en la sección~\ref{sec:equidad}, la proporción de pacientes seleccionados es menor en pacientes afroamericanos (brecha {{EQ_SEL_VEREDICTO}}) y también lo es la sensibilidad (brecha {{EQ_SENS_VEREDICTO}}); la brecha de selección coincide con diferencias de composición en las variables que más pesan (edad, ingresos previos, alta a otra institución), mientras que la precisión entre los seleccionados es similar (tabla~\ref{tab:eqcomp}). (d) Esas mismas variables pueden recoger diferencias de acceso a la atención: un menor registro de ingresos previos puede reflejar menos acceso y no menos riesgo, algo que estos datos no permiten distinguir.

\textbf{Recomendación.} No usar la raza como predictor y usarla \emph{solo para auditar}: medir periódicamente, por grupo, la proporción seleccionada, la sensibilidad y la precisión. Igualar la sensibilidad entre grupos exigiría fijar cuotas o umbrales por raza, lo que en sí mismo es usar la raza para decidir a quién se llama. Es una decisión de política, con implicancias legales y éticas, que corresponde al comité y no al modelo.

% ------------------------------------------------------------------ 6
\section{Conclusiones y recomendación al comité}
\begin{itemize}
\item \textbf{Recomendación.} Usar el \textbf{Modelo B} para priorizar el seguimiento telefónico: contactar al 20\,\% de los pacientes con mayor riesgo captura \textbf{{{P_SENS_B}}\,\%} de los reingresos a 30 días, \textbf{{{P_LIFT_B}} veces} lo que se lograría al azar.
\item \textbf{Alcance.} El AUC de {{P_AUC_B}} indica un ordenamiento solo moderado: el {{NOCAPT_B}}\,\% de los reingresos queda fuera del 20\,\% contactado. Conviene complementar el modelo con reglas simples y trazables (ingresos previos y alta a una institución de cuidado) y evaluarlo en datos más recientes.
\item \textbf{Hallazgos descriptivos.} El historial de ingresos previos y la edad avanzada son los factores más asociados al reingreso temprano; el manejo de la diabetes y los exámenes aportan asociaciones modestas, y los exámenes casi no se realizan.
\item \textbf{Equidad y privacidad.} No usar la raza como predictor, sino solo para auditar. Monitorear por grupo la proporción seleccionada, la sensibilidad y la precisión: hoy se selecciona a una menor proporción de pacientes afroamericanos, con una precisión similar. Cualquier ajuste por grupo debe decidirlo el comité de forma explícita. No distribuir los datos fuera del entorno autorizado.
\end{itemize}

\subsection*{Limitaciones}
Un solo conjunto de prueba (sin validación cruzada ni validación temporal); intervalos \emph{bootstrap} que solo recogen la variabilidad de la prueba; ventana de observación más corta para los pacientes vistos por primera vez al final del período; modelo lineal sin interacciones y sin ajuste fino de hiperparámetros; datos de 1999--2008, de un grupo de hospitales y solo con los reingresos observados en ellos; análisis restringido a la primera hospitalización de cada paciente; \cod{encounter\_id} se usa solo como proxy del orden temporal; y las diferencias por grupo racial provienen de un único conjunto de prueba con grupos pequeños.

% ------------------------------------------------------------------ 7
\section{Reproducibilidad}
Para reproducir exactamente las salidas basta ejecutar, desde la raíz del repositorio y dentro del contenedor \cod{datasciencetoolbox/dsatcl2e} (o una terminal Linux con las herramientas indicadas):
\begin{lstlisting}
git clone {{REPO_URL}} && cd {{REPO_DIR}}
bash scripts/pipeline.sh
\end{lstlisting}
El \emph{pipeline} descarga los datos, ejecuta la limpieza, el análisis exploratorio y la modelación, genera \cod{data/diab\_clean.csv}, las tablas intermedias (\cod{data/tablas}), las figuras (\cod{report/figuras}), la ficha (\cod{report/ficha.txt}), \cod{report/reporte.md} y este informe. La estructura del repositorio es:
\begin{lstlisting}[columns=fixed]
scripts/pipeline.sh     pipeline completo, comentado y en orden logico
scripts/graficos.py     figuras (matplotlib)
scripts/csv2tex.py      tablas CSV -> LaTeX
report/reporte.md.tpl   plantilla con marcadores de doble llave -> report/reporte.md
report/informe.tex.tpl  plantilla del informe -> report/informe.tex -> informe.pdf
report/figuras          figuras generadas
data/                   datos, particiones y tablas intermedias (no se versionan)
\end{lstlisting}

\clearpage
\appendix
\section{Ficha de seguimiento post-alta}
La ficha se genera con comandos a partir de \cod{data/diab\_clean.csv} y de \cod{data/test\_pred.csv} (Modelo B, partición principal), sin escribir los valores a mano:
\begin{lstlisting}
{{INCLUIR:report/ficha.txt}}
\end{lstlisting}

\section{Entorno de ejecución}\label{app:entorno}
\begin{lstlisting}
{{INCLUIR:data/tablas/entorno.txt}}
\end{lstlisting}

\end{document}
