# Zeiterfassung

A time-tracking service where people clock in, take breaks and clock out through a web page, delivered to a customer as the SAII HS2026 semester project and run there under monitoring and alerting.

## Language

### Tracking

**Person**:
Someone who stamps. A Person has a name that is unique case-insensitively, with surrounding whitespace ignored; the spelling used at creation is the one shown. In the customer project a Person also logs in, and only stamps for themselves.
_Avoid_: User, Benutzer, employee, account

**Admin**:
A Person who may also see every Person's Stamps in the Admin area.
_Avoid_: Superuser, manager

**Admin area**:
The view, open only to Admins, that lists the Stamps of all Persons.
_Avoid_: Adminbereich (in English text), dashboard

**Stamp**:
One recorded event: a Person, an Action, an optional Note and the time it happened. Stamps are append-only.
_Avoid_: Entry, record, booking, Buchung, Stempelung (in English text)

**Action**:
One of the four stamp kinds: EIN (clock in), PAUSE (start break), ZURUECK (end break), AUS (clock out). The UI label for ZURUECK is "ZURÜCK".
_Avoid_: Event type, command

**Note**:
Optional free text attached to a Stamp, up to 200 characters, e.g. "Support XYZ Kunde Meyer".
_Avoid_: Comment, description (the course calls it "Rapport")

**Status**:
Where a Person currently stands, derived from their latest Stamp: OUT (no stamp, or last was AUS), WORKING (last was EIN or ZURUECK), ON BREAK (last was PAUSE).
_Avoid_: State, presence

**Valid transition**:
An Action allowed from the Person's current Status. OUT allows EIN; WORKING allows PAUSE or AUS; ON BREAK allows ZURUECK. Anything else is rejected.

**Worked time today**:
The sum of WORKING intervals for a Person within the current day in Europe/Zurich. An interval still open counts up to now.
_Avoid_: Hours, balance

**Status board**:
The overview on the main page listing every Person with their Status and Worked time today.

### Deployment

**Environment**:
Either dev or prod. Same base manifests, different overlays.

**Dev**:
The environment for development and testing, one replica.

**Prod**:
The customer-facing environment, several replicas, image pulled from a registry.

**LM1**:
The developer machine in the Entwicklungsnetz, where Dev runs.
_Avoid_: dev VM, local machine

**LM2**:
The customer machine in the Kundennetz, where Prod and the monitoring run.
_Avoid_: customer VM, production server

**Kali**:
The tester machine used for GUI, functional and security tests against LM1 and LM2.

**Commit-to-Alert**:
The full delivery and operations chain: commit on LM1, Git, CI, registry, GitOps deployment on LM2, telemetry, alert rule, Mattermost message.
_Avoid_: pipeline (that is only the CI part)

### Course

**Tag**:
One course day of SAII HS2026, numbered as on the lecturer's slides, which can differ from the module plan.
_Avoid_: lesson, session, Lektion

**Auftrag**:
A task the lecturer gives on a Tag.
_Avoid_: assignment, exercise, ticket

**Abgabe**:
A result handed in to the lecturer for an Auftrag, usually via Teams by the end of the lesson.
_Avoid_: deliverable, submission (in file names)
