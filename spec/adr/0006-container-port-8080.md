# The app listens on 8080, not 5000

The Ablaufplan and network plan v2 assumed 5000 (taken from the Übungstest Flask app). App v1.4 listens on 8080, and so do its probes, Service `targetPort`, Makefile, smoke test and the Tag 6 reference app. We keep 8080 and change the plans, because a submitted diagram is cheaper to correct than every place the app depends on the port. The Service still exposes 80 and the Ingress 443; 8080 is only seen inside the cluster.

## Consequences

- Network plan v3 and the Datenflussplan say 8080 wherever v2 said 5000, with a legend note that the port changed.
- The Ablaufplan stays as submitted (it called 5000 an assumption).
