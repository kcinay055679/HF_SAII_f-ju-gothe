# Working agreement

How Yanick and Claude work together on this project. Read this at the start of a session, together with [STATUS.md](STATUS.md) and the newest `tagNN_…/README.md`. Repo layout and commands are in the root `CLAUDE.md`. This file covers the how.

## Roles

- **Yanick (team f_you_goethe, class 26a, SAII HS2026)** makes the decisions. He hands in Abgaben via Teams, records videos, and gets anything from places Claude can't reach: Smartlearn (no access for Claude), Teams, the VMs LM1/LM2/KL1/KL2/LF1.
- **Claude** gathers facts, proposes, writes specs, tracking files, drafts, diagrams and code, and keeps the tracking files current.

## How a piece of work runs

1. **Gather context first.** Read the relevant slides and Aufträge in `docs/` (via `pdftotext -layout`), the existing `spec/` files and `abgaben/`. Look facts up yourself. Never ask Yanick for something that is in the repo or the course material.
2. **Clarify structure and decisions by grilling** (`/mattpocock-skills:grilling`, `/mattpocock-skills:grill-with-docs`):
   - ask in numbered rounds, each question with a recommended answer, worded so "yes" accepts it
   - Yanick answers tersely ("Q1 yes, Q3 …")
   - only act once the frontier is empty
3. **Write specs with `/mattpocock-skills:to-spec`.** There is no issue tracker: a spec is saved as a file instead. Project-wide in `spec/zeiterfassung-spec.md`, per Tag in `spec/tagNN_…/spec.md`. The "check the seams" step is done by stating how the work will be verified and asking once.
4. **Record terms and decisions as they settle:** terms in `GLOSSARY.md` (domain-modeling style, no implementation details), hard-to-reverse decisions as an ADR in `adr/`. A decision that flips gets a new ADR that supersedes the old one.
5. **Update tracking right away:** day README checklist, `STATUS.md`, and `LEARNINGS.md` when something new was learned.
6. **Commit and push** after each coherent step. App/IaC changes go to the submodule `zeiterfassung/` (`SAII_Zeiterfassung`) first, then the pointer is committed to the project repo (`HF_SAII_f-ju-gothe`), both on `main`.

## When Claude can't get a fact

- Say exactly what is missing and the cheapest way for Yanick to get it (e.g. "run `ip -br a` on LM2").
- Continue with the item visibly marked as an assumption in the plan or spec. Don't block the rest of the work on it.
- Screenshots Yanick drops into the repo root get moved to the matching `spec/tagNN_…/work/` folder, renamed descriptively, and summarised in a Markdown note next to them.

## Conventions agreed so far

- **Tag folders:** only from Tag 08 (project start) on, named `tagNN_YYYY-MM-DD` after the slide numbering. `spec/` and `abgaben/` use identical names. A future Tag's folder is created only once its slides exist.
- **Ownership of status:** the day README owns its checklist. `STATUS.md` owns the 13 work packages and only links to day items.
- **Drafts vs. final:** drafts go to `spec/tagNN_…/work/`, final results to `abgaben/tagNN_…/`.
- **Diagrams:** living `.drawio` sources go in `spec/diagrams/`, and every Abgabe is a PDF exported from them. A lost source gets regenerated from the PDF and committed unchanged first, then edited in a separate commit.
- **Language:** tracking files in English, anything handed in in German. Domain terms from `GLOSSARY.md` (Person, Stamp, Admin, …), not Benutzer/Buchung.
- **File names for Abgaben:** `f_you_goethe_26a_SAII.<ext>` and `f_you_goethe_26a_SAII_AblaufProjekt.<ext>`.
- **The app** (`zeiterfassung/`, v1.4) is the baseline. The product spec is the target. Gaps are listed in the spec's "Baseline" section.
- **Git:** project repo + app repo as submodule `zeiterfassung/` (ADR-0007). `docs/` (course material) is not committed. `CLAUDE.md` is committed via a per-repo override of the global gitignore. No Claude/AI attribution in commits or PRs.

## Before deleting or moving anything

- Verify duplicates by checksum before deleting, and only delete what is also kept elsewhere.
- Check that a nested git repo is pushed before removing its `.git`. Keep history where cheap (`git subtree split` brought the app history back into `SAII_Zeiterfassung` as a fast-forward).
- Ask before outward-facing steps the user hasn't asked for, such as a new remote or force-pushing.

## Communication

- Answers are terse; the user's caveman-mode hook sets the tone. Lead with the result, then what's left and what's needed from Yanick.
- When Claude finds a contradiction (slides vs. module plan, app vs. plan, e.g. port 8080 vs 5000), it raises it, logs it in `LEARNINGS.md`, and gives a recommendation. It doesn't decide silently.
- Don't produce Abgaben that weren't asked for. Write the spec and drafts, and let Yanick decide what gets handed in.
