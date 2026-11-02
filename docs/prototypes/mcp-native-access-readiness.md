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
window does not end access. Stop, app quit, or changing the selected library ends
the access window. Relaunch starts Off. No idle timer or daemon is added.

Whole library sharing allows creating new Lists. Selected-List sharing retains
its existing restrictions: agents can edit selected Lists and create Items in
them, while the owner manages List creation and global deletion. Read-only
libraries retain Core's write rejection. MCP clients cannot select another
account or dataset through request fields.

## Credentials and lifecycle

Each Enable generates a new 32-byte random credential in the app's private,
device-only data-protection Keychain. An ephemeral App Group discovery file holds
only the accepted version, instance/window IDs, endpoint, protocol and On state.
The non-UI reader validates that state, reads Keychain without prompting, performs
an authenticated ping with the matching window header, then rereads discovery
state before emitting its header JSON. It never starts the GUI, opens Planner data
or enables a listener. Redirects and non-loopback endpoints are rejected.

Stop revokes admission and cancels active tool tasks before listener/credential
cleanup. An already committed command keeps its truthful result; Stop does not
promise rollback. Re-enable rotates the credential and can immediately reuse the
port. Failed binding or discovery publication never reports On. A library/session
replacement stops the old bridge instead of silently retargeting its clients.

## Qualification

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

Production qualification remains pending: create and edit an Item and List,
schedule the Item through MCP in the selected shared library, verify native
readback on Mac and iPhone, and read a phone-side edit back through MCP. The
attended runner compiles for both platforms. Manual Mac automation approval,
the completed TestFlight update and a primary-app reference now yield a passing
native inspection of the actual Production sharing controls. No received library
is registered yet. The iPhone attempts still stop before any test begins while
enabling automation, including a retry announced for live approval. A read-only
lock-state check reported no passcode requirement. Its runner uses Apple's
`UseDestinationArtifacts` mode to preserve the installed app; that mode explicitly
rejects Mac destinations, whose runner targets the installed app path instead.

The remaining attended handoff is a foreground Terminal run of the existing
native iPhone tests: prepare Whole library sharing only from Off, add the verified
Mac recipient, then copy its private invitation for acceptance. Existing narrower
sharing remains unchanged, no source plans are created by these steps, and manual
automation authentication stays enabled. The user explicitly approved this
Production sharing/editing and local Codex access. No new policy decision is
pending. Production MCP writes and cross-device readback remain unqualified until
that invitation is accepted and the exact received library is selected.

Other agent clients and broader idle/sleep matrices are outside this requested
Codex slice. Raw credentials, invitation links, contact details and device logs
remain temporary and outside Git.
