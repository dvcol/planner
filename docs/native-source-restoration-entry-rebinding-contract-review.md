# Restored Item references from independent itineraries

Status: Q158 proposed. [A20](architecture-review-packet.md) already requires references authorized by either restoration candidate to follow the deterministic winner. Q157's [first rule](native-source-restoration-maintenance-contract-review.md) deliberately admits only unreferenced losing physical rows. This proposal extends maintenance to direct Item entries in an independent surviving Itinerary. It does not choose how to merge competing candidate-owned collections.

## Input and literal result

An open family F890 declares closed predecessor Item X101/811 and candidates X101/814 and X101/815. Both physical candidates exist. Winner814 retains its original notes, estimate, global Todo, archive state and timestamps. Loser815 has different content and global Done. A separate valid Itinerary T301/831 owns entry E451/851 targeting X101/815, locally Todo, followed by E452/852 targeting X101/815, locally Done.

Maintenance retains X101/814 exactly, rebinds both entries' persisted source lifetime and native Item relationship to X101/814, and retires only physical row815. Each entry keeps its public identity, lifetime, owner binding, route position and local completion. Direct-entry completion aliases and change history retain their exact identities and values. The two appearances therefore become Todo and Done under the winning Item's global Todo. This is A20's winning source state taking precedence; it does not copy the loser's global Done into local completion.

The independent Itinerary, its content, owned data and timestamps remain unchanged. Other entries and independent imported owners survive. No new source, entry lifetime, removal marker, source Delete or predecessor redirect is created. An old predecessor reference remains unsupported by this rule.

## Bounded admission

Require the same complete, uniquely resolved open-family authority and actual present smallest candidate as Q157. Admit one or more consistent direct Item entries owned by uniquely resolved, surviving independent Itineraries. The scalar and native relationship bindings must agree. The owner must not be a losing or unresolved source candidate. Each affected entry and its existing completion history must validate before any preparation.

The losing Item must otherwise have no memberships, labels, bookmarks, Schedules or other owned/inbound relationships. Nil or mismatched relationship objects, unknown candidates, missing winners, conflicting authority, unresolved owners, changed lifetimes and unrepresentable completion history reject without changing native data or prior recovery. Do not rewrite membership provenance or choose a policy for duplicate pairs. Rebinding List/Itinerary candidates, label targets and competing candidate-owned collections remains required later work on the map.

## Serialized declaration and atomic recovery

Add sourceRestorationConsolidation rule2 for this direct-entry rebinding and retirement. Keep rule1's original meaning and historical preparations. The exact existing maintenance preparation/evidence fields stay unchanged; rule2 contains one complete validated portable-v4 proposed graph and uses the exact preparation-byte SHA-256 digest. Recovery envelope2, portable4, physical model19 and the migration plan stay unchanged.

Persist the proposal before atomically saving entry scalar/relationship rebinding, physical loser retirement and the matching maintenance commit. Before save, validate the staged complete graph against the proposal and recheck dataset/ownership/control/history. A native failure rolls back the whole action; preparation alone remains unverified. A committed native save followed by publication failure blocks new commands until explicit Retry publishes the current coherent graph. Retry must not repeat rebinding, retire another source or fabricate a user command. Existing receipts and exact original-command replay retain their results and checkpoints.

Advance writer compatibility21 to22 before emitting rule2 evidence. An actual gate21 executable must reject reads/writes using an already active session and refuse cold main/Share startup after activation22, rather than failing late on an unknown rule. This is a logical writer declaration change, not a model migration or portable format change.

The main app owns activation. For already-delivered candidates and entries under control21, validate a nonmutating projection of both source selection and entry rebinding first. If it fails, native rows and prior recovery remain unchanged. Publish the coherent portable-v4 baseline and metadata22, then activate control22. This projection records no native retirement/maintenance commit. Only afterward may the separately prepared rule2 transaction revalidate and save the actual physical changes. Share waits for main activation. Interrupted publication/activation remains inspectable and retryable.

## Interfaces and qualification

Reuse the existing public Core/native-input, recovery-filesystem, real-process, native UI and HTTP seams. No new public command/read, target, package, production test hook or direct test boundary is requested.

Retain a failing direct-entry tracer first, then qualify the literal repeated-entry result, complete winner/owner/history preservation, invalid scalar/object/owner authority, exact replay and stale operations, coherent query/export/recovery, redelivery, independent-reader invalidation and interruption/native-save/publication/Retry outcomes. Verify actual gate21 active/cold rejection, main/Share activation ordering, all-kind Q157 rule1 regressions and historical evidence compatibility. Run affected lint/compiler/native/HTTP checks. Installed Share, signed storage, CloudKit/account convergence, actual Mac interaction, physical devices and whole-app acceptance remain separate gates; signing stays deferred.
