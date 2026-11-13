#set page(paper: "a4", margin: (x: 1.6cm, y: 1.4cm))
#set text(font: ("Liberation Sans", "Arial"), size: 10pt, lang: "de")
#set par(leading: 0.55em, spacing: 0.8em)
#show heading.where(level: 1): it => block(above: 1.3em, below: 0.5em, text(size: 12pt, it.body))
#grid(columns: (1fr, auto),
  text(size: 15pt, weight: "bold")[Runbooks Monitoring],
  align(right + bottom, text(fill: luma(90))[Team f_you_goethe · 26a · SAII · Stand 13.11.2026]),
)
Ein Runbook ist eine kurze Schritt-für-Schritt-Anleitung: was bei einem bestimmten Alert geprüft und gemacht werden muss. Befehle gelten auf LM2 im Ordner `~/SAII_Zeiterfassung`. Quelle: App-Repo, `monitoring/runbooks/`. Das Grafana-Dashboard heisst «LM2 und Zeiterfassung».

= Runbook: LM2NodeDown

Prometheus erreicht den Node Exporter auf LM2 seit mindestens einer Minute nicht (`up{job="lm2-node"} == 0`).

1. In Prometheus unter `/targets` die Fehlermeldung beim Target `lm2-node` lesen.
2. Prüfen, ob LM2 per SSH erreichbar ist. Wenn nicht: VM-Konsole in Smartlearn öffnen.
3. Auf LM2 im Ordner `~/SAII_Zeiterfassung` mit `docker compose ps` den Zustand von `saii-node-exporter` prüfen.
4. Logs mit `docker compose logs --tail 50 node-exporter` ansehen.
5. Container mit `docker compose start node-exporter` starten.
6. Prüfen, ob der Alert auf Resolved wechselt, und die Ursache dokumentieren.

= Runbook: LM2HighMemoryUsage

Die RAM-Auslastung auf LM2 liegt seit mindestens fünf Minuten über 85 %.

1. Im Grafana-Dashboard «LM2 und Zeiterfassung» prüfen, seit wann der RAM-Verlauf steigt.
2. Auf LM2 mit `free -h` den freien Speicher prüfen.
3. Mit `top` (Taste `M`) den Prozess mit dem grössten Speicherbedarf suchen.
4. Container mit `docker stats --no-stream` kontrollieren.
5. Ursache dokumentieren. Einen fehlerhaften Prozess oder Container nur bei Bedarf kontrolliert neu starten.
6. Prüfen, ob der Alert auf Resolved wechselt.

= Runbook: LM2HighCpuUsage

Die CPU-Auslastung auf LM2 liegt seit mindestens fünf Minuten über 85 %. LM2 hat nur 1 vCPU, Last wirkt sich deshalb sofort auf alle Dienste aus.

1. Im Grafana-Dashboard prüfen, seit wann die CPU-Auslastung hoch ist.
2. Auf LM2 mit `top` den verursachenden Prozess suchen.
3. Container mit `docker stats --no-stream` kontrollieren.
4. Ursache dokumentieren.
5. Einen fehlerhaften Prozess oder Container nur bei Bedarf kontrolliert neu starten.
6. Prüfen, ob der Alert auf Resolved wechselt.

= Runbook: LM2RootFilesystemLow

Auf dem Root-Dateisystem `/` von LM2 sind seit mindestens zehn Minuten weniger als 15 % frei. Ist `/` voll, können Prometheus, Docker und die Datenbank nicht mehr schreiben.

1. Im Grafana-Dashboard prüfen, wie schnell der freie Platz sinkt (langsam = Wachstum, schnell = Fehler).
2. Auf LM2 mit `df -h /` den aktuellen Stand prüfen.
3. Grösste Verzeichnisse suchen: `sudo du -xh / --max-depth=2 | sort -h | tail -20`.
4. Docker-Belegung prüfen: `docker system df`. Ungenutzte Images mit `docker image prune` entfernen.
5. Logs prüfen: `journalctl --disk-usage`, bei Bedarf `sudo journalctl --vacuum-size=500M`.
6. Keine Daten von Prometheus, Grafana oder der Zeiterfassung löschen. Ursache dokumentieren.
7. Prüfen, ob der Alert auf Resolved wechselt.

= Runbook: ZeiterfassungDown

Prometheus erreicht die Zeiterfassung seit mindestens einer Minute nicht (`up{job="zeiterfassung"} == 0`). Mitarbeitende können nicht stempeln.

1. Im Repo-Ordner auf LM2 mit `docker compose ps zeiterfassung` den Zustand prüfen (`unhealthy`, `exited`, `restarting`).
2. Logs mit `docker compose logs --tail 100 zeiterfassung` lesen.
3. `/health` direkt prüfen: `curl -s localhost:8080/health`. Ein 503 nennt die Ursache, meist ein volles oder nicht beschreibbares `/data`.
4. Bei vollem Dateisystem zuerst das Runbook «LM2RootFilesystemLow» abarbeiten.
5. Container mit `docker compose up -d zeiterfassung` neu starten. Das Volume `zeiterfassung-data` nicht löschen.
6. Prüfen, ob der Alert auf Resolved wechselt, und die Ursache dokumentieren.

= Runbook: ZeiterfassungHighErrorRate

Mehr als 5 % der Anfragen an die Zeiterfassung enden seit mindestens fünf Minuten mit einem 5xx-Status.

1. Im Grafana-Dashboard im Panel «Zeiterfassung Fehlerquote 5xx» prüfen, seit wann die Fehler auftreten.
2. In Prometheus betroffene Endpunkte suchen: `sum by (endpoint, status) (rate(http_requests_total{job="zeiterfassung",status=~"5.."}[5m]))`.
3. Logs mit `docker compose logs --tail 200 zeiterfassung` nach Tracebacks durchsuchen.
4. `curl -s localhost:8080/health` prüfen (Datenbank und `/data`).
5. Wurde kurz vorher eine neue Version ausgerollt, auf die vorherige Version zurückgehen.
6. Prüfen, ob der Alert auf Resolved wechselt, und die Ursache dokumentieren.

= Runbook: ZeiterfassungSlowStamps

Das p95 der Stempelanfragen (`POST /stamp`) liegt seit mindestens zehn Minuten über 500 ms. Das verletzt das Latenz-SLO.

1. Im Grafana-Dashboard prüfen, ob gleichzeitig CPU oder RAM von LM2 hoch sind. LM2 hat nur 1 vCPU.
2. Wenn ja, das Runbook «LM2HighCpuUsage» oder «LM2HighMemoryUsage» abarbeiten.
3. Mit `docker stats --no-stream` prüfen, welcher Container die Last erzeugt.
4. Request-Rate im Dashboard prüfen: ungewöhnlich viele Anfragen deuten auf einen Lasttest oder Missbrauch hin.
5. Ursache dokumentieren. Die Zeiterfassung nur bei Bedarf mit `docker compose restart zeiterfassung` neu starten.
6. Prüfen, ob der Alert auf Resolved wechselt.
