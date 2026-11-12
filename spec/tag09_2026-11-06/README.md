# Tag 09 · 06.11.2026 · GitOps, CI, Monitoring

Source: `docs/General/SAII_Tag9_final.pdf`

## Ziel

Understand GitOps with Argo CD, CI vs CD, and monitoring with Prometheus, Grafana and ELK. Use that to research what the Zeiterfassung should be monitored on, update the network and data flow plans for monitoring and the new Smartlearn project environment, and start the app's Docker image.

## Aufträge

1. **Catch-up for anyone absent**: the Tag 08 Aufträge (team, plans, Ablaufplan + Git). See [tag08](../tag08_2026-10-30/README.md).
2. **Recherche**:
   - How can Kubernetes or Docker be monitored with Prometheus, Grafana and the ELK stack?
   - What would we monitor in our Zeiterfassung, and how?
   - Explain best practices so the customer understands them. Input from the slides: the golden signals latency, traffic, errors and saturation. For the Zeiterfassung that means response time, request rate, HTTP errors and CPU or DB load.
3. **Überarbeiten**:
   - adapt the network plan and the data flow plan to the new monitoring knowledge
   - research the new Smartlearn environment "Projekt SAII HS2026" and adapt the network plan to it
4. **Starten**: build the Zeiterfassung app with Docker for our image. No Abgabe.

## Abgaben

| Abgabe | Format | Who | Channel | Deadline |
| --- | --- | --- | --- | --- |
| Recherche | 1 A4 with sketch + text, **plus a video of max 2.5 min** | group, 1 person submits | Teams | end of lesson |
| Netzwerkplan + Datenflussplan, revised | `.drawio` or `.visio` (no PDF-only) | group, 1 person submits | Teams | end of lesson |
| App with Docker | – | – | – | no Abgabe |

## Status

- [~] Recherche A4 (sketch + text): draft `work/recherche-a4.pdf` (source `.typ`, sketch from `spec/diagrams/monitoring-skizze.drawio`), needs team review
- [~] Recherche video ≤ 2.5 min: script `work/video-skript.md` (~1:40), needs recording
- [x] Netzwerkplan v2, PDF only
- [x] Netzwerkplan v2 `.drawio`: recovered from the PDF metadata into [`spec/diagrams/netzwerkplan.drawio`](../diagrams/netzwerkplan.drawio)
- [~] Netzwerkplan adapted to the Smartlearn project environment: all IPs known in [NETWORK.md](../NETWORK.md), v3 can be drawn now
- [~] Datenflussplan with monitoring: [`spec/diagrams/datenflussplan.drawio`](../diagrams/datenflussplan.drawio), preview `work/datenflussplan-entwurf.pdf`, needs team review + PDF export from draw.io
- [x] App with Docker: app v1.4 has a tested multi-stage image. Port 8080 ([ADR-0006](../adr/0006-container-port-8080.md))
- [ ] Netzwerkplan v3 (firewall LF1, KL2, monitoring ports, 8080): waiting on `dmz0` IPs

## Ergebnisse

[`abgaben/tag09_2026-11-06/`](../../abgaben/tag09_2026-11-06/)

- `f_you_goethe-Netzwerkplan.drawio.pdf`: Netzwerkplan v2

## Working files

Remaining work is specified in [spec.md](spec.md). [`work/`](work/) holds drafts for this Tag (Recherche notes, video script). Final versions go to `abgaben/tag09_2026-11-06/`.

## Erkenntnisse

- The network plan source is lost, port conflict, app baseline vs requirements: see [LEARNINGS](../LEARNINGS.md).
