# Spec: Tag 08 remaining work

Scope: the parts of the Tag 08 Auftrag (Projektstart) that are not done yet. Status and the full Auftrag list are in [README.md](README.md). Terms follow [GLOSSARY.md](../GLOSSARY.md).

## Problem Statement

The team handed in the hand-drawn Netzwerkplan v1 and the Grober Ablaufplan on Tag 08, but three things are still missing:

- **Datenflussplan:** never handed in. The lecturer can't review how information moves from commit to alert, or how login and stamping travel through the system.
- **Team Git:** the repo now exists on GitHub (`HF_SAII_f-ju-gothe`), but only one member has access. The other members can't push, and the "everyone rebuilds it" rule can't be met.
- **Team registration:** it's not recorded whether the team name, class and members reached the lecturer via Teams. Without that, the lecturer won't create the Teams group, and submissions can't go through one person.

## Solution

- Draw one Datenflussplan as a `.drawio` source in `spec/diagrams/`, and export it to PDF. It covers everything Tag 08 asks for:
  - the Commit-to-Alert path
  - login, stamping and admin access
  - where code, images and configuration live
  - open assumptions

  Tag 09 asks for a revised Datenflussplan that adds monitoring. Rather than drawing two plans, this one already includes the monitoring path, so the same file satisfies both Tage. It gets handed in once, as the Tag 09 Abgabe, with a note that it also covers the missing Tag 08 one.
- Give every team member write access to the GitHub repo, and record the member list in the Tag 08 README.
- Confirm that the team registration was sent, or send it.
- Netzwerkplan v1 as `.drawio` is not redone; v2 (Tag 09) supersedes it.

## User Stories

1. As the lecturer, I want a Datenflussplan from the team, so that I can check the team understood the path from commit to alert before they build it.
2. As the lecturer, I want the plan to show the path Developer → Commit → Git → CI → Registry → Argo CD → Deployment on LM2 → Monitoring → Alertmanager → Mattermost, so that the release and alert chain is complete.
3. As the lecturer, I want login, stamping and admin access drawn as their own flows, so that I can see how a Person's data travels and where it is stored.
4. As the lecturer, I want each arrow labelled with what moves (code, image, manifest, Stamp, metric, log, alert) and over which protocol/port, so that the flows are unambiguous.
5. As the lecturer, I want to see where code, images and configuration are stored, so that it's clear what Git, the registry and the cluster each hold.
6. As the lecturer, I want application, monitoring and Mattermost visually distinct, so that I can tell the three concerns apart.
7. As the lecturer, I want open assumptions written on the plan itself, so that unclear points are visible instead of silently guessed.
8. As the lecturer, I want the trust boundary between Entwicklungsnetz and Kundennetz visible, so that I can judge which flows cross it.
9. As the lecturer, I want the source as `.drawio` plus a PDF, so that I can open it without tools and the team can keep editing it.
10. As the lecturer, I want the file named `Team-Name_Klasse_SAII.xyz`, so that I can sort submissions.
11. As the lecturer, I want only one team member to submit, so that I don't get duplicates.
12. As a team member, I want one data flow plan for both Tage, so that we maintain a single diagram instead of two drifting versions.
13. As a team member, I want the plan to use the same system names and ports as the network plan, so that both plans tell the same story.
14. As a team member, I want push access to the team repo, so that I can contribute and rebuild the setup in my own environment.
15. As a team member, I want the member list recorded in the repo, so that we know who is in the team without searching Teams.
16. As the lecturer, I want the team name, class and members sent via Teams, so that I can create the Teams group.
17. As a Person, I want my password to travel only over HTTPS and my Stamps to stay inside the Kundennetz, so that my data is protected. The plan shows exactly that.

## Implementation Decisions

- **One file:** a single Datenflussplan `.drawio` in `spec/diagrams/`, exported to PDF into `abgaben/tag09_2026-11-06/`. The Tag 08 README links to it and marks the item as covered by the Tag 09 Abgabe.
- **Three lanes, left to right**, matching the Smartlearn zones:
  - Entwicklungsnetz `lan0` (LM1, KL1)
  - outside `wan0` (GitHub: Git, CI, registry), reached through firewall LF1
  - Kundennetz `dmz0` (LM2 with Argo CD, cluster, monitoring, Mattermost; KL2)
- **Release flow:**
  - LM1 push → Git (HTTPS 443)
  - Git triggers CI
  - CI pushes the image → registry (HTTPS 443)
  - Argo CD on LM2 reads manifests from Git (HTTPS 443)
  - the cluster pulls the image from the registry (HTTPS 443)
  - the Deployment starts the app pods
- **User flows:**
  - Person/Admin browser → Ingress (HTTPS 443) → app (container port, still open: 5000 or 8080)
  - app → PostgreSQL (5432, cluster internal only)
  - login, stamp and Admin area drawn as three labelled arrows
- **Monitoring flow:**
  - Prometheus scrapes app `/metrics` and node/cluster exporters (pull)
  - Grafana queries Prometheus
  - a log shipper sends logs → Elasticsearch, and Kibana reads them
  - Prometheus rules → Alertmanager → Mattermost webhook (HTTPS 443)
  - a "resolved" message goes back the same way
- **Colour code:** application, monitoring and alerting (Mattermost) each get their own colour, with a legend.
- **Open assumptions box:**
  - container port
  - where Git, CI and the registry run
  - LM2 IP/hostname
  - whether Mattermost and ELK run on LM2 or centrally
  - Minikube vs k3d/k3s on LM2
- **Language:** German labels on the diagram (it's an Abgabe).
- **GitHub:** add every member as a collaborator with write access. The member list goes into the Tag 08 README.

## Testing Decisions

A good check here verifies the Abgabe against the lecturer's stated requirements, not against our taste. The seam is the requirement list from the Tag 9 slides ("Wichtige Infos" for the Tag 08 Auftrag), walked through as a checklist on the exported PDF:

- systems involved
- communication directions
- interfaces and ports
- storage of code/images/config
- commit-to-alert path
- open assumptions
- application/monitoring/Mattermost marked
- login/stamping/access drawn

Further checks:
- **Consistency:** every system, IP and port on the Datenflussplan also appears on the network plan, with the same name and value.
- **Format:** the `.drawio` opens in draw.io, and the PDF is regenerated from it, not edited separately.
- **Git access:** each member clones the repo and pushes a test branch.
- **Prior art:** the lecturer's example Datenflussplan in the Tag 9 slides ("BSP – Datenflussplan"), and the team's own technical flow in section 3 of the Ablaufplan.

## Out of Scope

- Redrawing Netzwerkplan v1 as `.drawio` (superseded by v2).
- Changing the Ablaufplan.
- Building or testing anything in the app.

## Further Notes

- **Class:** 26a, so file names are `f_you_goethe_26a_SAII.<ext>` and `f_you_goethe_26a_SAII_AblaufProjekt.<ext>`.
- **Lateness:** the Tag 08 Datenflussplan is overdue. Submitting it together with the Tag 09 version is a judgement call. If the lecturer wants it separately, export the same file a second time into `abgaben/tag08_2026-10-30/`.
