# Spec: Tag 09 remaining work

Scope: the parts of the Tag 09 Auftrag that are not done yet. Status and the full Auftrag list are in [README.md](README.md). Terms follow [GLOSSARY.md](../GLOSSARY.md).

## Problem Statement

The lecturer asked for three things on Tag 09, and the team only has a PDF of the Netzwerkplan v2.

- **Recherche:**
  - **Asked for:** an A4 page with a sketch and a video of at most 2.5 minutes. Together they explain to the customer how Kubernetes/Docker is monitored with Prometheus, Grafana and ELK, and what the team will monitor in the Zeiterfassung.
  - **Status:** missing.
- **Plans:**
  - **Asked for:** both plans revised for monitoring and for the new Smartlearn project environment, as `.drawio`.
  - **Status:** the network plan source is lost, the data flow plan doesn't exist, and the plans haven't been checked against the new environment.
- **App with Docker:**
  - **Asked for:** start building the app with Docker.
  - **Status:** app v1.4 already has an image, but it listens on 8080 while the submitted plans say 5000.

## Solution

1. **Recherche A4 (German):**
   - a monitoring sketch on top
   - short sections: how monitoring works, what we monitor for the Zeiterfassung, how alerts reach the Betriebsteam, best practices
   - the sketch is a `.drawio` in `spec/diagrams/`
   - drafts live in `work/`, the PDF goes to `abgaben/`
2. **Video (German, ≤ 2:30):** a scripted voice-over of the A4 sketch, written in `work/` first. Recorded by the team, MP4 to `abgaben/`.
3. **Netzwerkplan v3:**
   - regenerate the v2 source as `.drawio` from the PDF
   - add the monitoring components with their ports and directions, plus the Kali IP
   - adapt it to the Smartlearn project environment
   - export to PDF
4. **Datenflussplan:** as specified in the [Tag 08 spec](../tag08_2026-10-30/spec.md), which also covers this Tag.
5. **Port decision:** decide 8080 vs 5000 as an ADR before step 3, so the plans and the app agree.
6. **App with Docker:** nothing new. App v1.4 already builds a tested image. Record that in the README.

## User Stories

### Recherche (A4 + video)

1. As the customer, I want a one-page explanation of how our system is monitored, so that I understand what the Betriebsteam watches without technical background.
2. As the customer, I want a sketch showing app, Kubernetes, Prometheus, Grafana, ELK, Alertmanager and Mattermost and how they connect, so that I see the whole picture at a glance.
3. As the customer, I want to know the difference between metrics (Prometheus), dashboards (Grafana) and logs (ELK), so that I know which tool answers which question.
4. As the customer, I want to know how Kubernetes and Docker themselves are monitored, so that I understand that both the app and the platform are watched. That covers node, pod and container metrics; cluster object state; container logs collected per node; and scraping of the app endpoint.
5. As the customer, I want the four golden signals explained with Zeiterfassung examples, so that I know what "healthy" means for our service:
   - latency: page and stamping response time
   - traffic: requests and Stamps per minute
   - errors: failed requests and rejected logins
   - saturation: CPU/memory against limits, DB connections, free disk on the volume
6. As the customer, I want to know which events raise an alarm, so that I know when the team gets woken up:
   - Zeiterfassung down
   - high error rate
   - slow responses
   - pod crash-looping
   - database down
   - volume almost full
7. As the customer, I want to see how an alarm reaches Mattermost and that a "resolved" message follows, so that I trust problems are seen and closed.
8. As the customer, I want best practices listed, so that I can judge the team's approach:
   - alert on symptoms the user feels, not on every metric
   - every alert has a runbook
   - consistent labels (service, pod, namespace)
   - structured logs
   - retention limits
   - few, actionable alerts against alarm fatigue
9. As the customer, I want the A4 to fit on one page, so that it's a quick read.
10. As the customer, I want a video of at most 2.5 minutes walking through the sketch, so that I can understand it by listening.
11. As the lecturer, I want the video to stay under 2:30, so that the hard limit ("MAX 2.5min (!)") is respected.
12. As the lecturer, I want one submission per group via Teams, so that I get one A4 and one video per team.
13. As a team member, I want the video script written before recording, so that we stay within time and every member can rehearse it.
14. As a team member, I want the Recherche to state what we will actually build later (Prometheus, Grafana, ELK, Alertmanager → Mattermost), so that it doubles as our monitoring plan.

### Netzwerkplan v3

15. As a team member, I want the network plan's `.drawio` source regenerated from the v2 PDF, so that we can edit it again.
16. As the lecturer, I want the revised network plan as `.drawio` or `.visio`, so that the "(!)" format requirement is met.
17. As the lecturer, I want each monitoring component placed on its machine with its port, so that I can see what listens where:
    - Prometheus 9090
    - Grafana 3000
    - Alertmanager 9093
    - Elasticsearch 9200
    - Kibana 5601
    - log shipper
    - node/cluster exporters
    - Mattermost 8065 or central
18. As the lecturer, I want scrape arrows to point from Prometheus to its targets, so that the pull model is shown correctly.
19. As the lecturer, I want the alert path Alertmanager → Mattermost webhook (HTTPS 443) drawn, so that the alarm route is visible.
20. As the lecturer, I want the Kali IP (192.168.110.70/24, gateway 192.168.110.2) and LM1 (192.168.110.60) on the plan, so that the Entwicklungsnetz is complete.
21. As the lecturer, I want the plan adapted to the new Smartlearn project environment (hostnames, IPs, networks), so that it matches the machines we'll actually use.
22. As the lecturer, I want trust boundaries between Entwicklungsnetz, Zentrale Dienste and Kundennetz marked, so that crossing flows are obvious.
23. As the lecturer, I want the asterisks in v2 (`*` = assumption) kept and explained in a legend, so that open assumptions stay visible.
24. As a team member, I want the plan to use the decided container port, so that the plan and the app don't contradict each other.

### Datenflussplan

25. As the lecturer, I want the revised Datenflussplan including monitoring, as `.drawio`, so that the Tag 09 requirement is met. Details are in the Tag 08 spec.

### App with Docker

26. As a team member, I want it recorded that app v1.4 already builds a tested, scanned image, so that "Starten: Zeiterfassung mit Docker" is visibly covered.
27. As a team member, I want the 8080 vs 5000 decision recorded as an ADR, so that it isn't re-argued every Tag.

## Implementation Decisions

- **Recherche A4:**
  - German, one A4 page, as PDF
  - sketch top half, text bottom half
  - text sections: "Wie überwachen wir?", "Was überwachen wir in der Zeiterfassung?", "Wie kommt ein Alarm an?", "Best Practices"
  - draft as Markdown in `work/`
- **Kubernetes/Docker monitoring content:**
  - Prometheus scrapes node exporter (host), cAdvisor/kubelet (containers), kube-state-metrics (pods, deployments, restarts) and the app's `/metrics`
  - for Docker without Kubernetes, the same via cAdvisor + node exporter
  - logs: a shipper per node reads container stdout and sends it to Elasticsearch; Kibana searches it
  - Grafana shows Prometheus data (and optionally Elasticsearch)
  - Alertmanager evaluates the rules from Prometheus and posts to Mattermost
  - the Tag 9 slides frame Monitoring as known states and Observability as unknown causes; the A4 should mention it in one line
- **Video:**
  - ~300 spoken German words, which is roughly 2:15 at a calm pace
  - follows the A4 top to bottom
  - script with timestamps in `work/`
  - recorded as a screen recording over the sketch, MP4
- **Diagrams:**
  - `spec/diagrams/` holds `netzwerkplan.drawio`, `datenflussplan.drawio` and `monitoring-skizze.drawio`
  - every Abgabe is a PDF export, and the `.drawio` itself is submitted too
  - the network plan version is in the title block (v3)
- **Regenerating v2:** rebuild it from the PDF with the same three-column layout and labels, commit that as the v2 baseline first, then make the v3 changes in a separate commit. That way the diff shows what changed for Tag 09.
- **Smartlearn project environment:**
  - details (hostnames, IPs, networks of the new LM2 etc.) are behind the Smartlearn login, so they can't be gathered from the repo
  - a team member reads them there and notes them in `work/`; until then the plan marks them as assumptions
  - known so far: LM1 = `li264-vmLM1.smartlearn.lan` (15 GiB RAM, 63 GB disk), Kali = `li261-vmKL1`
- **Port:** a new ADR decides 8080 or 5000. Recommendation: 8080, because the app, its probes, the Makefile, the smoke test and the course reference app all use it; the plans are cheaper to change than the app. The Ablaufplan stays as submitted.

## Testing Decisions

The seam is the lecturer's requirement list for each Abgabe, checked on the final export. No new tooling is needed.

- **Recherche A4:**
  - covers both research questions (how to monitor K8s/Docker with Prometheus/Grafana/ELK; what we monitor in the Zeiterfassung)
  - contains a sketch
  - is written for the customer (no unexplained jargon)
  - includes best practices
  - fits on one page when printed
- **Video:** the measured duration is ≤ 2:30, and the A4 and video say the same thing.
- **Network plan:**
  - every component from the monitoring section of the slides is present (Prometheus, Grafana, ELK, Mattermost) plus Alertmanager
  - every arrow has a direction, protocol and port
  - Kali, LM1, Git/registry and LM2 are present
  - open assumptions are marked
  - delivered as `.drawio`
- **Consistency:** the network plan and the data flow plan use identical names, IPs and ports, and both use the container port from the ADR.
- **App:** the existing `make test` and `make scan` still pass. No new tests for Tag 09.
- **Prior art:**
  - the lecturer's "BSP – Netzwerkplan" and "BSP – Datenflussplan" slides
  - the monitoring slides (golden signals, Prometheus/Grafana/Elastic roles)
  - the team's network plan v2

## Out of Scope

- Installing Prometheus, Grafana, ELK or Mattermost (later Tage).
- Adding `/metrics`, login or PostgreSQL to the app.
- CI pipeline, Argo CD setup.
- Setting up LM2 itself. Only planning against its known or assumed details.

## Further Notes

- **Deadline:** the Tag 09 Abgaben were due "bis Ende Lektion" on 06.11.2026, so they're late. The next Tag (13.11.2026, remote) moves on to Mattermost/metrics.
- **Recording the video:** someone in the team has to record it; Claude can only write the script.
- **Port in the plans:** the submitted v2 PDF says 5000 in several places. If the ADR picks 8080, v3 must change all of them. The legend should note the change so the lecturer isn't confused.
- **Sizing hint for ELK:** LM1 has 15 GiB RAM. If LM2 is similar, ELK + Prometheus + Grafana + the app fit, but tightly. Worth one sentence in the A4 as "Elasticsearch braucht am meisten Speicher".
