"""Turn the runbooks in zeiterfassung/monitoring/runbooks/*.md into one Typst file."""
import re
import sys
from pathlib import Path

ORDER = ["lm2-node-down", "lm2-high-memory", "lm2-high-cpu", "lm2-root-filesystem-low",
         "zeiterfassung-down", "zeiterfassung-errors", "zeiterfassung-slow-stamps"]
src, out = Path(sys.argv[1]), Path(sys.argv[2])

head = """#set page(paper: "a4", margin: (x: 1.6cm, y: 1.4cm))
#set text(font: ("Liberation Sans", "Arial"), size: 10pt, lang: "de")
#set par(leading: 0.55em, spacing: 0.8em)
#show heading.where(level: 1): it => block(above: 1.3em, below: 0.5em, text(size: 12pt, it.body))
#grid(columns: (1fr, auto),
  text(size: 15pt, weight: "bold")[Runbooks Monitoring],
  align(right + bottom, text(fill: luma(90))[Team f_you_goethe · 26a · SAII · Stand 13.11.2026]),
)
Ein Runbook ist eine kurze Schritt-für-Schritt-Anleitung: was bei einem bestimmten Alert geprüft und gemacht werden muss. Befehle gelten auf LM2 im Ordner `~/SAII_Zeiterfassung`. Quelle: App-Repo, `monitoring/runbooks/`. Das Grafana-Dashboard heisst «LM2 und Zeiterfassung».
"""
parts = [head]
for name in ORDER:
    for line in (src / f"{name}.md").read_text().splitlines():
        line = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"«\1»", line)
        line = line.replace("@", "\\@").replace("$", "\\$")
        if line.startswith("# "):
            line = "= " + line[2:]
        elif line and not re.match(r"\d+\. ", line):
            line = line.replace("*", "\\*")
        parts.append(line)
    parts.append("")
out.write_text("\n".join(parts))
