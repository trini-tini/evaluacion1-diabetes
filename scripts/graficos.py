
import csv
import os
import matplotlib
matplotlib.use("Agg")                     
import matplotlib.pyplot as plt

TAB, FIG = "data/tablas", "report/figuras"
os.makedirs(FIG, exist_ok=True)
AZUL, NARANJA, GRIS, ROJO = "#1f77b4", "#ff7f0e", "#7f7f7f", "#d62728"
plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False})


def leer(nombre):
    with open(os.path.join(TAB, nombre), newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def num(x):
    return float(x)


def miles(n):
    return f"{int(n):,}".replace(",", " ")     


dist = leer("dist_readmitted.csv")
tasa_global = next(num(r["porcentaje"]) for r in dist if r["variable"] == "Reingreso30" and r["categoria"] == "1")


def barras_tasa(ax, filas, clave, titulo, xlabel, rot=0):
    cats = [r[clave] for r in filas]
    tasas = [num(r["tasa_pct"]) for r in filas]
    ns = [int(r["n"]) for r in filas]
    b = ax.bar(cats, tasas, color=AZUL)
    ax.axhline(tasa_global, color=ROJO, ls="--", lw=1)
    for rect, t, n in zip(b, tasas, ns):
        ax.text(rect.get_x() + rect.get_width() / 2, t + 0.3, f"{t:.1f}%\nn={miles(n)}",
                ha="center", va="bottom", fontsize=7)
    ax.set_title(titulo, fontsize=10)
    ax.set_xlabel(xlabel)
    ax.set_ylabel("Reingreso < 30 días (%)")
    ax.set_ylim(0, max(tasas) * 1.28)
    plt.setp(ax.get_xticklabels(), rotation=rot, ha="right" if rot else "center")


# Figura 1: distribucion de readmitted (original vs limpia) y Reingreso30
fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 4), gridspec_kw={"width_ratios": [3, 2]})
cats = ["NO", ">30", "<30"]
orig = [next(num(r["porcentaje"]) for r in dist if r["base"] == "original" and r["variable"] == "readmitted" and r["categoria"] == c) for c in cats]
limp = [next(num(r["porcentaje"]) for r in dist if r["base"] == "limpia" and r["variable"] == "readmitted" and r["categoria"] == c) for c in cats]
x = range(len(cats))
w = 0.38
b1 = a1.bar([i - w / 2 for i in x], orig, w, label="Original (todas las hospitalizaciones)", color=GRIS)
b2 = a1.bar([i + w / 2 for i in x], limp, w, label="Limpia (1 por paciente, sin fallecidos ni hospicio)", color=AZUL)
for bars in (b1, b2):
    for r in bars:
        a1.text(r.get_x() + r.get_width() / 2, r.get_height() + 0.6, f"{r.get_height():.1f}%", ha="center", fontsize=8)
a1.set_xticks(list(x)); a1.set_xticklabels(cats)
a1.set_ylabel("% de hospitalizaciones / pacientes"); a1.set_title("readmitted (3 categorías)")
a1.legend(frameon=False, fontsize=8); a1.set_ylim(0, max(orig + limp) * 1.22)
r0 = next(num(r["porcentaje"]) for r in dist if r["variable"] == "Reingreso30" and r["categoria"] == "0")
bb = a2.bar(["0 (no)", "1 (sí)"], [r0, tasa_global], color=[GRIS, ROJO])
for r in bb:
    a2.text(r.get_x() + r.get_width() / 2, r.get_height() + 1, f"{r.get_height():.2f}%", ha="center", fontsize=9)
a2.set_title("Reingreso30 (binaria, base limpia)"); a2.set_ylim(0, 105)
fig.tight_layout(); fig.savefig(f"{FIG}/fig1_distribucion.png", dpi=160); plt.close(fig)

# Figura 2: tasa de reingreso segun variables
fig, ax = plt.subplots(2, 2, figsize=(11, 8))
barras_tasa(ax[0, 0], leer("tasa_edad.csv"), "grupo_edad", "Según grupo de edad", "Grupo de edad (años)", rot=45)
barras_tasa(ax[0, 1], leer("tasa_inpatient.csv"), "ingresos_previos", "Según ingresos hospitalarios previos (año anterior)", "number_inpatient")
barras_tasa(ax[1, 0], leer("tasa_A1C.csv"), "A1Cresult", "Según resultado de HbA1c (None = no medida)", "A1Cresult")

filas = [{"g": f"change={r['change']}", "tasa_pct": r["tasa_pct"], "n": r["n"]} for r in leer("tasa_change.csv")] + \
        [{"g": f"diabetesMed={r['diabetesMed']}", "tasa_pct": r["tasa_pct"], "n": r["n"]} for r in leer("tasa_diabetesMed.csv")]
barras_tasa(ax[1, 1], filas, "g", "Según cambio de medicación y uso de medicamentos", "", rot=30)
fig.suptitle(f"Tasa de reingreso < 30 días (línea roja: promedio global {tasa_global:.2f}%)", fontsize=11)
fig.tight_layout(); fig.savefig(f"{FIG}/fig2_tasas.png", dpi=160); plt.close(fig)

# Figura 3: diagnosticos principales
d = leer("top10_diag1.csv")[::-1]
fig, ax = plt.subplots(figsize=(10, 5))
etq = [f"{r['diag_1']}  {r['descripcion'][:50]}" for r in d]
tasas = [num(r["tasa_pct"]) for r in d]
b = ax.barh(etq, tasas, color=AZUL)
ax.axvline(tasa_global, color=ROJO, ls="--", lw=1)
for rect, r in zip(b, d):
    ax.text(rect.get_width() + 0.2, rect.get_y() + rect.get_height() / 2, f"{num(r['tasa_pct']):.1f}%  (n={miles(r['n'])})", va="center", fontsize=8)
ax.set_xlabel("Reingreso < 30 días (%)"); ax.set_xlim(0, max(tasas) * 1.35)
ax.set_title("10 diagnósticos principales (diag_1, ICD-9) más frecuentes")
fig.tight_layout(); fig.savefig(f"{FIG}/fig3_diagnosticos.png", dpi=160); plt.close(fig)

#  Figura 4: curva de ganancia acumulada
g = leer("curva_ganancia.csv")
px = [0] + [num(r["pct_contactado"]) for r in g]
fig, ax = plt.subplots(figsize=(6.5, 5))
ax.plot(px, [0] + [num(r["aleatorio"]) for r in g], color=GRIS, ls="--", label="Selección aleatoria")
ax.plot(px, [0] + [num(r["modelo_A"]) for r in g], color=NARANJA, marker="o", ms=3, label="Modelo A (numéricas)")
ax.plot(px, [0] + [num(r["modelo_B"]) for r in g], color=AZUL, marker="o", ms=3, label="Modelo B (numéricas + categóricas)")
ax.axvline(20, color=ROJO, lw=0.8, ls=":")
ax.text(21, 3, "20% contactado", color=ROJO, fontsize=8)
ax.set_xlabel("% de pacientes contactados (mayor riesgo predicho primero)")
ax.set_ylabel("% de reingresos capturados (sensibilidad)")
ax.set_title("Curva de ganancia acumulada (conjunto de prueba)")
ax.legend(frameon=False); ax.set_xlim(0, 100); ax.set_ylim(0, 100)
fig.tight_layout(); fig.savefig(f"{FIG}/fig4_ganancia.png", dpi=160); plt.close(fig)

# Figura 5: pesos del Modelo B 
p = leer("pesos_B_top15.csv")[::-1]
fig, ax = plt.subplots(figsize=(10, 5.5))
etq = []
for r in p:
    etq.append(r["variable"] if r["nivel"] == "" else f"{r['variable']} = {r['nivel']}  (vs {r['referencia']})")
vals = [num(r["peso"]) for r in p]
ax.barh(etq, vals, color=[ROJO if v > 0 else AZUL for v in vals])
ax.axvline(0, color="black", lw=0.6)
ax.set_xlabel("Peso en la regresión logística (log-odds)")
ax.set_title("Modelo B: 15 mayores efectos (categorías con n ≥ 300 en entrenamiento)")
fig.tight_layout(); fig.savefig(f"{FIG}/fig5_pesos.png", dpi=160); plt.close(fig)

# Figura 6: equidad por raza
e = [r for r in leer("equidad_raza.csv") if int(r["n"]) >= 300]
fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 4))
for ax, col, ic, tit, ref in ((a1, "pct_seleccionado", "ic95_seleccionado", "% del grupo seleccionado en el 20% de mayor riesgo", 20),
                              (a2, "sensibilidad_pct", "ic95_sensibilidad", "% de reingresos del grupo capturados", None)):
    nombres = [r["raza"] for r in e]
    v = [num(r[col]) for r in e]
    lo = [num(r[ic].split("-")[0]) for r in e]
    hi = [num(r[ic].split("-")[1]) for r in e]
    ax.bar(nombres, v, yerr=[[a - b for a, b in zip(v, lo)], [b - a for a, b in zip(v, hi)]], color=AZUL, capsize=3)
    if ref:
        ax.axhline(ref, color=ROJO, ls="--", lw=1)
    ax.set_title(tit, fontsize=9); ax.set_ylim(0, min(100, max(hi + [ref or 0]) * 1.1))
    plt.setp(ax.get_xticklabels(), rotation=30, ha="right")
fig.suptitle("Modelo B (sin raza como predictor): desempeño por grupo racial, IC 95%", fontsize=10)
fig.tight_layout(); fig.savefig(f"{FIG}/fig6_equidad.png", dpi=160); plt.close(fig)

print("figuras escritas en", FIG, ":", ", ".join(sorted(os.listdir(FIG))))
