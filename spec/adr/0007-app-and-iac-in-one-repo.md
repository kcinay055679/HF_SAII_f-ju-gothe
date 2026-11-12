# App and infrastructure code share one repo, the project repo has it as a submodule

The app repo `SAII_Zeiterfassung` holds the app (`app/`), all cluster code (`deploy/`: app manifests, Argo CD, monitoring, logging, policies, backup) and CI (`.github/workflows/`). The project repo `HF_SAII_f-ju-gothe` (spec, Abgaben) includes it as the submodule `zeiterfassung/`. One repo per concern would be the textbook GitOps split. We chose one repo because the team is small, one commit can change app and manifests together, and the course's data flow plan shows a single Git repo as the source of truth. Argo CD only needs read access to one public repo.

## Considered Options

- **Separate config repo for `deploy/`:** cleaner audit trail and no CI noise from tag bumps. But it means two repos to clone, two to grant access to, and cross-repo changes for every release. Rejected as overhead for this project.
- **Everything in the project repo (former subtree):** mixes course paperwork into the repo Argo CD watches. Rejected.

## Consequences

- CI must use path filters (`app/**`), otherwise the commit that bumps the image tag in `deploy/` triggers another build.
- Argo CD Applications point at paths under `deploy/`, never at the repo root.
- Changes to the app or `deploy/` are committed and pushed in the submodule first, then the submodule pointer is committed in the project repo.
- Clone the project repo with `git clone --recurse-submodules`.
