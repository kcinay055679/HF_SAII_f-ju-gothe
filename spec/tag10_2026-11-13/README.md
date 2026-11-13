# Tag 10 · 13.11.2026 · Prometheus, Grafana, SLOs

Source: `docs/General/OneDrive_1_11-13-2026/SAII_Tag10_final.pdf`, demo stack in `docs/General/OneDrive_1_11-13-2026/tag10-grafanaprometheus/` (also as `.zip`).

## Ziel

Place Prometheus, Node Exporter and Grafana in the chain Betriebsziel → Metrik → PromQL → Dashboard → Alert. Read PromQL for reachability, load and latency, derive an SLI/SLO from an operating goal, plan a focused dashboard and an actionable alert with a runbook. Install the stack on LM2 and prove it works.

## Aufträge

1. **Testbesprechung**: the lecturer calls each person during the your-turn blocks to go through the test grade.
2. **Your turn, monitoring on LM2** (60 + 40 min). Demo stack: Docker Compose with Prometheus (9090), Node Exporter (9100), Grafana (3000), provisioned datasource, dashboard `lm2-overview.json` and two alert rules (`LM2NodeDown`, `LM2HighMemoryUsage`).
   - install Prometheus, Node Exporter and Grafana on LM2
   - show the Prometheus target `lm2-node` as UP
   - Grafana dashboard with RAM % and RAM history; create short RAM load and watch the history
   - add CPU to the dashboard and create a new alert rule
   - add one more metric to the dashboard, with an alert rule and a short runbook
   - "Erstellt einen neuen Ordner für Tag10 in eurem Projektteamszeug": evidence goes into a Tag 10 folder in the team's Teams files
3. **Projektarbeit** (40 min or until end of lesson):
   - extend the architecture / network diagram
   - define what we monitor (Kali, web service, …), split into metrics and logs
   - design a container architecture and hand it in, in the new Tag 10 folder

Reference queries from the slides and demo README:

```promql
up{job="lm2-node"}
100 * (1 - node_memory_MemAvailable_bytes{job="lm2-node"} / node_memory_MemTotal_bytes{job="lm2-node"})
100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{job="lm2-node",mode="idle"}[5m])))
histogram_quantile(0.95, sum by (le) (rate(prometheus_http_request_duration_seconds_bucket[5m])))
```

SLO example from the slides (Zeiterfassung): availability SLI = successful health checks / all checks, SLO ≥ 99.5 % per calendar month. Latency SLI = duration of a Stamp request, SLO 95 % within 500 ms.

## Abgaben

| Abgabe | Format | Who | Channel | Deadline |
| --- | --- | --- | --- | --- |
| Monitoring on LM2: evidence (target UP, dashboard with RAM + CPU + 1 more metric, alert rules, runbook) | not specified; screenshots + runbook assumed | group | Teams, new Tag 10 folder | not stated, assumed end of lesson |
| Container architecture + extended network diagram + monitoring definition (metrics & logs) | not specified; `.drawio` + PDF assumed | group | Teams, new Tag 10 folder | not stated, assumed end of lesson |

## Status

- [x] Monitoring stack running on LM2: `docker-compose.yml` at the root of the app repo runs the app (v1.5) + Prometheus + Node Exporter + Grafana, cloned to `~/SAII_Zeiterfassung` on LM2. Docker 29.1.3 from the Ubuntu repos
- [x] Targets `lm2-node`, `prometheus`, `zeiterfassung` UP (verified via API)
- [x] Screenshots (taken by Claude with headless Chromium over Tailscale, 13.11.): targets UP, dashboard under RAM + CPU load, alert `LM2NodeDown` pending → firing → resolved, dashboard afterwards. Combined in `Nachweis_Monitoring_LM2.pdf`, raw PNGs in `nachweise/`
- [x] CPU panel + alert `LM2HighCpuUsage`
- [x] Extra metric root filesystem free % + alert `LM2RootFilesystemLow` + runbook
- [x] Beyond the Auftrag: app `/metrics`, app panels (requests, 5xx, p95 of `/stamp`) and alerts `ZeiterfassungDown`, `ZeiterfassungHighErrorRate`, `ZeiterfassungSlowStamps` (latency SLO from the slides), one German runbook per alert in `monitoring/runbooks/`
- [x] Monitoring definition (SLI/SLO, metrics and logs per system incl. Kali, dashboard, alerts, open points): `Monitoring_Definition.pdf`, source `work/monitoring-definition.typ`
- [x] Runbooks for all 7 alerts: `Runbooks.pdf`, generated from `zeiterfassung/monitoring/runbooks/` by `work/runbooks-to-typst.py`
- [x] Container architecture (Ist: Compose on LM2, Ziel: Kubernetes namespaces): `.drawio` + PDF, source [`spec/diagrams/container-architektur.drawio`](../diagrams/container-architektur.drawio)
- [x] Network plan v4 (monitoring running, ports 8080/9090/9100/3000 verified lan0 → dmz0): `.drawio` + PDF
- [ ] Tag 10 folder in Teams created and filled

## Ergebnisse

[`abgaben/tag10_2026-11-13/`](../../abgaben/tag10_2026-11-13/)

- `f_you_goethe_26a_SAII_Nachweis_Monitoring_LM2.pdf` + `nachweise/*.png`: Your-turn evidence
- `f_you_goethe_26a_SAII_Monitoring_Definition.pdf`: what we monitor, metrics vs logs
- `f_you_goethe_26a_SAII_Runbooks.pdf`: one runbook per alert
- `f_you_goethe_26a_SAII_Containerarchitektur.drawio` + `.pdf`
- `f_you_goethe_26a_SAII_Netzwerkplan_v4.drawio` + `.pdf`
- nothing handed in via Teams yet

## Working files

Drafts go to [`work/`](work/).

## Erkenntnisse

- Slides install monitoring with Docker Compose on LM2, our plan has it as IaC on Kubernetes: see [LEARNINGS](../LEARNINGS.md).
- URLs (over Tailscale): Grafana `http://192.168.120.60:3000` (admin / `saii-demo`), Prometheus `http://192.168.120.60:9090/targets`, app `http://192.168.120.60:8080`.
- RAM load test from the demo README: `docker run --rm --memory=512m python:3.12-alpine python -c "import time; x=bytearray(400*1024*1024); time.sleep(120)"` on LM2. With 15 GiB RAM it moves the gauge by only ~3 %.
