# Spec: Kundenprojekt Zeiterfassung (Team f_you_goethe)

Sources: SAII Tag 9 slides (Projektauftrag, GitOps, CI, Monitoring), both SAII HS2026 module plans, Team f_you_goethe "Grober Ablaufplan" (Tag 8), Netzwerkplan v1 (hand sketch) and v2 (drawio), the reference Zeiterfassung on Minikube (Tag 6) and the SAII Übungstest.

Terms follow [GLOSSARY.md](GLOSSARY.md) (Person, Admin, Stamp, Action, Status, LM1, LM2, Kali, Commit-to-Alert). Machine facts: LM1 is `li264-vmLM1`, 192.168.110.60 in the Entwicklungsnetz 192.168.110.0/24; LM2 sits in the Kundennetz 192.168.200.0/24; Kali is `li261-vmKL1`. "Zentrale Dienste" means Git repository, CI pipeline and container registry.

## Baseline: app v1.4

The app in `zeiterfassung/` (built for the Tag 4/5 Kubernetes Auftrag) is the starting point. It already has:

- Flask + gunicorn, Persons picked from a list, Actions EIN / PAUSE / ZURUECK / AUS with Valid transitions, optional Note, Status board with Worked time today
- JSON and form API, `/health` checking volume and database
- SQLite on a PVC, persistence proven by a smoke test that deletes every pod
- digest-pinned multi-stage image, unit tests in a Dockerfile `test` stage, Trivy scan
- Kustomize base with dev (1 replica, NodePort) and prod (3 replicas, Ingress, registry image) overlays on a single-node k3d cluster
- ADR-0001 to ADR-0005 in [adr/](adr/), AI decision log

Gaps against this spec (each needs work and, where a decision flips, a new ADR that supersedes the old one):

- no login and no Admin area (ADR-0004 says no auth): customer requirement, must change
- SQLite instead of PostgreSQL (ADR-0002): must change
- k3d on one machine instead of the LM1 / LM2 split (ADR-0001): to decide once the Smartlearn project environment is known
- no `/metrics`, no structured logs, no tracing
- no CI pipeline, no SBOM, no Argo CD, no NetworkPolicy, no read-only root filesystem, no Mattermost alerting
- listens on 8080, the team plans say 5000: open decision, see [LEARNINGS.md](LEARNINGS.md)

## Problem Statement

The customer needs a working time-tracking service that their staff can use from a browser, and they need to trust that it keeps running. Today they have nothing: no place for staff to clock in and out, no overview for the admin, and no way for an operations team to find out that the service is down before staff complain.

From the engineering team's side, the problem is delivering that service in a reproducible, auditable way: every change must go from a developer machine to the customer environment without manual cluster edits, the running system must be observable, and failures must reach the operations team as clear, actionable alarms in Mattermost. The result has to survive a live acceptance with an injected failure, and a foreign team must be able to operate it from the documentation alone.

## Solution

A small Zeiterfassung web application, packaged as a hardened container image, delivered through a GitOps platform chain into a Kubernetes cluster on LM2:

- Persons log in over HTTPS and stamp EIN, PAUSE, ZURUECK and AUS. Stamps are stored durably in PostgreSQL and survive pod restarts.
- Admins see all recorded times in an Admin area.
- Git is the single source of truth for code, image definition and deployment configuration. CI builds, tests, generates an SBOM, scans and pushes a versioned image. Argo CD deploys from Git to LM2 and reports Synced/Healthy/OutOfSync.
- Prometheus collects metrics (golden signals of the app plus Kubernetes/infrastructure), Grafana shows a focused dashboard, the ELK stack makes logs searchable, OpenTelemetry carries shared service/pod/namespace context.
- Alertmanager routes alerts (firing and resolved) through a protected webhook into a Mattermost channel, with service, state, time and runbook link.
- The platform is hardened (least privilege, non-root, network boundaries, policies) and recoverable (backup/restore with stated RTO/RPO), and documented as a runbook.

## User Stories

### Person

1. As a Person, I want to log in with my own username and password, so that my Stamps are attributed to me.
2. As a Person, I want to stamp EIN with one click, so that recording my start time costs no effort.
3. As a Person, I want to stamp AUS with one click, so that my working day is closed correctly.
4. As a Person, I want to stamp PAUSE and ZURUECK, so that breaks are not counted as working time.
5. As a Person, I want to see my own recent Stamps after stamping, so that I can confirm the stamp was recorded.
6. As a Person, I want the server, not my browser, to set the timestamp, so that times cannot be faked from the client.
7. As a Person, I want to be prevented from stamping an Action that is not a Valid transition from my Status, with a clear message, so that my records stay consistent.
8. As a Person, I want my Stamps to still be there after the system restarts or a pod is replaced, so that I never lose recorded time.
9. As a Person, I want to log out, so that nobody else can stamp on my behalf on a shared machine.
10. As a Person, I want to reach the app only over HTTPS, so that my password is not sent in clear text.
11. As a Person, I want a clear error page instead of a stack trace when something fails, so that I know to retry or contact support.
12. As a Person, I want to be unable to see other Persons' Stamps and Notes, so that their data stays private.

### Admin

13. As an admin, I want a separate Admin area that only admin accounts can open, so that personal data is not exposed to normal users.
14. As an admin, I want to see all Stamps of all users with user, action and time, so that I can check working hours.
15. As an admin, I want to filter the overview by user and by date, so that I can find a specific person's day quickly.
16. As an admin, I want times shown in local time (Europe/Zurich) while stored in UTC, so that the display is readable and the data unambiguous.
17. As an admin, I want to create user accounts (or have them seeded via configuration), so that new Persons can start using the system.
18. As an admin, I want non-admin users to receive "forbidden" when they call admin URLs directly, so that access control is not only hidden in the UI.

### Customer (Kunde / Abnahme)

19. As the customer, I want a working Zeiterfassung reachable on LM2, so that I can accept the delivery.
20. As the customer, I want a documented acceptance test (login, stamp, persistence, admin view, monitoring visible, test alarm in Mattermost), so that acceptance is objective.
21. As the customer, I want a short explanation of what is monitored and why, so that I understand what the operations team watches.
22. As the customer, I want the database not to be reachable from outside the cluster, so that our time data is protected.
23. As the customer, I want a backup and a demonstrated restore with stated RTO/RPO, so that I know how much data could be lost and how fast service returns.

### Developer (Engineer on LM1)

24. As a developer, I want to run the app and PostgreSQL locally on LM1 with one command, so that I can develop without the customer cluster.
25. As a developer, I want the same image to run on LM1 and LM2, configured only through environment variables and Secrets, so that "works on LM1" means "works on LM2".
26. As a developer, I want a shared Git repository holding app code, Dockerfile, Kubernetes manifests and Argo CD config, so that everything needed to rebuild the system is versioned.
27. As a developer, I want CI to run automatically on push, so that broken changes are caught before they reach the customer.
28. As a developer, I want CI to run the HTTP-level test suite against a freshly built image, so that the image itself is tested, not just the source.
29. As a developer, I want CI to generate an SBOM and run a vulnerability scan that fails the build on critical findings, so that there is at least one tested security gate.
30. As a developer, I want images pushed to the registry with an immutable version tag (never `latest`), so that every deployment is traceable to a commit.
31. As a developer, I want to release by changing the image tag in the Git manifests/values, so that CI and CD stay separated.
32. As a developer, I want Kustomize (or Helm) base plus dev/prod overlays, so that I maintain one set of manifests with only the differences per environment.
33. As a developer, I want manifests to render cleanly (kustomize build / helm template / lint) in CI, so that broken YAML never reaches Argo CD.
34. As a developer, I want each team member to be able to rebuild the full setup in their own environment, so that the project meets the "jeder baut nach" rule.

### Tester (Kali)

35. As a tester, I want to reach the app's GUI from Kali, so that I can do browser-based functional tests.
36. As a tester, I want to run a port scan (Nmap) against LM2, so that I can verify only intended ports (HTTPS) are exposed.
37. As a tester, I want to try basic attacks (unauthenticated admin access, SQL injection in login, missing CSRF protection), so that obvious security gaps are found before acceptance.
38. As a tester, I want documented test results, so that the customer sees evidence, not claims.

### Operator (Betriebsteam / Platform)

39. As an operator, I want Argo CD to show whether the cluster matches Git (Synced) and whether the app runs (Healthy), so that I know the state at a glance.
40. As an operator, I want manual cluster changes to show as OutOfSync and be reverted by sync, so that drift is visible and the fix goes through Git.
41. As an operator, I want to roll back by reverting a commit, so that recovery from a bad release is fast and auditable.
42. As an operator, I want startup, readiness and liveness probes on the app, so that Kubernetes only routes traffic to healthy pods and restarts hung ones.
43. As an operator, I want resource requests and limits on every workload, so that one component cannot starve the others on LM2.
44. As an operator, I want 1 replica in dev and 2 replicas in prod, so that prod survives a single pod failure.
45. As an operator, I want the app to expose a Prometheus `/metrics` endpoint with request count, error count and latency histograms, so that I can measure the golden signals.
46. As an operator, I want Prometheus to also scrape Kubernetes and node metrics (pod restarts, CPU, memory, PVC usage, PostgreSQL), so that saturation and infrastructure problems are visible.
47. As an operator, I want a focused Grafana dashboard with latency, traffic, errors and saturation for the Zeiterfassung, so that I can judge the service health in seconds.
48. As an operator, I want at least three documented PromQL queries (up, request rate, latency/error rate), so that the dashboard and alerts are explainable.
49. As an operator, I want an SLO (e.g. availability and latency target) with a matching alert, so that alerts reflect user impact, not noise.
50. As an operator, I want an alert when the Zeiterfassung is unreachable, so that downtime is noticed before users complain.
51. As an operator, I want alerts for high error rate, high latency, crash-looping pods and the database being down, so that the common failure modes are covered.
52. As an operator, I want alert messages in Mattermost to contain service, severity, state, start time and a runbook link, so that whoever reads it knows what to do.
53. As an operator, I want a "resolved" message in Mattermost when the problem is gone, so that I know the incident is over.
54. As an operator, I want the Mattermost webhook URL stored as a Secret, not in Git in plain text, so that nobody outside the team can post fake alarms.
55. As an operator, I want structured (JSON) application logs with timestamp, severity, user action, request path, status and trace ID, so that logs are searchable in ELK and correlate with metrics and traces.
56. As an operator, I want logs enriched with pod, namespace and service attributes (via OpenTelemetry / log shipper), so that I can tell which instance produced an error.
57. As an operator, I want a saved search in Kibana for app errors, so that I can start an investigation in one click.
58. As an operator, I want to reconstruct a root-cause timeline from metric, log and trace for a controlled failure, so that incidents can be explained afterwards.
59. As an operator, I want a runbook per alert, so that a foreign person can diagnose and fix the typical failures.
60. As an operator, I want a systematic diagnosis path (get pods/svc → describe → logs → service ports → port-forward + curl /health), so that troubleshooting is reproducible.

### Security / Hardening

61. As a security reviewer, I want the app container to run as non-root with read-only root filesystem, no privilege escalation and all capabilities dropped, so that a compromised app has minimal power.
62. As a security reviewer, I want a dedicated ServiceAccount per workload with least-privilege RBAC (verified with `kubectl auth can-i`), so that tokens cannot be abused cluster-wide.
63. As a security reviewer, I want NetworkPolicies so that only the app may reach PostgreSQL on 5432 and only the ingress may reach the app, so that trust boundaries in the Netzwerkplan are enforced.
64. As a security reviewer, I want DB credentials and app secrets in Kubernetes Secrets, never in images or Git in clear text, so that a leaked repo does not leak the database.
65. As a security reviewer, I want passwords stored as salted hashes, so that a DB dump does not reveal user passwords.
66. As a security reviewer, I want a policy engine (Kyverno or OPA Gatekeeper) rejecting `latest` tags, privileged pods and workloads without resources, so that risky configuration is blocked automatically.
67. As a security reviewer, I want documented hardening measures (Zero Trust session), so that the customer can follow what was done and why.

### Documentation / Handover

68. As a foreign team, I want a runbook covering setup, deployment/GitOps, telemetry, security, backup/restore, known issues and escalation, so that I can operate the system without asking the authors.
69. As the lecturer, I want an up-to-date Netzwerkplan (IPs, ports, protocols, trust boundaries, component placement on LM1/LM2) and Datenflussplan (commit to alert, plus login, stamping, access), so that the architecture is reviewable.
70. As the lecturer, I want ADRs for key decisions (e.g. ADR-001), so that the reasoning behind technology choices is recorded.
71. As the team, I want a live demo script for the acceptance (commit, build/scan, GitOps deploy, service, telemetry, Mattermost, recovery), so that the live acceptance runs without improvisation.

## Implementation Decisions

### Application (Zeiterfassung service)

- Single web service, server-rendered HTML (no SPA). Python, following the course prior art (Flask in the Übungstest, stdlib HTTP server in the Tag 6 reference). Flask preferred for sessions, forms and the Prometheus client integration.
- Container port: team plans say 5000, baseline app uses 8080 (open, see LEARNINGS). The Service maps 80 → container port; Ingress terminates TLS on 443.
- HTTP interface (the main contract, also the test seam):
  - `GET /login`, `POST /login`, `POST /logout`
  - `GET /` – own stamping page with own recent Stamps (auth required)
  - `POST /stamp` – body `action` ∈ {`EIN`, `PAUSE`, `ZURUECK`, `AUS`} plus optional Note; the Person comes from the session, not the body; server sets UTC timestamp; form post redirects (303), JSON returns 201, invalid transition 409
  - `GET /admin` – all Stamps, filter by user and date (admin role required; 403 otherwise)
  - `GET /health`, `GET /live` – process alive; `GET /ready` – ready only when the database is reachable
  - `GET /metrics` – Prometheus exposition format
- Roles: `person` and `admin`. Initial admin and users seeded from a Secret at startup (no self-registration).
- Session cookie: HttpOnly, Secure, SameSite; CSRF token on all POST forms.
- Valid transitions as in the baseline: OUT → EIN → WORKING → PAUSE → ON BREAK → ZURUECK → WORKING → AUS → OUT; anything else is rejected with a user-facing message.
- Configuration exclusively via environment variables (DB host, port, name, user, password from Secret, session secret, log level, timezone for display).
- Logs: one JSON object per line on stdout (timestamp, level, message, user, action, path, status, duration, trace_id). No log files inside the container.
- Metrics: request counter by path/method/status, request duration histogram, stamping counter by action, DB-up gauge.
- Tracing: OpenTelemetry instrumentation exporting OTLP to the in-cluster collector; trace ID also written into the logs.

### Data model (PostgreSQL)

- `persons`: id, name (unique, case-insensitive), password_hash, role (`person` | `admin`), created_at.
- `stamps`: id, person_id (FK), action, note, occurred_at (timestamptz, UTC).
- Schema created by an idempotent migration at app startup (or init job). No ORM requirement.
- DB port 5432, reachable only inside its environment (Docker network on LM1, cluster-internal Service on LM2).

### Container image

- Multi-stage build, slim pinned base image, pinned dependency versions.
- Runs as UID 10001 (same as reference app), compatible with read-only root filesystem (writable `/tmp` via emptyDir only).
- Tagged with an immutable version (semver and/or short commit SHA). `latest` is never deployed.
- SBOM generated per build; Trivy (or Docker Scout) scan as a gate (fail on CRITICAL).

### Repository layout (logical, not paths)

- Application source and tests.
- Image definition.
- Local dev setup for LM1 (Compose: app + PostgreSQL).
- Kubernetes manifests: Kustomize base (namespace, app Deployment, Service, Ingress, ServiceAccount/RBAC, NetworkPolicies, PostgreSQL StatefulSet + PVC) and overlays `dev` (1 replica, Minikube on LM1) and `prod` (2 replicas, LM2).
- Argo CD Application definition pointing at the prod overlay.
- Monitoring configuration: scrape config/ServiceMonitor, alert rules, Alertmanager route + Mattermost receiver, Grafana dashboard as JSON, OTel collector values.
- Docs: Netzwerkplan, Datenflussplan, ADRs, runbooks, test evidence.

### CI pipeline

- Trigger: push / merge to main.
- Stages: lint + unit/HTTP tests → image build → run HTTP test suite against the built image with a throwaway PostgreSQL → SBOM → vulnerability scan (gate) → push to registry → render manifests (`kustomize build` / `helm lint`+`template`).
- CI never deploys to LM2. A release is a commit that bumps the image tag in the prod overlay (by hand or by a CI job committing to Git). Argo CD syncs.
- CI runner and registry type are still open (school GitLab/Gitea + built-in registry, or GitHub + GHCR); must be reachable from LM2 over HTTPS 443.

### Kubernetes on LM2

- Single-node cluster (Minikube or k3s, matching what the Smartlearn environment provides).
- Namespaces: `zeiterfassung` (app + DB), `monitoring` (Prometheus, Grafana, Alertmanager, OTel collector), `logging` (ELK or log shipper), `argocd`.
- App Deployment: startup/readiness/liveness probes on `/health`, `/ready`, `/live`; requests/limits; securityContext as in the reference app plus read-only root filesystem.
- PostgreSQL as StatefulSet with PVC; credentials from Secret; not exposed outside the cluster.
- Ingress with TLS (self-signed or internal CA) on 443; only HTTPS exposed to Persons/Kali.
- NetworkPolicies: default deny in `zeiterfassung`; allow ingress-controller → app port; app → db:5432; Prometheus → app `/metrics`; app → OTel collector; DNS egress.
- RBAC: app ServiceAccount without API permissions (token not mounted); a read-only `support` ServiceAccount (pods, pods/log: get/list/watch) like the reference.

### GitOps (Argo CD)

- One Argo CD Application for the Zeiterfassung (prod overlay), auto-sync with self-heal and prune.
- Monitoring stack also managed via Argo CD where practical, otherwise Helm installs documented in the runbook.
- Drift demonstration: manual `kubectl scale`/edit → OutOfSync → restored by sync; permanent fix only via Git commit.

### Monitoring, logging, alerting

- Prometheus (kube-prometheus-stack via Helm) scraping app `/metrics`, kube-state-metrics, node exporter, PostgreSQL exporter.
- Golden signals for the Zeiterfassung: latency (p95 request duration), traffic (request rate), errors (5xx rate), saturation (CPU/memory vs limits, DB connections, PVC usage).
- SLO: e.g. 99 % of requests successful and p95 < 500 ms over 30 days (exact numbers recorded in an ADR).
- Alert rules (each with runbook link): `ZeiterfassungDown` (up == 0 / no ready endpoints), `HighErrorRate`, `HighLatency`, `PodCrashLooping`, `PostgresDown`, `PVCAlmostFull`. All must exercise Pending → Firing → Resolved and No Data handling.
- Alertmanager → Mattermost incoming webhook (HTTPS 443), webhook URL as Secret; `send_resolved: true`; message template: service, severity, state, start time, summary, runbook URL.
- Mattermost runs on LM2 (or as provided by the course); a dedicated channel for the Betriebsteam.
- Logs: app stdout → shipper (Filebeat/Fluent Bit or OTel collector) → Elasticsearch → Kibana, enriched with pod/namespace/service. Grafana may show logs too if Loki is chosen instead (module plan allows Loki or existing Elastic; team plan says ELK).
- OpenTelemetry Collector via Helm, receiving OTLP, adding Kubernetes attributes (k8sattributes processor), exporting traces (Tempo or compatible) and optionally metrics/logs.

### Network

- Entwicklungsnetz 192.168.110.0/24: LM1 (192.168.110.60), Kali.
- Kundennetz 192.168.200.0/24: LM2.
- Zentrale Dienste: Git, CI, registry (location depends on Smartlearn environment).
- Flows: LM1 → Git (HTTPS 443, push/pull); Git → CI (trigger); CI → registry (HTTPS 443, push); Argo CD on LM2 → Git (HTTPS 443, read); LM2 → registry (HTTPS 443, pull); Persons/Kali → Ingress (HTTPS 443) → app (container port) → PostgreSQL (5432, internal); Prometheus → app (HTTP internal, scrape); Alertmanager → Mattermost (HTTPS 443 webhook).

### Resilience and policy

- Kyverno (or Gatekeeper) policies: disallow `latest`, disallow privileged, require requests/limits; tested by applying a violating manifest.
- Backup: scheduled `pg_dump` (CronJob) to a separate volume or off-cluster location; documented restore procedure; RTO/RPO stated and demonstrated once.

## Testing Decisions

### What a good test is

- Tests only exercise external behaviour through public interfaces (HTTP, Kubernetes API state, Prometheus/Alertmanager/Mattermost outputs). No assertions on internal functions, table layouts or template markup details.
- Every claim in the acceptance ("works", "persistent", "alerts") needs a reproducible piece of evidence, following the course principle: a running pod does not prove the app works; a bound PVC does not prove data survives.

### Seams

1. **Primary seam: the HTTP interface of the Zeiterfassung.** One black-box test suite drives login, stamping, admin view, authorization, health/ready and `/metrics` via HTTP against a base URL. The same suite runs:
   - in CI against the freshly built image + throwaway PostgreSQL,
   - on LM1 against the local Compose/Minikube setup,
   - against LM2 through the Ingress (customer acceptance, also from Kali).
   This is the only new test seam in the codebase.
2. **Platform acceptance (Commit-to-Alert) checks**, scripted on top of existing tooling rather than a new code seam: Argo CD status (Synced/Healthy), persistence across pod deletion, `kubectl auth can-i` expectations, NetworkPolicy reachability, policy rejection, and the alert path (scale app to 0 → Mattermost firing → scale back → Mattermost resolved).

### What gets tested

- App over HTTP: login success/failure, logout, stamp each Action, invalid transition rejected (409), user sees only own Stamps, admin sees all, non-admin gets 403 on admin URLs, unauthenticated requests redirected to login, CSRF-less POST rejected, `/ready` fails when DB is unreachable, `/metrics` counters increase after requests.
- Persistence: create a Stamp → delete pod(s) → Stamp still visible (also for the PostgreSQL pod).
- Security: image scan gate fails on a deliberately vulnerable base; `can-i` answers match expectations (yes/yes/no as in the reference); Nmap from Kali shows only 443 on LM2; DB not reachable from outside the namespace.
- GitOps: manual drift detected and reverted; rollback by commit revert.
- Monitoring: PromQL queries return data; test alert passes Pending → Firing → Resolved and arrives in Mattermost with runbook link; saved Kibana search finds a provoked error with pod/namespace attributes.
- Recovery: restore from backup into a fresh DB and verify Stamps via HTTP.

### Prior art

- Tag 6 "Zeiterfassung auf Minikube" HowTo: health check via curl, persistence test by deleting the pod, probe inspection, RBAC `can-i` checks.
- SAII Übungstest: curl-based HTTP checks through `kubectl port-forward`, `/health` 200 evidence, persistence via `/entry` + pod replacement, Kustomize dev/prod rendering without deploying.
- Tag 9 recap: systematic diagnosis sequence (get → describe → logs → service ports → port-forward + curl).

## Out of Scope

- Payroll, overtime calculation, absence/holiday management, reports/exports beyond the admin overview.
- Badge/hardware terminals (reference app mentions "Badge"; only online stamping is in scope).
- Self-service registration, password reset by e-mail, SSO/LDAP.
- Mobile apps or a SPA frontend.
- Multi-node / high-availability Kubernetes, managed cloud services, multi-region.
- PostgreSQL replication or operator-managed HA.
- Production-grade public certificates (internal/self-signed TLS is sufficient).
- Paging/on-call channels other than Mattermost.

## Further Notes

- **Timeline** (module plan): Mattermost integration 13.11.2026, hardening documentation 20.11 and implementation 27.11, Test 2 / Projekt-Gate (RAG status for Delivery, Observability, Security, Recovery, Documentation), handover and cross-team test 18.12.2026, Projektabgabe with live acceptance and failure challenge 09.01.2027. The two module plan versions in `docs/General` disagree on dates and topics per day; the A&C version is the more detailed one and was used for topic content.
- **Port inconsistency**: the Tag 6 reference app listens on 8080, the Übungstest Flask app on 5000, the team planning uses 5000 and the baseline app v1.4 uses 8080. Still open; whichever wins gets an ADR and the network plan follows.
- **Open assumptions** (from team Ablaufplan and Netzwerkplan v2, still to confirm against the new Smartlearn project environment): exact LM2 IP and hostnames, where Git/CI/registry live and which product, whether Mattermost and ELK run on LM2 or are provided centrally, whether LM2 runs Minikube or k3s, resource limits of LM2 for running the full ELK stack (ELK is memory-heavy; Loki is the fallback the module plan allows).
- **Group rule**: group work allowed, but every member must rebuild the setup in their own environment, so the LM1 and LM2 setup must be fully scripted/documented.
- **Deliverables still referenced by the course**: ADR-001, updated Netzwerkplan and Datenflussplan (.drawio + PDF), Telemetry-Plan, three PromQL queries + dashboard + SLO + test alert, incident report and improved runbook, tested policy + restore evidence + risk list, handover protocol.
