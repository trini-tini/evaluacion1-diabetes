
import csv
import sys

ESC = {"\\": r"\textbackslash{}", "&": r"\&", "%": r"\%", "$": r"\$", "#": r"\#", "_": r"\_",
       "{": r"\{", "}": r"\}", "<": r"\textless{}", ">": r"\textgreater{}", "^": r"\^{}", "~": r"\~{}", "[": "{[}", "]": "{]}"}
MARCA = "@@"          


def esc(s):
    return "".join(ESC.get(c, c) for c in s)


def es_num(s):
    try:
        float(s)
        return True
    except ValueError:
        return s in ("-", "")


def fmt(s):
   
    if s.isdigit() and len(s) >= 4:
        return f"{int(s):,}".replace(",", MARCA)
    return s


def menos(s):
   
    return "$-$" + s[1:] if len(s) > 1 and s[0] == "-" and es_num(s) else s


src, dst = sys.argv[1], sys.argv[2]
omitir = set(sys.argv[3:])
with open(src, newline="", encoding="utf-8") as f:
    filas = list(csv.reader(f))
enc = filas[0]
idx = [i for i, c in enumerate(enc) if c not in omitir]
cuerpo = filas[1:]
alin = ["r" if all(es_num(r[i]) for r in cuerpo) and any(r[i] not in ("", "-") for r in cuerpo) else "l" for i in idx]
with open(dst, "w", encoding="utf-8") as out:
    out.write("\\begin{tabular}{" + "".join(alin) + "}\n\\toprule\n")
    out.write(" & ".join(esc(enc[i]) for i in idx) + " \\\\\n\\midrule\n")
    for r in cuerpo:
        out.write(" & ".join(menos(esc(fmt(r[i])).replace(MARCA, r"\,")) for i in idx) + " \\\\\n")
    out.write("\\bottomrule\n\\end{tabular}\n")
