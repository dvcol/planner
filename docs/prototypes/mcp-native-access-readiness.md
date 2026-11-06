# Mac MCP bridge for Codex

The 2 November request brings local Mac MCP access into the current TestFlight
follow-up. The selected client is Codex on the Mac and its connected phone
session. The implementation reuses the existing authenticated HTTP adapter and
the exact PlannerCore facade/session owned by the native app. It adds no server
on iOS, cloud backend, public endpoint, package or target.

## Use

1. Open the shared library in Plan 2Do Settings → Sharing and libraries.
2. In Settings → Agent access, check the displayed library and choose Enable.
3. Copy the Codex connection block shown there into the host's MCP configuration.
   It contains the loopback URL and a command invoking this installed app with
   `--mcp-headers`; it contains no credential. Use the installed app's actual path,
   not an old Xcode build path.
4. Reconnect Codex to load the server. Normal Codex tool-approval settings still
   apply. The connected phone session uses that Mac connection.

The Mac must be awake and Plan 2Do running to answer requests. Closing a planning
window does not end access. The on/off choice is saved for the authorized library
and account. Relaunch and same-library session refresh restore enabled access
with a fresh credential. Stop saves Off. Changing to another library or account
revokes the current window and does not transfer its authorization. No idle timer
or daemon is added.

The endpoint binds only to `127.0.0.1`; it is not directly reachable over LAN or
the internet. The Planner iOS app opens its own local Core session and synchronizes
shared planning data through iCloud rather than connecting to this Mac endpoint.

Whole library sharing allows creating new Lists. Selected-List sharing retains
its existing restrictions: agents can edit selected Lists and create Items in
them, while the owner manages List creation and global deletion. Read-only
libraries retain Core's write rejection. MCP clients cannot select another
account or dataset through request fields.

## Credentials and lifecycle

Each enabled access window generates a new 32-byte random credential in the app's
private, device-only data-protection Keychain. A separate, non-secret preference
retains the selected dataset, ownership binding and port beside the discovery
file. It contains no credential and is not synchronized as a cross-device grant.
An ephemeral App Group discovery file holds
only the accepted version, instance/window IDs, endpoint, protocol and On state.
The non-UI reader validates that state, reads Keychain without prompting, performs
an authenticated ping with the matching window header, then rereads discovery
state before emitting its header JSON. It never starts the GUI, opens Planner data
or enables a listener. Redirects and non-loopback endpoints are rejected.

Stop revokes admission and cancels active tool tasks before listener/credential
cleanup. An already committed command keeps its truthful result; Stop does not
promise rollback. Re-enable rotates the credential and can immediately reuse the
port. Failed binding or discovery publication never reports On. A session
replacement revokes the old bridge before restoring the saved choice for the
same authorized library and account. A different scope stays off and preserves
the previous scope's saved choice.

## Qualification

The persistent-choice follow-up passes nine focused signed lifecycle tests with
real Keychain, listener and disposable Core stores. They cover reconstruction of
the controller/store, automatic replacement of a stale same-library session,
durable Stop, scope isolation, stale-controller Stop and retention of a newer
port. The separate opt-in attended-client check was not rerun. Installed Mac
TestFlight build 12 restores access after the user enables it once, quits and
reopens the app without retoggling: the signed header helper and all six source
catalog reads succeed. A real iCloud account switch has not been performed.

The associated large-library follow-up reuses validated physical labels within
one unchanged bulk read or row window. The write/recovery cohort passes 161 tests;
the subsequent rows/capture/query cohort passes 30 tests, including paging,
another writer's label rename and malformed-label repair. These cohorts overlap.
No label values are cached across requests and no storage migration is added.
The installed build reads a real 64-row food List window with 87 matching Items
in 0.323 and 0.315 seconds; its corresponding identity queries take 0.141 and
0.086 seconds. Full-library timing remains part of the import completion check.

Four focused signed app-hosted lifecycle/validation tests and eight existing
HTTP authentication, ping, initialization and listener tests pass. They use real
Keychain and disposable real Planner storage, including a real MCP write, stale
credential rejection, immediate re-enable, occupied-port/publication failure,
concurrent Stop, and native library replacement. Six existing capture/bulk
admission checks also pass after cancellation forwarding was preserved.

A real Codex CLI 0.165.0 preflight passes through the signed executable's header
helper: create a uniquely named Item, read its exact generated identity, then edit
notes using the returned field hash. Core independently observes the final value.
The first noninteractive run correctly refused writes under its Never approval
policy; the successful run uses Codex's normal automatic-review mode for these
explicitly authorized disposable writes, without disabling sandboxing or changing
persistent approval settings. Tool guidance now calls out `sourceId` for source
edits and `scheduleId` for Schedule edits.

The affected Mac and iOS Simulator app/Share builds pass. Mac build 9 is Testing
in the Personal internal TestFlight group, with matching uploaded crash symbols
and saved testing notes. The installed Mac app's build 9, receipt, signature and
Production private-CloudKit/server entitlements are independently verified.
iOS build 8 already contains the compatible sharing/data protocol; this Mac-only
bridge does not require an iOS build-number change.

The requested Production round trip passes on 2 November 2026, using the actual
installed Mac TestFlight build 9 and iPhone TestFlight build 8:

- Three native iPhone steps pass: Whole library setup from Off, adding the verified
  Mac account and copying the private invitation. No narrower share was replaced.
- Mac acceptance produces the native “Library added” confirmation. The exact
  received library has Can edit permission; selecting it and enabling MCP passes.
- Real Codex CLI 0.165.0 applies six commands: create/edit List, create/edit Item,
  create/edit Schedule. Exact source reads independently verify generated
  identities, membership, names, notes and the booking: 3 November 2026,
  10:00–11:15 Asia/Tokyo.
- Mac native readback passes. iPhone native readback passes after app relaunch,
  then changes only that test Item's notes through its actual editor.
- A fresh Codex process uses the saved user MCP configuration and reads the
  phone's new notes plus the unchanged exact booking. Both read-only calls pass.

The initial client attempt was rejected before writing: operation IDs must be
UUIDs, and List creation uses `content.name`, while Items use `content.title`.
The successful run supplies the adapter-verified wire forms and returned field
hashes; it does not infer success from the model's final message. User Codex
configuration now contains the loopback URL and installed-app header helper,
without a saved credential or changes to normal approval policy. Reconnect Codex
to load that server into a new session.

The iPhone runner uses Apple's `UseDestinationArtifacts` mode to preserve the
installed app. Mac targets the installed app path. Direct PTY execution starts
mobile automation; TestFlight onboarding initially covered Planner. Its one-off
captured-screen dismissal was removed afterward. The retained checks use native
macOS sheets, visible form controls, the source Item's View item action and the
Schedule's actual accessibility role. Manual automation authentication remains
enabled. No iPad access, iCloud switch cycle or unrelated Production write was
needed. The synthetic List, Item and booking remain available for inspection.

Other agent clients and broader idle/sleep matrices are outside this requested
Codex slice. Raw credentials, invitation links, contact details and device logs
remain temporary and outside Git.
