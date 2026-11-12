# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Team f_you_goethe's semester project for the SAII HS2026 course (HF): the "Kundenprojekt Zeiterfassung". The goal is a time-tracking app delivered Commit-to-Alert: LM1 → Git → CI → registry → Argo CD on LM2 → Prometheus/Grafana/ELK → Alertmanager → Mattermost.

| Path | What it is | In Git |
| --- | --- | --- |
| `zeiterfassung/` | **Submodule** → `SAII_Zeiterfassung`: the app (`app/`), all cluster code (`deploy/`) and later CI (`.github/workflows/`) | as submodule pointer |
| `spec/` | Project tracking: product spec, status, learnings, glossary, ADRs, one folder per Tag | yes |
| `abgaben/` | Final results handed in to the lecturer, one folder per Tag | yes |
| `docs/` | Course material from the lecturer (slides, Aufträge, zips, videos). Read-only reference | no (`.gitignore`d) |

Two repos (ADR-0007):
- **Project repo** `git@github.com:kcinay055679/HF_SAII_f-ju-gothe.git` (this one): spec, Abgaben, diagrams.
- **App repo** `git@github.com:kcinay055679/SAII_Zeiterfassung.git`, mounted as the submodule `zeiterfassung/`. It holds the app, the IaC (Kubernetes, Argo CD, monitoring, logging, policies, backup) and CI. Argo CD on LM2 watches its `deploy/` folder.

Both repos are public. Clone with `git clone --recurse-submodules`. When changing app or IaC code: commit and push inside `zeiterfassung/` first, then commit the updated submodule pointer in the project repo.

## Project tracking (`spec/`)

Read `spec/WORKING-AGREEMENT.md` first: it describes how the user and Claude work together (workflow, conventions, what to ask for).


- `zeiterfassung-spec.md`: target product spec. Its "Baseline: app v1.4" section lists what the app has and what is missing.
- `STATUS.md`: owns the 13 work packages from the team's Ablaufplan, open Abgaben, open decisions, and a roadmap of future dates. It links to day checklists and doesn't copy them.
- `LEARNINGS.md`: dated findings, newest first, each tagged with the Tag it came up on.
- `GLOSSARY.md`: canonical terms. Use **Person / Admin / Stamp / Action / Status / LM1 / LM2 / Kali / Tag / Auftrag / Abgabe**. Avoid User, Benutzer, Buchung and Stempelung in English text.
- `adr/`: ADRs `NNNN-slug.md`. A decision that flips (e.g. adding login, or PostgreSQL) gets a new ADR that supersedes the old one, not an edit of it.
- `tagNN_YYYY-MM-DD/README.md`: one per course day from Tag 08 (project start) on. Sections: Ziel, Aufträge, Abgaben, Status checklist, Ergebnisse, Erkenntnisse. The day README owns its checklist. Drafts go into that day's `work/`.
- `diagrams/`: living `.drawio` sources for the network plan and data flow plan, revised across Tage. Each Abgabe gets a PDF export of that day's version. draw.io PDFs embed their source in the `Subject` metadata, so a "lost" `.drawio` can be recovered with `pdfinfo`.
- `NETWORK.md`: IP plan, firewall behaviour, and the known VM network problems with their fixes. Check it before touching VM networking.
- `archive/`: superseded planning docs.

Conventions:
- **Tag numbering:** follows the lecturer's slides, not the module plans (they disagree). The folder name carries the date so they can't be confused.
- **Folder pairs:** `spec/tagNN_…` and `abgaben/tagNN_…` always use the same name.
- **Future Tage:** only create a new Tag folder once that day's slides are in `docs/`.
- **When a Tag's work changes state:** update the day README checklist, `STATUS.md`, and `LEARNINGS.md` if something new was learned.
- **Language:** tracking files are in English. Anything handed in (`abgaben/`) is in German.

## App commands (`zeiterfassung/`)

Prerequisites: Docker, k3d, kubectl, make, curl. No host Python or Typst is needed; tests and docs run in containers. Host ports 8080, 8081 and 5050 must be free.

```bash
cd zeiterfassung
make test      # unit tests via the Dockerfile `test` stage (build fails if a test fails)
make cluster   # k3d registry (5050) + single-node cluster "saii"
make dev       # test, build, k3d image import, apply deploy/zeiterfassung/overlays/dev -> http://localhost:8080
make prod      # test, build, push to local registry, apply overlays/prod -> http://zeiterfassung.localhost:8081
make smoke     # stamp in dev+prod, delete all pods, verify the Stamps survived
make scan      # Trivy, HIGH/CRITICAL
make status    # pods/svc/pvc/ingress of both namespaces
make docs      # build docs/abgabe.pdf from abgabe.typ (Typst container)
make clean     # deletes cluster AND registry, all data lost
```

Single test, on the host with a venv (`pip install -r requirements.txt -r requirements-dev.txt`):

```bash
cd zeiterfassung/app && python -m pytest tests/test_app.py::test_health_reports_healthy -q
```

Render manifests without applying: `kubectl kustomize deploy/zeiterfassung/overlays/dev` (or `prod`).

`VERSION` in the Makefile, `APP_VERSION` in the Dockerfile and the image tags in the overlays must be bumped together on a release.

## App architecture

- `app/store.py` holds the domain: the Action set, the Valid transition table (`ALLOWED`, `STATUS_AFTER`), Status derivation, Worked time today (Europe/Zurich), and SQLite access under `DATA_DIR`. A Stamp's transition check and insert run in one write transaction, so concurrent replicas can't both accept the same transition.
- `app/app.py` is a Flask app factory `create_app(data_dir)`, served by gunicorn (`--workers 1 --threads 8`) on 8080. Each route answers both form posts (303 redirect) and JSON (201/200/400/404/409). `/health` writes a probe file to `/data` and queries the DB, returning 503 on failure. Probes use it.
- Tests use `create_app(tmp_path).test_client()`, so there is no cluster or real DB.
- Image: digest-pinned `python:3.13-slim`, multi-stage (build venv → test → runtime without pip), UID 10001, `/data` volume.
- `deploy/zeiterfassung/base` (deployment, service, pvc) plus overlays:
  - dev: 1 replica, NodePort 30080, imported image, ns `zeiterfassung-dev`
  - prod: 3 replicas, ClusterIP + Traefik Ingress, registry image, ns `zeiterfassung-prod`
- Prod's 3 replicas share one RWO `local-path` PVC. That only works because the cluster has a single node (ADR-0001, ADR-0002). Don't add k3d agents without changing storage.
- `deploy/README.md` lists the planned IaC folders (`argocd/`, `monitoring/`, `logging/`, `policies/`, `backup/`). CI must path-filter on `app/**`, so image-tag bumps in `deploy/` don't retrigger builds.
- The course material uses minikube. `zeiterfassung/README.md` has the minikube → k3d command mapping and the rootless Docker workarounds, which the Makefile auto-detects.

## Known gaps vs the customer requirements

The app was built for the Tag 4/5 Auftrag. The customer project still needs:
- login and an Admin area (ADR-0004 currently says no auth)
- PostgreSQL instead of SQLite
- the LM1/LM2 split
- `/metrics`, structured logs
- CI, Argo CD, NetworkPolicies
- Mattermost alerting

Container port is 8080 (ADR-0006). The submitted network plan v2 still says 5000; v3 fixes that.
