# Document Sections

The rule each section of `assets/release-document-template.md` follows. Sections 1 and 8 carry
their rule in the template itself.

## 2. Major Changes — cluster, don't list

Do **not** produce one section per repository. Customers do not know or care where your repo
boundaries fall, and a 12-repo list reads as noise.

Cluster the customer-visible bullets from every report into 3–6 **themes** by capability — "Tool
integration", "Data layer", "Security hardening" — each with 2–4 bullets. Name a service only
where the customer needs it to troubleshoot.

Repos with `change_class: version-bump-only` appear only in the Version Matrix.

## 3. Benefits

One line per theme: what the customer gets. Security fixes, stability, and measurable numbers
land harder with enterprise clients than feature names do. Only cite a number some report
substantiates.

## 4. Impact

- **4.1 System** — breaking changes and which of their integrations must change; new infra; new
  outbound hosts to allowlist; resource changes
- **4.2 Process** — retraining, SOP and doc updates, changes to their integration code.
  Customers routinely under-plan this, because nobody tells them a screen moved.
- **4.3 Downtime** — total window, which functions are unavailable, what stays up

## 5. Deployment Playbook

Build waves from `deploy_after`: services with no dependencies go in wave 1, their dependents in
wave 2, and so on. Provider before consumer, always.

The rollback decision point needs an explicit abort criterion and a cutoff time. "We'll see how
it goes" is how a window overruns. If any migration is irreversible, state that rollback after
that step means restore-from-backup with a stated RPO — that is a different conversation with
the customer than "redeploy the old tag", and it has to happen before the window, not during it.

Present the schedule as a proposal requiring customer approval, in their timezone, in a
low-traffic window — never as a fixed date.

## 6. Version Matrix

Every service, including the no-ops. Plus one **platform-level release number** the customer
quotes in support tickets: individual service tags are for your team, the platform version is
for them.

## 7. Customer Actions Required

Extract everything the customer must do — supply config values, open firewall rules, update
integration code, retrain staff — each with a by-when. Keep it in its own numbered section.
Buried in prose these get missed, and then the deploy fails during the window and it looks like
your fault.
