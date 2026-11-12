# Learnings

Things we noticed along the way. Newest first. Each entry names the Tag it came up on and what it affects.

## 2026-11-12 · Tag 09 · The network plan v2 source is lost

Only `f_you_goethe-Netzwerkplan.drawio.pdf` exists. Before changing the network plan again, regenerate the `.drawio` from the PDF into [diagrams/](diagrams/) and edit only that from then on. Every Abgabe gets a PDF exported from it.

## 2026-11-12 · Tag 09 · Container port 5000 vs 8080

The Ablaufplan and the submitted network plan v2 say the app listens on 5000. App v1.4 listens on 8080, and so does the Tag 6 reference app; only the Übungstest Flask app uses 5000. Pick one, write an ADR, and align the network plan or the app.

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
