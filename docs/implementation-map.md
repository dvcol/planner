# Native Planner MVP map

The [GitHub decision map](https://github.com/dvcol/planner/issues/1) is canonical.
This file mirrors its low-resolution index; open work and dependencies live
in GitHub native sub-issues.

## Destination

Reach an implemented, reviewed core V2 Planner MVP for daily personal use on
iPhone, iPad and Mac, then obtain the user's explicit acceptance of its native
workflows and recorded limitations.

## Notes

- This effort explicitly carries execution and acceptance into the map, as
  authorized by the user; it is no longer a specification-only exercise.
- The map is an index. Open work lives in native child issues; native blocked-by
  relationships define the frontier. Detailed answers live in resolution
  comments and linked artifacts, not this body.
- Core feature code is implemented locally. Signing/setup is ready and normal
  same-account mobile sync passes. Remaining work is the focused
  native/physical/assistive acceptance frontier; these statements do not declare
  the release accepted.
- Validated workspace checkpoint: `278da3da` on `prototype/navigation`.
  Published branch: `9eb878c5`. Newer source/evidence is not yet published;
  final handoff must reconcile that explicitly.
- Prefer the simplest sufficient MVP. Reuse passing evidence, run serial
  affected-target checks, and investigate reproducible defects. Do not fill time
  with broader matrices or repeat normal iCloud checks without a relevant
  change.
- Planner data uses local-authoritative storage and the user's private iCloud
  database only. No public/shared/developer-funded cloud fallback.
- Consult `code-quality`, `code-architecture` and `code-testing` when
  applicable. Use TDD when requested. Existing interface approvals carry
  forward; tracker cleanup creates no new product answers or test seams.
- Human review is still human review. Claim work before executing it; do not
  infer app acceptance from this administrative cleanup. The user has returned;
  attended checks require current device readiness.
- The user explicitly authorized this bulk historical-state/scope
  reconciliation. The normal one-HITL-decision-per-session rule applies to new
  decisions, not these already-authorized administrative dispositions.
- The [pre-cleanup implementation
  index](https://github.com/dvcol/planner/blob/9eb878c50984966d373d9d1a0017205c9a4bb6e4/docs/implementation-map.md)
  preserves published history. The current workspace keeps detailed checkpoints
  separately from this low-resolution index.

## Decisions so far

- [Release goals](https://github.com/dvcol/planner/issues/2): core V2 is the
  first daily-use release; later user amendments keep advanced administration
  and V3 out of MVP.
- [Planner vocabulary](https://github.com/dvcol/planner/issues/3): shared Items,
  contextual appearances and independent completion/archive vocabulary.
- [Apple capabilities](https://github.com/dvcol/planner/issues/4): native Apple
  framework and entitlement feasibility, with runtime limits recorded.
- [Place-data provenance](https://github.com/dvcol/planner/issues/5): owned
  content remains distinct from temporary provider previews.
- [Apple test access](https://github.com/dvcol/planner/issues/7): approved team,
  identifiers, signing and MVP device/container access are established; behavior
  acceptance stays separate.
- [Duration and search](https://github.com/dvcol/planner/issues/8): exact
  planning estimates, cumulative criteria and stable shared query behavior.
- [Itineraries and scheduling](https://github.com/dvcol/planner/issues/9): live
  ordered references and canonical timed/all-day schedules with explicit
  civil-time rules.
- [Offline conflicts and recovery](https://github.com/dvcol/planner/issues/10):
  preserve durable local data and truthful outcomes; advanced manual recovery
  qualification is deferred.
- [URL and share capture](https://github.com/dvcol/planner/issues/11): reviewed
  partial capture retains original links and explicit source/appearance scope.
- [Core architecture](https://github.com/dvcol/planner/issues/12): shared Core
  with local-authoritative SwiftData and the accepted private CKSyncEngine
  amendment.
- [Shared command contracts](https://github.com/dvcol/planner/issues/13): one
  authority/read model; system/agent adapters retain their later-stage scope.
- [Navigation prototype](https://github.com/dvcol/planner/issues/14):
  established native workflows; duplicate final acceptance is consolidated under
  the remaining UI gate.
- [Build workflow](https://github.com/dvcol/planner/issues/18): native Xcode
  project, shared schemes and local Swift packages.
- [Native search capabilities](https://github.com/dvcol/planner/issues/19): the
  native lexical baseline and its measured/qualification limits.
- [Native long-list capabilities](https://github.com/dvcol/planner/issues/20):
  paged native presentations, full-scope identities and measured performance
  limits.
- [Native calendar date
  capabilities](https://github.com/dvcol/planner/issues/21): explicit DST,
  timezone and inclusive civil-date behavior.
- [Completion scopes and derived
  progress](https://github.com/dvcol/planner/issues/22): shared/global versus
  contextual state, appearance-based progress and archive rules.

## Not yet specified

No additional MVP product decision is identified by the current audit. Known
acceptance work is already represented by open native child issues, not fog. If
review exposes a consequential new choice, create one precise decision ticket
rather than silently choosing or expanding this map.

## Out of scope

- [MCP session prototype](https://github.com/dvcol/planner/issues/16) and [Local
  MCP compatibility](https://github.com/dvcol/planner/issues/6): V3 Agent
  Control/MCP and remaining App Intents/Shortcuts/Siri qualification; retained
  context, not MVP blockers.
- Advanced JSON export/import, restoration-family expansion and their
  administration polish: deferred by the accepted MVP amendment; existing tools
  and safeguards remain intact.
- Installed Mac Share: explicitly deferred; Mac in-app creation/capture remains
  in scope.
- More iCloud off/on, conflict, interruption and quota stress qualification:
  currently deferred and unqualified; normal physical sync evidence is retained
  without promising untested outcomes.
- Apple Calendar export, embedded Google Maps/API-key billing and shared
  planning retain their existing exclusions. App Store/unlisted distribution
  follows the core acceptance handoff.

## Remaining implementation and acceptance

Use the canonical map's native child issues and blocking relationships.
The core feature implementation is present; remaining acceptance must not be
reported as complete. No signing setup or further iCloud stress run is queued.

## Historical checkpoints

[Detailed implementation checkpoints](implementation-checkpoints.md) retain the
previous chronological report with its actual versions, tests and limitations.
[Decision checkpoints](decision-checkpoints.md) retain the old decision register.
The exact before-edit issue bodies and relationships are preserved in the
[tracker snapshot](history/tracker-before-mvp-reconciliation-2026-10-31.json.gz).
These archives are historical evidence, not additional current task queues.
