# Video-Skript: Monitoring für die Zeiterfassung

Target: ≤ 2:30 (hard limit). About 200 words, so roughly 1:40 at a calm pace. That leaves room for pauses while pointing at the sketch. Record as a screen recording over `monitoring-skizze.png` / the A4, with the mouse pointing at the box being talked about. One or more speakers, split by section.

| Zeit | Bild | Text |
| --- | --- | --- |
| 0:00–0:15 | A4, Titel | Hallo, wir sind das Team f_you_goethe. In diesem Video zeigen wir, wie wir Ihre Zeiterfassung überwachen, damit Probleme auffallen, bevor Ihre Mitarbeitenden sie bemerken. |
| 0:15–0:45 | Skizze links → Prometheus | Die Zeiterfassung läuft in Kubernetes. Prometheus fragt alle fünfzehn Sekunden nach Messwerten: bei der Anwendung, beim Server, bei den Containern und bei der Datenbank. Mit Docker allein geht das gleich, mit cAdvisor und dem Node-Exporter. |
| 0:45–1:00 | Grafana | Grafana zeigt diese Werte als Dashboard. Ein Blick genügt: Läuft es, und ist es schnell? |
| 1:00–1:15 | Elasticsearch + Kibana | Zusätzlich sammeln wir alle Logs in Elasticsearch. Mit Kibana finden wir heraus, was genau passiert ist, zum Beispiel um acht Uhr drei. |
| 1:15–1:45 | Tabelle goldene Signale | Wir achten auf vier Signale. Latenz: Wie schnell antwortet die Seite beim Stempeln? Traffic: Wie viele Anfragen kommen an? Fehler: Wie viele Anfragen schlagen fehl? Und Sättigung: Wie nah sind CPU, Speicher und Datenbank am Limit? |
| 1:45–2:05 | Alertmanager → Mattermost | Wird eine Regel verletzt, etwa wenn die Zeiterfassung länger als eine Minute nicht erreichbar ist, schickt der Alertmanager eine Nachricht in den Mattermost-Kanal des Betriebsteams, mit Dienst, Zeit und Anleitung. Ist das Problem gelöst, kommt automatisch eine Entwarnung. |
| 2:05–2:25 | Best Practices | Unsere Grundsätze: Wir alarmieren nur, was Benutzer spüren. Jeder Alarm hat eine Anleitung. Und wir überwachen auch das Monitoring selbst. So bleibt Ihre Zeiterfassung zuverlässig. Danke! |

## Checklist before handing in

- [ ] Recorded length measured, ≤ 2:30
- [ ] Says the same as the A4, nothing extra
- [ ] Audio understandable, no background noise
- [ ] Export as MP4 → `abgaben/tag09_2026-11-06/f_you_goethe_26a_SAII_Recherche.mp4`
