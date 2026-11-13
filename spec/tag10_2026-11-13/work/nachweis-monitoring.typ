// Compile from the repo root: typst compile --root . spec/tag10_2026-11-13/work/nachweis-monitoring.typ …
#set page(paper: "a4", margin: (x: 1.4cm, y: 1.2cm), footer: context align(right, text(size: 8pt, fill: luma(110))[Seite #counter(page).display() / #counter(page).final().first()]))
#set text(font: ("Liberation Sans", "Arial"), size: 10pt, lang: "de")
#set par(leading: 0.5em, spacing: 0.7em)
#show heading.where(level: 2): set text(size: 11.5pt)
#show heading: set block(above: 1em, below: 0.45em)
#let dir = "/abgaben/tag10_2026-11-13/nachweise/"
#let shot(file, caption, w: 100%) = figure(image(dir + file, width: w), caption: caption, supplement: [Bild])

#grid(columns: (1fr, auto),
  text(size: 15pt, weight: "bold")[Nachweis Monitoring auf LM2],
  align(right + bottom, text(fill: luma(90))[Team f_you_goethe · 26a · SAII · 13.11.2026]),
)
#v(-0.3em)
Auf LM2 (192.168.120.60) laufen Zeiterfassung, Prometheus, Node Exporter und Grafana als Docker Compose aus dem App-Repo `SAII_Zeiterfassung` (`git clone` + `make up`). Die Bilder wurden am 13.11.2026 über Tailscale aus lan0 aufgenommen. Zeiten in Schweizer Zeit.

#table(columns: (34%, 1fr, auto), inset: 4pt, stroke: 0.4pt + luma(170),
  table.header([*Auftrag*], [*Nachweis*], [*Bild*]),
  [Prometheus, Node Exporter, Grafana auf LM2 installieren], [4 Container laufen, Zeiterfassung `healthy`], [1, 2],
  [Target `lm2-node` UP], [alle drei Targets UP: `lm2-node`, `prometheus`, `zeiterfassung`], [1],
  [Dashboard mit RAM-Prozent und RAM-Verlauf, RAM-Last erzeugen], [4 GB RAM-Last per Container: RAM von ≈ 6 % auf ≈ 33 %], [2, 7],
  [CPU im Dashboard, neue Alert-Regel], [Panels CPU-Auslastung und -Verlauf, Regel `LM2HighCpuUsage` (> 85 % während 5 min)], [2, 6],
  [1 weitere Metrik, Alert-Regel, Runbook], [Root-Dateisystem frei, Regel `LM2RootFilesystemLow` (< 15 % während 10 min), Runbook im Dokument «Runbooks»], [2, 6],
  [Alert-Lebenszyklus], [Node Exporter gestoppt: `LM2NodeDown` Pending → Firing, danach gestartet → Resolved], [3–6],
  [SLO überwachen (Zusatz)], [p95 `POST /stamp` unter CPU-Last 1,36 s > 500 ms, `ZeiterfassungSlowStamps` ging auf Pending], [2, 7],
)

#shot("01_prometheus_targets_up.png", [Prometheus `/targets`: alle Targets UP])

#shot("02_grafana_dashboard_ram_cpu_last.png", [Grafana-Dashboard «LM2 und Zeiterfassung» während 4 GB RAM-Last und voller CPU-Last (zweiter Durchgang ab 14:55): RAM 32 %, CPU 74 % (Mittel über 5 min). Die p95-Dauer beim Stempeln steigt auf 1,36 s, das Latenz-SLO von 500 ms ist verletzt], w: 88%)

#shot("03_prometheus_alert_pending.png", [Node Exporter gestoppt: `LM2NodeDown` ist Pending (Wartezeit 1 min läuft)])

#shot("04_prometheus_alert_firing.png", [Nach der Wartezeit: `LM2NodeDown` ist Firing])

#shot("05_prometheus_target_down.png", [Gleichzeitig in `/targets`: `lm2-node` ist DOWN])

#shot("06_prometheus_alerts_resolved.png", [Node Exporter wieder gestartet: kein Alert mehr aktiv (Resolved), alle 7 Regeln inaktiv])

#shot("07_grafana_dashboard_nach_test.png", [Dashboard nach dem Test: zwei RAM-Spitzen, Lücke 14:51–14:53 beim Ausfall des Node Exporters, Fehlerquote 0 %. Erkenntnis: mit nur 1 vCPU bremst jede CPU-Last direkt das Stempeln], w: 88%)
