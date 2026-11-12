# Zeiterfassung — Umsetzungsplan (SAII HS2026, Abgabe 18.09.2026 18:45)

**Annahmen:** Ubuntu Lern-VM, bash, Docker installiert, k3d ≥ 5.x, kubectl ≥ 1.27,
Python 3.13 Base-Image, Typst ≥ 0.12 für die Dokumentation.

**Abweichung von der Kursvorgabe:** lokaler Cluster ist **k3d** statt minikube.
Alle Kursbefehle (`minikube kubectl -- …`) sind unten übersetzt. Siehe §11.

---

## 0. Entscheidungen, die vor dem Code feststehen müssen

Diese vier sind die einzigen echten Designentscheidungen. Jede ist ein fertiger
Eintrag für das AI Decision Log.

| Entscheidung | Wahl | Begründung |
| --- | --- | --- |
| Cluster | **k3d** statt minikube | Vorgabe des Autors. Kursmaterial nutzt durchgehend minikube. |
| Node-Anzahl | **`--agents 0`** (nur Server) | k3s Default-StorageClass `local-path` ist node-lokal, PVC ist `ReadWriteOnce`. Bei >1 Node landen die 3 Prod-Replicas auf verschiedenen Nodes und können nicht mounten. Single-Node macht RWO + 3 Replicas überhaupt erst möglich. Quelle: docs.k3s.io/storage. |
| 3 Prod-Replicas auf einem RWO-PVC | Beibehalten, Schreibzugriffe mit `fcntl.flock` serialisieren | Das Deck fordert beides (`prod: 3 Replicas`, PVC-Persistenz). Allgemein widersprechen sie sich; hier funktioniert es nur, weil alle Pods auf einem Node laufen. Stärkster Decision-Log-Eintrag — Konflikt dokumentieren, nicht verstecken. |
| WSGI-Server | **gunicorn**, `--workers 1 --threads 8` | `app.run()` ist Flasks Dev-Server, nicht produktiv. Mehrere Worker-Prozesse würden das Schreibkonflikt-Problem vervielfachen. `flock` deckt den Fall über Replicas hinweg ab. |

---

## 1. Repository-Layout

```text
~/workspace/zeiterfassung/
├── app/
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .dockerignore
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── pvc.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── service-nodeport.yaml
│   └── prod/
│       ├── kustomization.yaml
│       ├── ingress.yaml
│       └── replicas-patch.yaml
├── docs/
│   ├── abgabe.typ          # Typst-Quelle der 4-Seiten-Dokumentation
│   ├── abgabe.pdf          # kompiliertes Abgabedokument
│   ├── ai-decision-log.md
│   └── img/                # Screenshots, die in abgabe.typ eingebunden werden
├── README.md
└── .gitignore
```

Ordnername `zeiterfassung`, **nicht** `hermes-zeiterfassung`: die Sicherheitsgrenze im
Tag-4-Deck lautet `~/workspace/zeiterfassung`, und Hermes muss von dort gestartet werden.

---

## 2. Phase 1 — Cluster

```bash
# ⚠ versionsabhängig: k3d ≥ 5.0. Prüfen mit `k3d version`.
k3d cluster create saii \
  --agents 0 \
  --port "8080:30080@loadbalancer"

kubectl config use-context k3d-saii
kubectl get nodes -o wide
kubectl get storageclass          # erwartet: local-path (default)
```

`--port "HOST:NODEPORT@loadbalancer"` veröffentlicht Host-Port 8080 über den
k3d-serverlb auf NodePort 30080. Dokumentiert im k3d-Guide „Exposing Services".
⚠ unverified für k3d < 5.0 — dort war die `@loadbalancer`-Node-Filter-Syntax anders.

Traefik ist in k3s standardmässig aktiv und bleibt aktiv — der Prod-Overlay-Ingress
braucht ihn.

> **Destruktiv:** `k3d cluster delete saii` löscht Cluster und alle PVCs darin.
> Die `/data`-Inhalte sind dann weg. Persistenz-Demo **vor** jedem Delete aufnehmen.

---

## 3. Phase 2 — Git-Baseline und Hermes

```bash
cd ~/workspace/zeiterfassung
git init
printf '__pycache__/\n*.pyc\n.venv/\ndata/\ndocs/abgabe.pdf\n' > .gitignore
git add . && git commit -m "Startpunkt vor Hermes"
```

Danach Hermes + Ollama gemäss `Hermes VibeCoding HowTo.pdf` §2–4.

> ⚠ unverified: Ich kann weder `hermes-agent.nousresearch.com/install.sh` noch den
> Modell-Tag `gemma4:31b` bestätigen. Nach dem Pull mit `ollama list` prüfen statt annehmen.

**Prompt 1** — wörtlich aus HowTo §5 (nur lesend), ergänzt um die k3d-Randbedingung:

```text
Zusatz: Der lokale Cluster ist k3d (k3s in Docker), nicht minikube.
Default-StorageClass ist `local-path`, Ingress-Controller ist Traefik.
Berücksichtige das bei Persistenz und Exposition.
```

Plan abwarten. **Vor** der Freigabe gegen die Checkliste in §9 reviewen — dieses Review
ist der bewertete Teil.

**Prompt 2** — HowTo §6 wörtlich, inklusive Regel 7 (AI Decision Log, ≥ 2 geprüfte Entscheidungen).

---

## 4. Phase 3 — Flask-Anwendung

`app/requirements.txt`:

```text
Flask==3.1.1
gunicorn==23.0.0
```

⚠ versionsabhängig: `Flask==3.1.1` ist der Pin aus dem Tag-2-Material.
`gunicorn==23.0.0` ist mein Vorschlag — aktuelle Version auf PyPI prüfen und
das pinnen, was tatsächlich installiert wird.

`app/app.py`:

```python
import fcntl
import json
import os
import socket
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, jsonify, request
from markupsafe import escape

DATA_DIR = Path(os.getenv("DATA_DIR", "/data"))
DATA_FILE = DATA_DIR / "times.jsonl"
APP_VERSION = os.getenv("APP_VERSION", "1.0")
ACTIONS = ("EIN", "PAUSE", "ZURUECK", "AUS")
MAX_NOTE = 200

app = Flask(__name__)


def append_event(event: dict) -> None:
    """Ein Event unter exklusivem Lock anhaengen, damit sich gleichzeitig
    schreibende Replicas auf dem RWO-Volume nicht ins Wort fallen."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with DATA_FILE.open("a", encoding="utf-8") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        try:
            fh.write(json.dumps(event, ensure_ascii=False) + "\n")
            fh.flush()
            os.fsync(fh.fileno())
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)


def read_events(limit: int = 20) -> list[dict]:
    if not DATA_FILE.exists():
        return []
    with DATA_FILE.open("r", encoding="utf-8") as fh:
        fcntl.flock(fh, fcntl.LOCK_SH)
        try:
            lines = fh.readlines()
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)
    out = []
    for line in lines[-limit:]:
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


@app.get("/health")
def health():
    """Liveness und Readiness. Beweist, dass der Prozess antwortet UND dass
    das Volume wirklich beschreibbar ist — eine Probe, die nur 200 liefert,
    waere auch bei read-only /data gruen."""
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        probe = DATA_DIR / ".health"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink()
    except OSError as err:
        return jsonify(status="unhealthy", error=str(err)), 503
    return jsonify(status="healthy", pod=socket.gethostname(),
                   version=APP_VERSION), 200


@app.post("/stamp")
def stamp():
    payload = request.form if request.form else (request.get_json(silent=True) or {})
    action = str(payload.get("action", "")).upper()
    if action not in ACTIONS:
        return jsonify(error="unknown action", allowed=list(ACTIONS)), 400

    note = str(payload.get("note", "")).strip()[:MAX_NOTE]

    append_event({
        "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "action": action,
        "note": note,
        "pod": socket.gethostname(),
    })
    return jsonify(status="ok", action=action), 201


@app.get("/events")
def events():
    return jsonify(read_events())


@app.get("/")
def index():
    rows = "".join(
        f"<tr><td>{escape(e.get('ts',''))}</td>"
        f"<td>{escape(e.get('action',''))}</td>"
        f"<td>{escape(e.get('note',''))}</td>"
        f"<td>{escape(e.get('pod',''))}</td></tr>"
        for e in reversed(read_events())
    )
    buttons = "".join(
        f'<button name="action" value="{a}">{a}</button>' for a in ACTIONS
    )
    return f"""<!doctype html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Zeiterfassung</title>
<style>
 body{{font-family:Arial,sans-serif;background:#f6f5f1;margin:0}}
 main{{max-width:760px;margin:60px auto;padding:36px;background:#fff;border:3px solid #111}}
 button{{padding:18px 8px;background:#fff500;border:2px solid #111;font-weight:bold;cursor:pointer}}
 .actions{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:28px 0}}
 table{{width:100%;border-collapse:collapse}} td,th{{border-bottom:1px solid #ddd;padding:6px;text-align:left}}
</style></head><body><main>
<h1>Zeiterfassung</h1>
<form method="post" action="/stamp">
  <input name="note" maxlength="{MAX_NOTE}" placeholder="Rapport, z.B. Support XYZ Kunde Meyer" style="width:100%;padding:10px">
  <div class="actions">{buttons}</div>
</form>
<p>Version <strong>{escape(APP_VERSION)}</strong> &middot; Pod <strong>{escape(socket.gethostname())}</strong></p>
<table><tr><th>Zeit</th><th>Aktion</th><th>Notiz</th><th>Pod</th></tr>{rows}</table>
</main></body></html>"""
```

Anmerkungen zum Code:

- `POST /stamp` liefert JSON, der Browser verlässt also die Seite. Für eine
  2.5-Minuten-Demo akzeptabel; für Auto-Refresh `return redirect("/")` verwenden
  (braucht `from flask import redirect`).
- `escape()` aus `markupsafe` wird explizit aufgerufen statt sich auf Jinja-Autoescape
  zu verlassen — dessen Default hat sich über Flask-Versionen geändert. Explizit schlägt
  versionsabhängig.
- `ZURUECK` ohne Umlaut vermeidet Encoding-Rauschen in URL und JSON. Das Deck schreibt
  `ZURÜCK`; das Label darf den Umlaut tragen, der Value bleibt ASCII.

---

## 5. Phase 4 — Container

`app/Dockerfile`:

```dockerfile
FROM python:3.13-slim

ARG APP_VERSION=1.0
ENV APP_VERSION=${APP_VERSION} \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN useradd --system --uid 10001 --user-group appuser
USER 10001

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", \
     "--workers", "1", "--threads", "8", \
     "--access-logfile", "-", "app:app"]
```

`app/.dockerignore`:

```text
.git
.gitignore
__pycache__/
*.pyc
.venv/
docs/
```

Bauen und importieren:

```bash
cd ~/workspace/zeiterfassung
docker build -t zeiterfassung:1.0 app/
k3d image import zeiterfassung:1.0 -c saii     # ⚠ k3d ≥ 5.x; ersetzt `minikube image load`
docker image inspect zeiterfassung:1.0 --format '{{.Config.User}}'   # erwartet 10001
```

`FROM python:3.13-slim` ist ein wandernder Tag. Pinning per Digest
(`python:3.13-slim@sha256:…`) ist die stärkere Antwort auf die Vorgabe
„Dockerfile mit festem Image-Tag" — so oder so eine Zeile im Security-Abschnitt wert.

---

## 6. Phase 5 — Base-Manifeste

`base/pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: zeiterfassung-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Kein `storageClassName` — k3s' `local-path` ist Default-SC und bindet den Claim.
Mit `kubectl get sc` verifizieren.

`base/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zeiterfassung
spec:
  type: ClusterIP
  selector:
    app: zeiterfassung
  ports:
    - name: http
      port: 80
      targetPort: http
```

`base/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zeiterfassung
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zeiterfassung
  template:
    metadata:
      labels:
        app: zeiterfassung
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: zeiterfassung
          image: zeiterfassung:1.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: APP_VERSION
              value: "1.0"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 2
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 256Mi
          volumeMounts:
            - name: daten
              mountPath: /data
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: daten
          persistentVolumeClaim:
            claimName: zeiterfassung-data
        - name: tmp
          emptyDir: {}
```

`imagePullPolicy: IfNotPresent` ist zwingend — das Image liegt nach
`k3d image import` nur im containerd-Store des Clusters, ohne Registry dahinter.
`Always` erzeugt `ErrImagePull`.

`base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - pvc.yaml
```

### Zwei bekannte Stolperstellen

**1.** `readOnlyRootFilesystem: true` + gunicorn braucht ein beschreibbares `/tmp` —
daher das emptyDir. Bei Crash zuerst `kubectl logs` lesen, nicht raten.

**2.** ⚠ inferred: Ob `fsGroup`-Ownership auf ein `local-path`-Volume (hostPath-basiert)
genauso durchschlägt wie auf ein CSI-Volume, kann ich nicht bestätigen. Wenn `/health`
mit `Permission denied` auf `/data` ein 503 liefert, ist das die Ursache. Fix per
initContainer:

```yaml
      initContainers:
        - name: fix-perms
          image: busybox:1.36
          command: ["sh", "-c", "chown 10001:10001 /data"]
          securityContext:
            runAsUser: 0
          volumeMounts:
            - name: daten
              mountPath: /data
```

Dafür muss `runAsNonRoot: true` von der Pod-Ebene in den `securityContext` des
App-Containers wandern. Nur ergänzen, wenn der Fehler tatsächlich auftritt — und dann
als Decision-Log-Eintrag mit Beweis festhalten.

---

## 7. Phase 6 — Overlays

`overlays/dev/service-nodeport.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zeiterfassung
spec:
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: http
      nodePort: 30080
```

`overlays/dev/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: zeiterfassung-dev
resources:
  - ../../base
replicas:
  - name: zeiterfassung
    count: 1
images:
  - name: zeiterfassung
    newTag: "1.0"
patches:
  - path: service-nodeport.yaml
```

`overlays/prod/replicas-patch.yaml` (nur für Ressourcenunterschiede; die Anzahl deckt
das `replicas:`-Feld ab):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zeiterfassung
spec:
  template:
    spec:
      containers:
        - name: zeiterfassung
          resources:
            requests:
              cpu: 200m
              memory: 128Mi
            limits:
              cpu: "1"
              memory: 512Mi
```

`overlays/prod/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zeiterfassung
spec:
  ingressClassName: traefik
  rules:
    - host: zeiterfassung.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: zeiterfassung
                port:
                  number: 80
```

`overlays/prod/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: zeiterfassung-prod
resources:
  - ../../base
  - ingress.yaml
replicas:
  - name: zeiterfassung
    count: 3
images:
  - name: zeiterfassung
    newName: registry.example.internal/saii/zeiterfassung
    newTag: "1.0"
patches:
  - path: replicas-patch.yaml
```

Der Prod-`newName` zeigt auf eine Registry, die im Lab nicht existiert — genau das ist
der Sinn des Dev/Prod-Splits laut Deck („lokales Image" vs. „Registry-Image"). Prod
**rendert** daher, **läuft** aber lokal nicht. Rendern als Beweis:

```bash
kubectl kustomize overlays/prod | head -60
```

Soll Prod fürs Video wirklich laufen: `k3d cluster create --registry-create` und dorthin
pushen — Mehraufwand, von der Vorgabe nicht verlangt.
⚠ unverified Flag-Syntax; mit `k3d cluster create --help` prüfen.

Namespaces einmalig anlegen:

```bash
kubectl create namespace zeiterfassung-dev
kubectl create namespace zeiterfassung-prod
```

---

## 8. Phase 7 — Deployen, prüfen, Persistenz beweisen

```bash
kubectl kustomize overlays/dev            # rendern vor apply — nie blind anwenden
kubectl apply -k overlays/dev

kubectl -n zeiterfassung-dev rollout status deployment/zeiterfassung
kubectl -n zeiterfassung-dev get pods,svc,pvc -o wide
kubectl -n zeiterfassung-dev get endpoints zeiterfassung

curl -sS http://localhost:8080/health
curl -sS -X POST http://localhost:8080/stamp -d 'action=EIN' -d 'note=Support XYZ Kunde Meyer'
curl -sS http://localhost:8080/events
```

### Persistenzbeweis — die Schlüsselszene fürs Video

```bash
curl -sS http://localhost:8080/events            # 1 Event
kubectl -n zeiterfassung-dev delete pod -l app=zeiterfassung
kubectl -n zeiterfassung-dev rollout status deployment/zeiterfassung
curl -sS http://localhost:8080/events            # gleiches Event, neuer Pod-Name bei neuen Stempelungen
```

### Probenbeweis — bewusst einen Fehlschlag erzeugen

Ein negatives Ergebnis ist aussagekräftiger als ein grünes.

```bash
kubectl -n zeiterfassung-dev exec deploy/zeiterfassung -- sh -c 'chmod 500 /data'
kubectl -n zeiterfassung-dev get pods -w         # erwartet READY 0/1 innert ~10s
```

⚠ inferred: Ob `chmod` durchgeht, hängt von der Volume-Ownership ab. Falls nicht,
denselben Effekt über einen temporären `DATA_DIR`-Patch auf einen read-only Pfad zeigen.

### Prod-Render prüfen

```bash
kubectl kustomize overlays/prod | grep -E 'replicas|image:|type:|kind:'
```

Erwartet: `replicas: 3`, Registry-Image, `type: ClusterIP`, ein `Ingress`.

### Abschluss-Commit

```bash
git add .
git commit -m "Zeiterfassung mit Kubernetes und Kustomize"
git log --oneline --decorate -5
```

---

## 9. Security-Anforderungen

Jede Anforderung auf die Manifest-Zeile gemappt, die sie umsetzt. Die Bewertung prüft
vermutlich auf Konkretheit, nicht auf Vollständigkeit generischer Listen.

| # | Anforderung | Umsetzung | Adressierte Bedrohung |
| --- | --- | --- | --- |
| 1 | Container läuft non-root, UID 10001 | Dockerfile `USER 10001`, Pod `runAsNonRoot`/`runAsUser` | Container-Breakout zu Host-root |
| 2 | Alle Linux-Capabilities entzogen | `capabilities.drop: ["ALL"]` | Privilegienmissbrauch im Container |
| 3 | Keine Privilege Escalation | `allowPrivilegeEscalation: false` | setuid-Binaries |
| 4 | Read-only Root-Dateisystem | `readOnlyRootFilesystem: true` + `/tmp` emptyDir | Persistenz eingeschleuster Payloads |
| 5 | Default-seccomp-Profil | `seccompProfile.type: RuntimeDefault` | Reduzierte Syscall-Oberfläche |
| 6 | CPU-/Memory-requests und -limits | `resources` in Base + Prod-Patch | Noisy Neighbour / Resource-Exhaustion-DoS |
| 7 | Eingabevalidierung: Action-Whitelist, Notiz auf 200 Zeichen gekürzt | `ACTIONS`-Tuple, `[:MAX_NOTE]` | Injection, unbegrenzte Schreibverstärkung |
| 8 | Output-Escaping aller Benutzerdaten | `markupsafe.escape()` in `index()` | Stored XSS über das Rapport-Feld |
| 9 | Keine Secrets in Image, Repo oder Prompts | `.dockerignore`, `.gitignore`, keine Secret-Envs | Credential-Leak über Git-Historie oder `docker history` |
| 10 | Minimales Base-Image, keine Build-Toolchain zur Laufzeit | `python:3.13-slim`, `--no-cache-dir` | CVE-Oberfläche |
| 11 | Prod nicht per NodePort exponiert | Prod-Overlay `ClusterIP` + Ingress | Unbeabsichtigte externe Erreichbarkeit |
| 12 | Integrität bei Nebenläufigkeit | `fcntl.flock` exklusiv + `fsync` | Verschränkte/korrupte Records über 3 Replicas |
| 13 | Health-Endpunkt prüft das Volume, nicht nur den Prozess | `/health` schreibt und löscht Probedatei | Stiller Datenverlust hinter grüner Probe |
| 14 | *Optional:* NetworkPolicy default-deny ausser von Traefik | nicht umgesetzt | Laterale Bewegung |
| 15 | *Optional:* RBAC / benutzerbezogene Stempelung | nicht umgesetzt — App braucht keine ServiceAccount-Rechte | HowTo-Prüffrage antwortet „normalerweise nein" |

14 und 15 sind laut Vorgabe ausdrücklich freiwillig. Sie als *geprüft und bewusst
zurückgestellt* aufzuführen wertet mehr als Schweigen.

---

## 10. Abgaben

### 10.1 Video, max. 2:30

Durchspielen und aufnehmen — 2.5 Minuten sind schnell vorbei.

| Zeit | Einstellung |
| --- | --- |
| 0:00–0:15 | `kubectl get pods,svc,pvc -n zeiterfassung-dev` — alles Running/Bound |
| 0:15–0:50 | Browser auf `localhost:8080`: EIN mit Rapport-Notiz, PAUSE, ZURÜCK, AUS; Tabelle füllt sich |
| 0:50–1:20 | `curl /health` → healthy; Probe-Stanza in `deployment.yaml` zeigen |
| 1:20–1:55 | `kubectl delete pod -l app=zeiterfassung`, Rollout, Browser neu laden — Daten noch da |
| 1:55–2:20 | `kubectl kustomize overlays/prod \| grep -E 'replicas\|image\|type'` — Dev/Prod-Diff |
| 2:20–2:30 | `git log --oneline -5` |

Das HowTo verlangt zusätzlich ein Video, das **den Hermes-Dialog und eine geprüfte
Änderung** zeigt. Das Tag-4-Slide nicht. Beides passt nicht in einen 2:30-Clip — siehe §11.

### 10.2 Dokumentation — Typst, max. 4 Seiten A4

Quelle: `docs/abgabe.typ`. Aufbau:

1. **SOLL** — was der Dienst tut, die vier Aktionen, Persistenzmodell, Dev/Prod-Split,
   Ordnerbaum aus §1.
2. **Security-Anforderungen** — Tabelle aus §9, reduziert auf das tatsächlich Umgesetzte
   plus die als zurückgestellt markierten Punkte.
3. **Healthchecks** — `/health`-Implementierung, was sie tatsächlich verifiziert,
   Readiness vs. Liveness und warum die Delays differieren, Screenshot des erzwungenen
   Fehlschlags.
4. **Abweichungen und Risiken** — k3d statt minikube; 3 Prod-Replicas auf einem RWO-Volume;
   wandernder Base-Image-Tag.

Kompilieren:

```bash
# Variante A: natives Binary (empfohlen)
typst compile docs/abgabe.typ docs/abgabe.pdf
typst watch  docs/abgabe.typ docs/abgabe.pdf    # Live-Rebuild beim Schreiben

# Variante B: ohne Systeminstallation, ueber die Python-Bindings
pip install typst
python3 -c "import typst; typst.compile('docs/abgabe.typ', output='docs/abgabe.pdf')"
```

Seitenzahl vor der Abgabe prüfen — 4 Seiten A4 sind ein hartes Limit:

```bash
pdfinfo docs/abgabe.pdf | grep Pages
```

Screenshots gehören nach `docs/img/` und werden im `.typ` per `image("img/….png")`
eingebunden. Ohne die Dateien kompiliert das Dokument nicht — deshalb sind die
`#image`-Aufrufe in der Vorlage auskommentiert, bis die Screenshots existieren.

### 10.3 AI Decision Log (`docs/ai-decision-log.md`)

Mindestens zwei Einträge im Vierspalten-Format des HowTo. Stärkste Kandidaten:

| Entscheidung | Hermes-Vorschlag | Prüfung | Ergebnis |
| --- | --- | --- | --- |
| Persistenz bei 3 Replicas | PVC mit `ReadWriteOnce`, 3 Replicas | RWO erlaubt Mount durch mehrere Pods nur auf **einem** Node; `local-path` ist node-lokal | k3d mit `--agents 0`; zusätzlich `flock` in der App; Konflikt dokumentiert |
| Exposition | Service als `LoadBalancer` | k3d hat ServiceLB, Vorgabe verlangt aber NodePort (dev) / ClusterIP (prod) | Dev NodePort 30080 über k3d-Portmapping, Prod ClusterIP + Traefik-Ingress |
| Health-Endpunkt | statisches `return 200` | Probe wäre auch bei read-only `/data` grün | `/health` schreibt und löscht Probedatei, 503 bei `OSError` |

---

## 11. Offene Punkte — mit Baumann klären, nicht raten

1. **Widersprüchlicher Abgabeumfang.** Tag-4-Slide: *Video (2.5 min) + Dokument (4 A4)*.
   Hermes-HowTo §7: *installierbare dev/prod-Variante + Video des Hermes-Dialogs +
   AI Decision Log + Git-Historie + `get pods,svc`-Beweis*. Modulplan Tag 5:
   *installierbare Variante + AI Decision Log*. Drei verschiedene Umfänge. Alles zu bauen
   kostet wenig Zusatzaufwand — dieser Plan deckt die Vereinigungsmenge ab — aber das
   Video kann in 2:30 nur einen Zweck erfüllen.
2. **Akzeptanz von k3d.** Das gesamte Kursmaterial ist minikube. Nichts in den
   Anforderungen nennt minikube zwingend, aber die Beweis-Screenshots weichen von den
   erwarteten Befehlen ab. Günstige Absicherung: `README.md` mit den minikube-Äquivalenten
   (`minikube image load` ↔ `k3d image import`, `minikube service` ↔ k3d-Portmapping) und
   die Substitution im Abweichungs-Abschnitt des Dokuments benennen.
3. **Ordnerpfad.** Deck: `~/workspace/zeiterfassung`. HowTo: `~/workspace/hermes-zeiterfassung`.
   Keiner wird vom OneDrive-Export befüllt. Den aus dem Deck nehmen und das festhalten.
