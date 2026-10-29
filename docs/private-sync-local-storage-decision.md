# Private synchronization and usable offline plans

Q164 A accepted on 29 October 2026; production remains local-only while the
replacement is implemented and qualified. It concerns the MVP synchronization
mechanism, not another recovery feature or a signing requirement.

## Evidence and existing approval

The [attended native test](prototypes/cloud-account-availability-native.md)
qualifies private export, Planner-only off/on, cache removal, same-account
reimport and exact fixture cleanup using the actual production schema. It does
not qualify uninterrupted offline editing or production account ownership.

Apple's [Frameworks Engineer explanation](https://developer.apple.com/forums/thread/811294)
confirms that disabling app-specific iCloud access is treated as account
sign-out. Unuploaded local changes can be removed too. The engineer points to
`CKSyncEngine` for a different application identity/privacy policy.

The approved [A10 architecture](core-architecture.md#approved-ownership-and-data-flow)
uses automatic SwiftData mirroring plus an independent recovery archive. Its
archive can preserve acknowledged content separately; the native cache-reset
test does not prove that archive design failed. It does establish that the
mirrored store alone cannot provide the requested usable offline copy.

The [new private-storage requirement](release-goals.md#private-cloud-storage-boundary-29-october-2026)
requires local preservation when private iCloud is unavailable, with no public,
shared or developer-funded fallback. Retaining automatic mirroring therefore
also needs a recovery-to-offline working-copy flow after account removal.

This choice concerns disabling app-specific iCloud or changing accounts. Both
designs still owe ordinary offline editing during a temporary network outage;
that is not the account-removal case exercised here.

## A: Keep local plans authoritative, use private CKSyncEngine

Accepted for the user's simpler MVP direction:

- Keep the existing SwiftData domain store configured with `.none`. Disabling
  CloudKit access does not automatically erase that store. Existing commands,
  queries, identities, local recovery and truthful save outcomes remain shared.
- Synchronize that local data using Apple's
  [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)
  and the approved container's explicit private database. No other database or
  backend is selected, including on quota or authentication errors.
- While private access is disabled, keep the current account's plans readable
  and editable locally, including across relaunch. Retain pending changes and
  show unavailable synchronization. Returning to the same account resumes sync.
- Keep each account's store, engine state and recovery namespace separate. An
  account transition invalidates old sessions; retained plans never upload to a
  different account automatically. Unbound existing local data is preserved and
  requires an explicit attachment choice before its first upload.
- Persist engine serialization and record metadata as internal account-scoped
  state outside portable backups. Reuse existing deletion/completion/reference
  semantics. Do not introduce another domain conflict or restoration framework.
- Keep the source models and existing portable formats unchanged for this first
  slice. Record mapping and synchronization metadata still need implementation
  and qualification; native mirroring's transport is no longer supplied for us.

The proposed public configuration extension is
`PlannerStorageConfiguration.StorageMode.privateCloud(containerIdentifier:)`.
It selects private synchronization of a local store, never an automatic
SwiftData cloud store. `localOnly` retains its current behavior. The container
is real deployment configuration; callers cannot supply an account selector or
an ownership token. Core resolves the actual account and binds the session.
Concrete account-specific paths and state are owned by Core beneath the
configured storage locations; app/Share callers do not reconstruct them.

Existing public command/query and native status interfaces remain the first
test surfaces. Begin with an isolated signed Core save, private round trip,
same-account off/on and cleanup. Qualify account isolation, interrupted sends,
quota failures, field conflicts, deletion and physical two-device operation
before activating production synchronization or claiming daily-use acceptance.
New direct test interfaces, if needed, require their existing review process.

This revises A10's synchronization mechanism. It adds CloudKit record mapping
and engine lifecycle work, but avoids using restoration as the normal way to
continue editing when private access is disabled. It is not an assertion that
`CKSyncEngine` is implemented or has passed Planner's convergence requirements.

## B: Retain automatic mirroring and explicit offline recovery

Keep A10's managed store and independent archive. After account removal clears
the cache, provide an explicit native recovery action to open a separate local
working copy. Preserve old-account archives and require reviewed attachment
before uploading that copy to any account. First launch without an account
continues to support ordinary local saves.

This retains Apple's managed record transport and the earlier topology, but
adds a user-visible recovery step before continuing with the same plans after
disabling iCloud. That difference must be accepted explicitly; an empty cloud
cache must not be presented as successful local preservation.

## Scope and decision

Both options retain private-only storage, offline saves, account isolation,
existing recovery evidence and the MVP's physical synchronization gates.
Neither changes the deferred export/import, Mac Share or V3 scope. Current
production data and cloud records stay untouched during isolated implementation.

The user accepted A. This supersedes A10's automatic mirroring mechanism; B is
retained above as the unselected alternative. There is no new account,
subscription, credential or capability request. The approved identifiers and
development signing setup remain in use.

The first [account-bound local-storage checkpoint](prototypes/private-local-storage.md)
implements ownership and local persistence without activating cloud transport.
