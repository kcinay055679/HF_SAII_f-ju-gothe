# Learnings

Things we noticed along the way. Newest first. Each entry names the Tag it came up on and what it affects.

## 2026-11-12 · Tag 09 · The LMs have only 1 vCPU

LM1 and LM2 have 1 vCPU, 15 GiB RAM, 63 GB disk each. The full stack on LM2 (Kubernetes, Argo CD, Prometheus, Grafana, ELK, app) will be CPU-bound. Prefer lightweight choices (k3s, Loki over ELK, small replica counts), or ask the lecturer for more vCPUs.

## 2026-11-12 · Tag 09 · The VM gateway is LF1 on .4, not .1 or .2

No VM had internet because every one pointed at a gateway that doesn't exist (.1 from the banner, .2 from the Kali guide). LF1 answers on 192.168.110.4 and 192.168.120.4. Also, both Ubuntu VMs had 192.168.110.60, so LM2 sits in the wrong zone. Problem, fix and IP plan: [NETWORK.md](NETWORK.md).

## 2026-11-12 · Tag 09 · The Smartlearn environment has a firewall and a DMZ

The lecturer's Smartlearn plan has three zones: `lan0` (LM1, KL1), `dmz0` (LM2, KL2) and `wan0`. Firewall `if229-vmLF1` connects them. Network plan v2 drew no firewall and no KL2. Every cross-zone flow (LM1 → GitHub, LM2 → GitHub/registry, KL1 → LM2) needs an opening on LF1. The IPs are not on the plan. Details: [tag09 work](tag09_2026-11-06/work/smartlearn-umgebung.md).

## 2026-11-12 · Tag 09 · draw.io PDFs carry their own source

The network plan v2 "source" wasn't lost. draw.io embeds the diagram XML, URL-encoded, in the PDF's `Subject` metadata (`pdfinfo` shows it). It was recovered unchanged into [diagrams/netzwerkplan.drawio](diagrams/netzwerkplan.drawio). Keep exporting with "include a copy of my diagram" so this keeps working.

## 2026-11-12 · Tag 09 · Container port 5000 vs 8080, decided: 8080

The Ablaufplan and network plan v2 said 5000, but app v1.4 and the Tag 6 reference use 8080. Decided 8080 ([ADR-0006](adr/0006-container-port-8080.md)), and the plans follow.

## 2026-11-12 · Tag 09 · The app baseline contradicts the customer requirements

App v1.4 was built for the Tag 4/5 Auftrag: no login (ADR-0004), SQLite (ADR-0002), single k3d cluster (ADR-0001). The Tag 9 customer requirements need login, an Admin area and the LM1/LM2 split, and the team plans say PostgreSQL. Those ADRs get superseded, not edited.

## 2026-11-12 · Tag 09 · The Status board shows everyone

The Status board lists every Person's Status. With login, decide whether a Person still sees the others' Status (presence board) or only their own Stamps. The spec currently says Notes and Stamps of others stay private; Status of others is undecided.

## 2026-11-12 · Tag 08 / 09 · Day numbers differ between slides and module plans

The slides call 06.11 "Tag 9", both module plans call it Tag 10, and the two module plans disagree on topics. Folders follow the slides plus the date. Tag 8 = 30.10.2026 is inferred from the timestamp on the Netzwerkplan v1 photo.

## 2026-11-06 · Tag 09 · Recap test traps worth remembering

- A locally built image is not in the cluster node until it is loaded (`minikube image load`, `k3d image import`).
- `Running` with `0/1 Ready`: check readiness probe path, pod events and the real health endpoint first.
- `targetPort` must match the port the app actually listens on.
- A `Bound` PVC is not persistence. The proof is: write a Stamp, delete the pod, find the Stamp in the new pod.
- Kustomize: one base, overlays only hold the differences. Render both without deploying.
- CI builds and checks; Argo CD deploys from Git. A manual cluster fix shows up as drift and gets reverted; the lasting fix goes through Git.
