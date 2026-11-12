# Project status

Last updated: 2026-11-12

This file owns the project work packages. Each Tag's own checklist lives in its `tagNN_…/README.md`; this file only links to it.

## Work packages

From the team's Grober Ablaufplan (Tag 8). Status: ✅ done · 🟡 partial · ⬜ open

| Nr. | Work package | Status | Where we stand |
| --- | --- | --- | --- |
| 01 | Anforderungen & Planung | ✅ | Ablaufplan submitted on Tag 8, [spec](zeiterfassung-spec.md) written |
| 02 | Git-Repository aufbauen | 🟡 | GitHub `HF_SAII_f-ju-gothe` with the app history imported. Team members still need write access |
| 03 | LM1 vorbereiten | 🟡 | k3d + registry setup works locally. No PostgreSQL, not yet set up on the actual LM1 |
| 04 | Zeiterfassung entwickeln | 🟡 | App v1.4 (Persons, Actions, Status board). Missing: login, Admin area, PostgreSQL, `/metrics`, structured logs |
| 05 | Lokal testen | 🟡 | Unit tests + smoke test exist. No Kali GUI/security tests |
| 06 | Push/Pull & CI aufbauen | ⬜ | |
| 07 | Images in Registry speichern | 🟡 | Local k3d registry only, no shared registry |
| 08 | LM2 / Kubernetes bereitstellen | ⬜ | LM2 is in the wrong subnet and has no internet yet. Fix in [NETWORK.md](NETWORK.md) |
| 09 | Deployment durchführen (Argo CD) | ⬜ | |
| 10 | Kundenseitige Tests | ⬜ | |
| 11 | Monitoring einrichten | ⬜ | |
| 12 | Alerting & Mattermost | ⬜ | |
| 13 | Gesamttest & Übergabe | ⬜ | |

## Open Abgaben

| Tag | Abgabe | Details |
| --- | --- | --- |
| 08 | Datenflussplan (draft done, covered by the Tag 09 one) | [tag08](tag08_2026-10-30/README.md) |
| 08 | Netzwerkplan v1 as `.drawio` + PDF (only the photo exists) | [tag08](tag08_2026-10-30/README.md) |
| 09 | Recherche: A4 drafted, video scripted (needs recording) | [tag09](tag09_2026-11-06/README.md) |
| 09 | Datenflussplan `.drawio`: drafted, needs review + export | [tag09](tag09_2026-11-06/README.md) |
| 09 | Netzwerkplan v3 `.drawio`: v2 source recovered, v3 waits on `dmz0` IPs | [tag09](tag09_2026-11-06/README.md) |

## Open decisions

- Cluster on LM1/LM2: k3d (ADR-0001) vs whatever the Smartlearn project environment provides.
- Registry product, and whether Argo CD on LM2 can reach GitHub.
- ELK vs Loki for logs, depends on LM2 memory.

## Roadmap

The two module plans disagree, and the slides number days differently again. Dates are reliable, numbers are not. A `tagNN_…` folder is only created once that day's slides are there.

| Date | Modulplan SAII HS2026 | Modulplan A&C (topic) |
| --- | --- | --- |
| 13.11.2026 | Integration Mattermost in ELK (remote) | Metrics, SLOs & Grafana: 3 PromQL queries, dashboard, SLO, test alert |
| 20.11.2026 | Save your Integration (ZeroTrust), Abgabe Härtungsmassnahmen | Logs, Traces & Correlation: saved search, root-cause timeline |
| 27.11.2026 | Rückblick Härtung, Härtung implementieren (remote) | Incident Response & Mattermost: down → Mattermost → resolved, incident report, runbook |
| 04.12.2026 | Test 2 / Reserve | Policy-as-Code & Resilience: policy, restore, risk list |
| 11.12.2026 | Weihnachtsapéro | Test 2 & Projekt-Gate (RAG status) |
| 18.12.2026 | Finaler Input Dokumentation (remote) | Dokumentation & Übergabe, cross-team test |
| 09.01.2027 | Abgabe Projekt | Projektabgabe, live acceptance + failure challenge |
| 16.01.2027 | Abschluss, Notenrückgabe | Abschluss & Transfer |
